"""Generate the positive class by inpainting residue onto real clean smiles.

Same idea as `synthesize_dirty.py`, with a diffusion model as the brush instead
of coloured polygons. The base photograph stays real: background, lighting,
skin and face are untouched, and only the masked teeth region is regenerated.

    # offline, no key, no cost: writes masks and local previews
    python inpaint_dirty.py --clean raw/clean --out raw/dirty --dry-run

    # for real
    set STABILITY_API_KEY=...
    python inpaint_dirty.py --clean raw/clean --out raw/dirty --per-image 3

Why inpainting rather than text-to-image: if the positive class were generated
whole and the negative class photographed, the classifier would learn to tell
rendered pixels from camera pixels. That is a far easier problem than the one
being asked, it scores near-perfectly in validation, and it fails completely on
the first real user. Editing one region of a real photo removes that shortcut,
because both classes come from the same source frames.

Outputs carry the same `__synth` tag as the compositor, so `prepare_dataset.py`
routes them into train and `verify_split.py` keeps them out of val and test.
Generated images train the model; they cannot measure it.
"""

from __future__ import annotations

import argparse
import json
import os
import random
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

from synthesize_dirty import SUFFIXES, SYNTH_TAG, find_teeth, synthesise

# Varied so the set does not collapse onto one kind of residue. Wording is
# deliberately plain; diffusion models handle concrete nouns better than
# clinical description.
PROMPTS: tuple[str, ...] = (
    "small piece of green spinach stuck between the front teeth",
    "tiny dark poppy seeds caught between teeth near the gum line",
    "a few crumbs of brown bread stuck on the front teeth",
    "small piece of dark green herb leaf wedged between two teeth",
    "bits of dark chocolate smeared on the front teeth",
    "small red berry skin stuck between the front teeth",
    "pale crumbs of cracker on the teeth near the gums",
    "a sesame seed stuck between two front teeth",
    "small piece of yellow food debris on the front teeth",
    "dark seed fragments lodged along the gum line of the front teeth",
)

NEGATIVE_PROMPT = "blurry, distorted teeth, extra teeth, deformed mouth, text"


def build_mask(image: Image.Image, rng: random.Random) -> Image.Image | None:
    """White where the model may paint, black everywhere else.

    The teeth mask is grown a little: an inpainter given a tight mask tends to
    produce a hard-edged patch, while a slightly loose one blends.
    """
    teeth = find_teeth(image, rng)
    if teeth is None:
        return None

    mask = Image.fromarray((teeth * 255).astype(np.uint8), mode="L")
    return mask.filter(ImageFilter.MaxFilter(7)).filter(
        ImageFilter.GaussianBlur(radius=1.5)
    )


