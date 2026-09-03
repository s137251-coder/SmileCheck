"""Composite food-like residue onto clean smile photos.

There is no public dataset of food residue on teeth, and stock libraries do not
license their images for model training. Synthesising the positive class from
clean photos is therefore the only route that does not involve photographing
people, and it is a standard approach for rare-defect detection.

    python synthesize_dirty.py --clean raw/clean --out raw/dirty --per-image 3

What this buys, and what it does not:

* It multiplies a small clean set into a large training set for free.
* It cannot tell you whether the model works. A classifier trained only on
  synthetic residue learns the synthesiser, not the problem. Every output here
  is named `__synth` so it can be kept out of validation and test, and
  `verify_split.py` fails the split if any leaks in.

Needs only numpy and Pillow, so it runs on the same interpreter as everything
else, without TensorFlow.
"""

from __future__ import annotations

import argparse
import json
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SUFFIXES = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}

# Marks every synthetic file. `verify_split.py` looks for exactly this.
SYNTH_TAG = "__synth"

# Plausible residue colours: leafy greens, seeds and skins, sauces, spices.
PALETTE: tuple[tuple[int, int, int], ...] = (
    (38, 58, 24),
    (54, 78, 30),
    (86, 62, 24),
    (58, 40, 22),
    (120, 40, 26),
    (150, 96, 28),
    (28, 26, 22),
    (94, 84, 40),
)


def find_teeth(image: Image.Image, rng: random.Random) -> np.ndarray | None:
    """Returns a boolean mask of likely teeth pixels, or None if unconvinced.

    Teeth are the bright, weakly-coloured region in the middle of a mouth crop.
    That is a crude rule, but it only has to be right enough to place residue
    somewhere plausible, and returning None on a bad match is safer than
    pasting food onto a cheek.
    """
    hsv = np.asarray(image.convert("HSV"), dtype=np.float32)
    saturation = hsv[..., 1] / 255.0
    value = hsv[..., 2] / 255.0

    height, width = value.shape
    mask = (value > 0.55) & (saturation < 0.42)

    # Teeth sit in the middle of the frame; the app's guide frame encourages
    # exactly that composition.
    region = np.zeros_like(mask)
    region[
        int(height * 0.20) : int(height * 0.88),
        int(width * 0.12) : int(width * 0.88),
    ] = True
    mask &= region

    if mask.mean() < 0.012:
        return None

    # Shrink the mask so residue lands inside the teeth rather than on the lip
    # boundary, where it would read as a shadow.
    eroded = Image.fromarray((mask * 255).astype(np.uint8)).filter(
        ImageFilter.MinFilter(5)
    )
    shrunk = np.asarray(eroded) > 127
    if shrunk.sum() < 200:
        return None

    del rng  # kept for signature stability; placement does the randomising
    return shrunk


def blob(
    draw: ImageDraw.ImageDraw,
    centre: tuple[int, int],
    radius: float,
    colour: tuple[int, int, int],
    alpha: int,
    rng: random.Random,
) -> None:
    """Draws one irregular lump. Real residue is never a clean ellipse."""
    points = []
    steps = rng.randint(7, 11)
    for i in range(steps):
        angle = (2 * math.pi * i) / steps
        jitter = rng.uniform(0.55, 1.45)
        points.append(
            (
                centre[0] + math.cos(angle) * radius * jitter,
                centre[1] + math.sin(angle) * radius * jitter * 0.8,
            )
        )
    draw.polygon(points, fill=(*colour, alpha))


def synthesise(
    image: Image.Image, mask: np.ndarray, rng: random.Random
) -> Image.Image:
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    ys, xs = np.nonzero(mask)
    # Bias towards the upper part of the teeth, near the gum line, which is
    # where food actually lodges.
    order = np.argsort(ys)
    candidates = order[: max(1, int(len(order) * 0.55))]

    scale = math.sqrt(image.width * image.height) / 224.0
    for _ in range(rng.randint(1, 4)):
        index = int(rng.choice(candidates))
        centre = (int(xs[index]), int(ys[index]))
        radius = rng.uniform(2.5, 7.5) * scale
        blob(
            draw,
            centre,
            radius,
            rng.choice(PALETTE),
            rng.randint(150, 240),
            rng,
        )

    # Blur softens the paste edge; without it the classifier learns to spot a
    # hard polygon boundary and nothing else.
    overlay = overlay.filter(
        ImageFilter.GaussianBlur(radius=rng.uniform(0.6, 1.8) * scale)
    )
    return Image.alpha_composite(image.convert("RGBA"), overlay).convert("RGB")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--clean", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--per-image", type=int, default=3)
    parser.add_argument("--seed", type=int, default=1337)
    args = parser.parse_args()

    sources = sorted(
        path
        for path in args.clean.iterdir()
        if path.is_file() and path.suffix.lower() in SUFFIXES
    )
    if not sources:
        raise SystemExit(f"No images in {args.clean}")

    args.out.mkdir(parents=True, exist_ok=True)
    rng = random.Random(args.seed)
    manifest: dict[str, list[str]] = {}
    skipped: list[str] = []

    for source in sources:
        with Image.open(source) as handle:
            image = handle.convert("RGB")

        mask = find_teeth(image, rng)
        if mask is None:
            skipped.append(source.name)
            continue

        produced = []
        for index in range(args.per_image):
            result = synthesise(image, mask, rng)
            name = f"{source.stem}{SYNTH_TAG}{index}.jpg"
            result.save(args.out / name, quality=92)
            produced.append(name)
        manifest[source.name] = produced

    (args.out / "manifest.json").write_text(
        json.dumps(
            {"seed": args.seed, "generated": manifest, "skipped": skipped},
            indent=2,
        )
    )

    made = sum(len(v) for v in manifest.values())
    print(f"\n  {len(manifest)} sources -> {made} synthetic images in {args.out}")
    if skipped:
        print(
            f"  {len(skipped)} skipped: no convincing teeth region found "
            f"(crop closer to the mouth)"
        )
    print(
        f"\n  Every file is tagged {SYNTH_TAG}. Keep these in train only - "
        f"a synthetic image in val or test makes the metrics meaningless.\n"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
