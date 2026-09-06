"""Crop selfies down to the mouth.

The app resizes the whole captured frame to the model's 224x224. In an
arm's-length selfie that leaves the teeth about 25 pixels tall and a piece of
food two or three pixels across, which caps how well any model can do no matter
how much data it is trained on. Cropping to the mouth first is what lifts that
ceiling.

    python crop_mouth.py --in raw/clean --out cropped/clean
    python crop_mouth.py --in raw/dirty --out cropped/dirty

Uses OpenCV's YuNet detector, which returns the two mouth-corner landmarks
directly, so the crop follows the actual mouth rather than assuming the face is
centred. Filenames are preserved, which keeps `pairXX_clean` / `pairXX_dirty`
grouping intact for `prepare_dataset.py`.

Whatever crop is used here must also be applied in the app before inference.
Training on mouths and running on whole frames would be the same mismatch in
the other direction.
"""

from __future__ import annotations

import argparse
import urllib.request
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

MODEL_FILE = "face_detection_yunet.onnx"
MODEL_URL = (
    "https://github.com/opencv/opencv_zoo/raw/main/models/"
    "face_detection_yunet/face_detection_yunet_2023mar.onnx"
)

SUFFIXES = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def ensure_model(path: Path) -> Path:
    if not path.is_file():
        print(f"  fetching {MODEL_FILE} (about 230 KB) ...")
        urllib.request.urlretrieve(MODEL_URL, path)
    return path


def detector(model: Path) -> cv2.FaceDetectorYN:
    return cv2.FaceDetectorYN.create(str(model), "", (320, 320), 0.5, 0.3, 5000)


def mouth_box(
    det: cv2.FaceDetectorYN, image: Image.Image, pad: float
) -> tuple[int, int, int, int] | None:
    """Returns the crop rectangle around the mouth, or None if no face."""
    bgr = cv2.cvtColor(np.asarray(image), cv2.COLOR_RGB2BGR)
    height, width = bgr.shape[:2]
    det.setInputSize((width, height))
    _, faces = det.detect(bgr)
    if faces is None or len(faces) == 0:
        return None

    face = max(faces, key=lambda f: f[2] * f[3])
    # YuNet landmarks: right eye, left eye, nose, right mouth corner, left
    # mouth corner.
    right, left = (face[10], face[11]), (face[12], face[13])
    centre_x = (right[0] + left[0]) / 2
    centre_y = (right[1] + left[1]) / 2
    mouth_width = abs(left[0] - right[0])
    if mouth_width < 8:
        return None

    box_w = mouth_width * pad
    box_h = box_w * 0.62
    x0 = int(max(0, centre_x - box_w / 2))
    y0 = int(max(0, centre_y - box_h / 2))
    x1 = int(min(width, centre_x + box_w / 2))
    y1 = int(min(height, centre_y + box_h / 2))
    if x1 - x0 < 32 or y1 - y0 < 20:
        return None
    return x0, y0, x1, y1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--in", dest="source", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument(
        "--pad",
        type=float,
        default=2.1,
        help="crop width as a multiple of the mouth width (default 2.1, which "
        "keeps the lips and a little chin)",
    )
    args = parser.parse_args()

    model = ensure_model(Path(__file__).with_name(MODEL_FILE))
    det = detector(model)

    sources = sorted(
        p
        for p in args.source.iterdir()
        if p.is_file() and p.suffix.lower() in SUFFIXES
    )
    if not sources:
        raise SystemExit(f"No images in {args.source}")

    args.out.mkdir(parents=True, exist_ok=True)
    done, missed = 0, []

    for path in sources:
        with Image.open(path) as handle:
            image = handle.convert("RGB")
        box = mouth_box(det, image, args.pad)
        if box is None:
            missed.append(path.name)
            continue
        image.crop(box).save(args.out / f"{path.stem}.jpg", quality=95)
        done += 1

    print(f"\n  {done}/{len(sources)} cropped into {args.out}")
    if missed:
        print(f"  {len(missed)} had no detectable face:")
        for name in missed[:10]:
            print(f"    {name}")
    print()
    return 1 if missed else 0


if __name__ == "__main__":
    raise SystemExit(main())