def stability_inpaint(
    image_path: Path, mask: Image.Image, prompt: str, api_key: str
) -> bytes:
    """POSTs to Stability's inpaint endpoint and returns the image bytes.

    Written against the documented v2beta shape. If the API has moved, this is
    the one function to fix; nothing else here knows about a vendor.
    """
    import requests

    mask_path = image_path.with_suffix(".mask.png")
    mask.save(mask_path)
    try:
        with (
            open(image_path, "rb") as image_file,
            open(mask_path, "rb") as mask_file,
        ):
            response = requests.post(
                "https://api.stability.ai/v2beta/stable-image/edit/inpaint",
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Accept": "image/*",
                },
                files={"image": image_file, "mask": mask_file},
                data={
                    "prompt": prompt,
                    "negative_prompt": NEGATIVE_PROMPT,
                    # Softens the seam between generated and original pixels.
                    "grow_mask": 5,
                    "output_format": "jpeg",
                },
                timeout=120,
            )
    finally:
        mask_path.unlink(missing_ok=True)

    if response.status_code != 200:
        raise RuntimeError(
            f"Stability returned {response.status_code}: {response.text[:300]}"
        )
    return response.content


def openai_inpaint(
    image_path: Path, mask: Image.Image, prompt: str, api_key: str
) -> bytes:
    """OpenAI's image edit endpoint.

    Note the inverted convention: OpenAI paints where the mask is
    *transparent*, so the teeth region becomes an alpha hole rather than white.
    """
    import base64
    import io

    import requests

    with Image.open(image_path) as handle:
        base = handle.convert("RGBA")
    alpha = Image.eval(mask.resize(base.size), lambda v: 255 - v)
    base.putalpha(alpha)

    buffer = io.BytesIO()
    base.save(buffer, format="PNG")
    buffer.seek(0)

    response = requests.post(
        "https://api.openai.com/v1/images/edits",
        headers={"Authorization": f"Bearer {api_key}"},
        files={"image": ("image.png", buffer, "image/png")},
        data={"model": "gpt-image-1", "prompt": prompt, "n": 1},
        timeout=180,
    )
    if response.status_code != 200:
        raise RuntimeError(
            f"OpenAI returned {response.status_code}: {response.text[:300]}"
        )
    payload = response.json()["data"][0]
    if "b64_json" in payload:
        return base64.b64decode(payload["b64_json"])
    return requests.get(payload["url"], timeout=120).content


PROVIDERS = {
    "stability": (stability_inpaint, "STABILITY_API_KEY"),
    "openai": (openai_inpaint, "OPENAI_API_KEY"),
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--clean", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--per-image", type=int, default=3)
    parser.add_argument(
        "--provider", choices=sorted(PROVIDERS), default="stability"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="no API calls: writes the mask and a locally composited preview "
        "so the framing and mask can be judged before spending anything",
    )
    parser.add_argument(
        "--max-requests",
        type=int,
        default=60,
        help="hard cap on billable calls, so a wrong path cannot run up a bill",
    )
    parser.add_argument("--seed", type=int, default=1337)
    args = parser.parse_args()

    sources = sorted(
        p
        for p in args.clean.iterdir()
        if p.is_file() and p.suffix.lower() in SUFFIXES
    )
    if not sources:
        raise SystemExit(f"No images in {args.clean}")

    call, key_env = PROVIDERS[args.provider]
    api_key = os.environ.get(key_env, "")
    if not args.dry_run and not api_key:
        raise SystemExit(
            f"{key_env} is not set. Export it, or use --dry-run to check the "
            f"masks first."
        )

    planned = len(sources) * args.per_image
    if not args.dry_run and planned > args.max_requests:
        raise SystemExit(
            f"{len(sources)} images x {args.per_image} would make {planned} "
            f"billable calls, over the --max-requests cap of "
            f"{args.max_requests}. Raise the cap deliberately if that is what "
            f"you want."
        )

    args.out.mkdir(parents=True, exist_ok=True)
    rng = random.Random(args.seed)
    manifest: dict[str, list[dict]] = {}
    skipped: list[str] = []
    failures = 0

    for source in sources:
        with Image.open(source) as handle:
            image = handle.convert("RGB")

        mask = build_mask(image, rng)
        if mask is None:
            skipped.append(source.name)
            continue

        records = []
        for index in range(args.per_image):
            prompt = rng.choice(PROMPTS)
            name = f"{source.stem}{SYNTH_TAG}{index}.jpg"
            target = args.out / name

            if args.dry_run:
                # Masks go in a subdirectory, never beside the images.
                # `prepare_dataset.py` scans only the top level of a class
                # folder, and an untagged .png sitting there would be taken for
                # a real photograph and routed into val or test.
                mask_dir = args.out / "masks"
                mask_dir.mkdir(exist_ok=True)
                mask.save(mask_dir / f"{source.stem}.mask{index}.png")
                # The local compositor stands in for the API so the pipeline,
                # naming and manifest can all be exercised without a key.
                synthesise(image, np.asarray(mask) > 127, rng).save(
                    target, quality=92
                )
            else:
                for attempt in range(3):
                    try:
                        target.write_bytes(
                            call(source, mask, prompt, api_key)
                        )
                        break
                    except Exception as error:  # noqa: BLE001 - reported below
                        if attempt == 2:
                            print(f"  failed {name}: {error}", file=sys.stderr)
                            failures += 1
                        else:
                            time.sleep(2 * (attempt + 1))
                else:
                    continue

            records.append({"file": name, "prompt": prompt})
        manifest[source.name] = records

    (args.out / "manifest.json").write_text(
        json.dumps(
            {
                "provider": "dry-run" if args.dry_run else args.provider,
                "seed": args.seed,
                "generated": manifest,
                "skipped": skipped,
            },
            indent=2,
        )
    )

    made = sum(len(v) for v in manifest.values())
    mode = "previews" if args.dry_run else "inpainted images"
    print(f"\n  {len(manifest)} sources -> {made} {mode} in {args.out}")
    if skipped:
        print(f"  {len(skipped)} skipped: no convincing teeth region found")
    if failures:
        print(f"  {failures} calls failed after retries")
    print(
        f"\n  Tagged {SYNTH_TAG}, so these go to train only. Val and test still "
        f"need real photographs.\n"
    )
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
