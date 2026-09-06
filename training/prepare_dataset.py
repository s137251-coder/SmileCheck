"""Split collected photos into train/val/test folders.

Input, one folder per class:

    raw/clean/*.jpg
    raw/dirty/*.jpg

Output, the layout `train.py` expects:

    dataset/train/{clean,dirty}/
    dataset/val/{clean,dirty}/
    dataset/test/{clean,dirty}/

The split is by *identity*, not by file. Images of the same subject share a
group, and a group lands entirely in one split. Without that, a matched pair
like `pair01_clean.jpg` and `pair01_dirty.jpg` gets shuffled into different
splits, and since the two differ only in the food on the teeth, the model can
score well on test by recognising the face and background it already memorised
in train. The number that comes out then measures nothing.

    python prepare_dataset.py --raw raw --out dataset
"""

from __future__ import annotations

import argparse
import random
import re
import shutil
from collections import defaultdict
from pathlib import Path

from contract import CLASS_NAMES
from synthesize_dirty import SYNTH_TAG

SUFFIXES = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}

# `pair01_clean`, `pair01_dirty`, `pair01__synth3` all belong to subject
# `pair01`. Anything that does not follow a convention becomes its own group,
# which degrades safely to one-file-per-group.
_CLASS_SUFFIX = re.compile(r"_(clean|dirty)$", re.IGNORECASE)


def group_key(path: Path) -> str:
    """The subject a file belongs to."""
    stem = path.stem
    if SYNTH_TAG in stem:
        stem = stem.split(SYNTH_TAG, 1)[0]
    return _CLASS_SUFFIX.sub("", stem)


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

    # class -> group -> files
    by_group: dict[str, dict[str, list[Path]]] = defaultdict(
        lambda: defaultdict(list)
    )
    for class_name in CLASS_NAMES:
        source = args.raw / class_name
        if not source.is_dir():
            raise SystemExit(f"Missing folder: {source}")
        images = collect(source)
        if not images:
            raise SystemExit(f"No images in {source}")
        for image in images:
            by_group[class_name][group_key(image)].append(image)

    groups = sorted({g for cls in by_group.values() for g in cls})
    rng = random.Random(args.seed)
    rng.shuffle(groups)

    total = len(groups)
    n_val = max(1, round(total * args.val_fraction))
    n_test = max(1, round(total * args.test_fraction))
    if n_val + n_test >= total:
        raise SystemExit(
            f"only {total} distinct subjects; too few to split by identity. "
            f"Generate more subjects rather than more images per subject."
        )

    assignment = {}
    for group in groups[:n_val]:
        assignment[group] = "val"
    for group in groups[n_val : n_val + n_test]:
        assignment[group] = "test"
    for group in groups[n_val + n_test :]:
        assignment[group] = "train"

    counts: dict[tuple[str, str], int] = defaultdict(int)
    dropped = 0

    for class_name in CLASS_NAMES:
        for group, files in by_group[class_name].items():
            split = assignment[group]
            for image in files:
                # Generated images may only train. One whose subject was drawn
                # into val or test cannot simply be moved to train, because the
                # subject would then straddle the split, so it is dropped.
                if SYNTH_TAG in image.name and split != "train":
                    dropped += 1
                    continue
                target = args.out / split / class_name
                target.mkdir(parents=True, exist_ok=True)
                shutil.copy2(image, target / image.name)
                counts[(split, class_name)] += 1

    print(f"\nWrote {args.out}/")
    print(f"{total} subjects -> train {groups[n_val + n_test:].__len__()}, "
          f"val {n_val}, test {n_test}\n")
    for split in ("train", "val", "test"):
        row = ", ".join(
            f"{name} {counts[(split, name)]}" for name in CLASS_NAMES
        )
        n = sum(counts[(split, name)] for name in CLASS_NAMES)
        print(f"  {split:<6} {n:>5}  ({row})")

    if dropped:
        print(
            f"\n  {dropped} generated images dropped: their subject was drawn "
            f"into val or test, and moving them to train would have split a "
            f"subject across the wall."
        )

    smallest = min(counts[("train", name)] for name in CLASS_NAMES)
    if smallest < 100:
        print(
            f"\n  warning: only {smallest} training images in the smallest "
            f"class. Expect an unreliable model below a few hundred per class."
        )
    print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
