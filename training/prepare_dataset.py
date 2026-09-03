"""Split collected photos into train/val/test folders.

Input, one folder per class:

    raw/clean/*.jpg
    raw/dirty/*.jpg

Output, the layout `train.py` expects:

    dataset/train/{clean,dirty}/
    dataset/val/{clean,dirty}/
    dataset/test/{clean,dirty}/

The split is per class, so both classes keep their proportions in every split,
and it is seeded so re-running gives the same result.

    python prepare_dataset.py --raw raw --out dataset
"""

from __future__ import annotations

import argparse
import random
import shutil
from pathlib import Path

from contract import CLASS_NAMES

SUFFIXES = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def collect(folder: Path) -> list[Path]:
    return sorted(
        path
        for path in folder.iterdir()
        if path.is_file() and path.suffix.lower() in SUFFIXES
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raw", type=Path, default=Path("raw"))
    parser.add_argument("--out", type=Path, default=Path("dataset"))
    parser.add_argument("--val-fraction", type=float, default=0.15)
    parser.add_argument("--test-fraction", type=float, default=0.15)
    parser.add_argument("--seed", type=int, default=1337)
    args = parser.parse_args()

    if args.val_fraction + args.test_fraction >= 1.0:
        raise SystemExit("val + test fractions must leave room for training")

    rng = random.Random(args.seed)
    counts: dict[str, dict[str, int]] = {}

    for class_name in CLASS_NAMES:
        source = args.raw / class_name
        if not source.is_dir():
            raise SystemExit(f"Missing folder: {source}")

        images = collect(source)
        if not images:
            raise SystemExit(f"No images in {source}")

        rng.shuffle(images)
        total = len(images)
        n_val = max(1, round(total * args.val_fraction))
        n_test = max(1, round(total * args.test_fraction))
        if n_val + n_test >= total:
            raise SystemExit(
                f"{source} has only {total} images, too few to split"
            )

        splits = {
            "val": images[:n_val],
            "test": images[n_val : n_val + n_test],
            "train": images[n_val + n_test :],
        }

        for split, files in splits.items():
            target = args.out / split / class_name
            target.mkdir(parents=True, exist_ok=True)
            for image in files:
                shutil.copy2(image, target / image.name)
            counts.setdefault(split, {})[class_name] = len(files)

    print(f"\nWrote {args.out}/\n")
    for split in ("train", "val", "test"):
        row = counts[split]
        total = sum(row.values())
        balance = ", ".join(f"{name} {n}" for name, n in row.items())
        print(f"  {split:<6} {total:>5}  ({balance})")

    smallest = min(
        counts["train"][name] for name in CLASS_NAMES
    )
    if smallest < 100:
        print(
            f"\n  warning: only {smallest} training images in the smallest "
            f"class. Expect an unreliable model below a few hundred per class."
        )
    print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
