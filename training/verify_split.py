"""Audit a prepared dataset before training.

Two ways a split quietly ruins a model, both invisible in the accuracy number:

* a synthetic image in val or test, which measures the synthesiser rather than
  the problem;
* the same photo in two splits, which measures memorisation.

    python verify_split.py --dataset dataset

Exits non-zero on either, so it can gate a training run.
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from collections import defaultdict
from pathlib import Path

from contract import CLASS_NAMES
from synthesize_dirty import SYNTH_TAG

SPLITS = ("train", "val", "test")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", type=Path, default=Path("dataset"))
    parser.add_argument(
        "--allow-synthetic-in-train",
        action="store_true",
        default=True,
        help=argparse.SUPPRESS,
    )
    args = parser.parse_args()

    problems: list[str] = []
    seen: dict[str, list[str]] = defaultdict(list)
    counts: dict[tuple[str, str], int] = {}
    synthetic: dict[str, int] = defaultdict(int)

    for split in SPLITS:
        for class_name in CLASS_NAMES:
            folder = args.dataset / split / class_name
            if not folder.is_dir():
                problems.append(f"missing folder: {folder}")
                continue

            files = [p for p in folder.iterdir() if p.is_file()]
            counts[(split, class_name)] = len(files)

            for path in files:
                if SYNTH_TAG in path.name:
                    synthetic[split] += 1
                    if split != "train":
                        problems.append(
                            f"synthetic image in {split}: {path.name}"
                        )
                seen[digest(path)].append(f"{split}/{class_name}/{path.name}")

    for locations in seen.values():
        splits = {loc.split("/", 1)[0] for loc in locations}
        if len(splits) > 1:
            problems.append(
                "same image in multiple splits: " + ", ".join(sorted(locations))
            )

    print(f"\nDataset: {args.dataset}\n")
    for split in SPLITS:
        row = [
            f"{name} {counts.get((split, name), 0)}" for name in CLASS_NAMES
        ]
        total = sum(counts.get((split, name), 0) for name in CLASS_NAMES)
        tag = f"  [{synthetic[split]} synthetic]" if synthetic[split] else ""
        print(f"  {split:<6} {total:>5}  ({', '.join(row)}){tag}")

    real_positives = counts.get(("test", CLASS_NAMES[1]), 0)
    print()
    if real_positives == 0:
        print(
            f"  warning: the test set has no {CLASS_NAMES[1]} images at all, "
            f"so nothing measures whether the model detects residue."
        )
    elif real_positives < 30:
        print(
            f"  warning: only {real_positives} real {CLASS_NAMES[1]} images in "
            f"test. Below ~30 the score is mostly noise."
        )

    if problems:
        print("\nFAIL")
        for problem in problems:
            print(f"  {problem}")
        print()
        return 1

    print("\nPASS - splits are disjoint and val/test are free of synthetics.\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
