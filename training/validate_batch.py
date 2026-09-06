"""Check a delivered batch of generated pairs before it reaches the dataset.

    python validate_batch.py path/to/batch.zip
    python validate_batch.py path/to/folder

Every check here exists because a real batch failed it:

* **Resolution.** One delivery came at 128x138. The mouth crop from that is
  about 70x43, where teeth are a white blur and a piece of food is under a
  pixel. The detail simply is not in the file.
* **Text in the pixels.** One delivery had "Image A (Clean)" printed across the
  top; another had the filename printed in the middle. A model trained on those
  learns to read the label, scores perfectly, and knows nothing.
* **Tile seams.** One delivery was a gallery screenshot sliced into tiles, so
  each file held fragments of two different faces.
* **Pairing.** The clean and dirty image of a pair must differ only in the food
  on the teeth. If they differ everywhere, they were regenerated rather than
  edited, and the model can separate them without ever looking at the teeth.

Exits non-zero if anything fails, so it can gate the pipeline.
"""

from __future__ import annotations

import argparse
import io
import re
import sys
import tempfile
import zipfile
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image

MIN_WIDTH = 640
MIN_HEIGHT = 1100
TARGET_ASPECT = 0.5625  # 9:16
ASPECT_TOLERANCE = 0.08

NAME = re.compile(r"^(pair\d+)_(clean|dirty)\.(jpg|jpeg|png)$", re.IGNORECASE)


def load(source: Path) -> dict[str, Image.Image]:
    """Reads a zip or a folder into name -> image."""
    images: dict[str, Image.Image] = {}
    if source.is_file() and source.suffix.lower() == ".zip":
        with zipfile.ZipFile(source) as archive:
            for name in archive.namelist():
                leaf = Path(name).name
                if not leaf or leaf.startswith("."):
                    continue
                try:
                    images[leaf] = Image.open(
                        io.BytesIO(archive.read(name))
                    ).convert("RGB")
                except Exception:
                    continue
    else:
        for path in sorted(source.iterdir()):
            if path.is_file():
                try:
                    images[path.name] = Image.open(path).convert("RGB")
                except Exception:
                    continue
    return images


def has_caption(image: Image.Image) -> int | None:
    """Row of a text banner, or None.

    A caption is a band that is markedly darker or lighter than the picture and
    carries high-contrast glyphs across most of its width.
    """
    grey = np.asarray(image.convert("L").resize((256, 276)), dtype=float)
    height = grey.shape[0]
    for y in range(height - 10):
        band = grey[y : y + 10, :]
        mean = band.mean()
        if mean < 70 and (band > 150).sum() > 60:
            return y
        if mean > 195 and (band < 110).sum() > 60:
            return y
    return None


def seam_strength(image: Image.Image) -> float:
    """Largest abrupt row-to-row brightness jump: a tile boundary."""
    grey = np.asarray(image.convert("L").resize((256, 276)), dtype=float)
    rows = grey.mean(axis=1)
    return float(np.abs(np.diff(rows)).max())


def pair_locality(clean: Image.Image, dirty: Image.Image) -> tuple[int, float]:
    """How many pixels changed strongly, and what share sits in the mouth band."""
    a = np.asarray(clean.resize((256, 458)), dtype=float)
    b = np.asarray(dirty.resize((256, 458)), dtype=float)
    diff = np.abs(a - b).mean(axis=2)
    strong = diff > 30
    total = int(strong.sum())
    if total == 0:
        return 0, 0.0
    height = strong.shape[0]
    band = np.zeros_like(strong)
    band[int(height * 0.50) : int(height * 0.75), :] = True
    return total, float((strong & band).sum()) / total * 100


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument(
        "--accept-into",
        type=Path,
        help="if every check passes, copy the images into this raw/ folder, "
        "splitting clean and dirty",
    )
    args = parser.parse_args()

    images = load(args.source)
    if not images:
        sys.exit(f"No readable images in {args.source}")

    problems: list[str] = []
    pairs: dict[str, dict[str, Image.Image]] = defaultdict(dict)

    print(f"\n{len(images)} files in {args.source.name}\n")

    for name, image in sorted(images.items()):
        match = NAME.match(name)
        if not match:
            problems.append(f"{name}: name does not match pairNN_clean/dirty")
            continue
        pairs[match.group(1)][match.group(2).lower()] = image

        notes = []
        w, h = image.size
        if w < MIN_WIDTH or h < MIN_HEIGHT:
            notes.append(f"too small ({w}x{h})")
        if abs(w / h - TARGET_ASPECT) > ASPECT_TOLERANCE:
            notes.append(f"not 9:16 ({w / h:.2f})")
        caption = has_caption(image)
        if caption is not None:
            notes.append(f"text in the pixels at row ~{caption}")
        seam = seam_strength(image)
        if seam > 45:
            notes.append(f"tile seam (jump {seam:.0f})")

        if notes:
            problems.append(f"{name}: " + "; ".join(notes))

    print("pairs:")
    for key in sorted(pairs):
        sides = pairs[key]
        if len(sides) != 2:
            problems.append(f"{key}: missing {'dirty' if 'clean' in sides else 'clean'}")
            print(f"  {key}  INCOMPLETE")
            continue
        changed, share = pair_locality(sides["clean"], sides["dirty"])
        flag = ""
        if changed < 200:
            flag = "  <- clean and dirty barely differ"
            problems.append(f"{key}: only {changed} pixels differ")
        elif share < 35:
            flag = "  <- change is spread over the whole frame"
            problems.append(
                f"{key}: only {share:.0f}% of the change is near the mouth"
            )
        print(f"  {key}  {changed:>6} px changed, {share:>5.1f}% near mouth{flag}")

    print()
    if problems:
        print(f"FAIL - {len(problems)} problems\n")
        for problem in problems[:25]:
            print(f"  {problem}")
        if len(problems) > 25:
            print(f"  ... and {len(problems) - 25} more")
        print()
        return 1

    print("PASS - every file is usable\n")

    if args.accept_into:
        for key, sides in pairs.items():
            for side, image in sides.items():
                folder = args.accept_into / side
                folder.mkdir(parents=True, exist_ok=True)
                image.save(folder / f"{key}_{side}.jpg", quality=95)
        print(f"  copied into {args.accept_into}/\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
