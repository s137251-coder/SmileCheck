"""The model contract the SmileCheck app enforces at runtime.

This is the Python mirror of `ModelContract.validate` in
`smilecheck/lib/services/analysis_service.dart`. The two must agree: if this
file says a model passes, the app must accept it, and vice versa.

Keeping the rules here, rather than inline in the training script, is what lets
`verify_model.py` check a model the app has never seen.
"""

from __future__ import annotations

from dataclasses import dataclass, field

# Index order is part of the contract: output[0] is P(clean), output[1] is
# P(dirty). Sorted alphabetically, which is also how Keras assigns class
# indices from directory names, so the two line up by construction.
CLASS_NAMES: tuple[str, str] = ("clean", "dirty")

IMAGE_SIZE = 224
OUTPUT_CLASSES = 2
ALLOWED_INPUT_DTYPES = ("float32", "uint8")
ALLOWED_CHANNELS = (1, 3)

# The app hands float32 models values in [0, 1] and uint8 models raw 0..255
# bytes. A model that wants MobileNet's native [-1, 1] must therefore do that
# rescaling *inside* itself; `train.py` bakes in a Rescaling layer for exactly
# this reason.
INPUT_DOMAIN = "[0, 1] for float32 input, 0..255 for uint8 input"


@dataclass
class ContractResult:
    ok: bool
    problems: list[str] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)


def check_signature(
    input_shape,
    input_dtype: str,
    output_shape,
    output_dtype: str,
) -> ContractResult:
    """Applies the same four rules the Dart side applies, in the same order."""
    problems: list[str] = []
    notes: list[str] = []

    shape = list(input_shape)
    if len(shape) != 4:
        problems.append(
            f"input is rank {len(shape)}; the app needs "
            f"[1, height, width, channels]"
        )
        return ContractResult(False, problems, notes)

    channels = shape[3]
    if channels not in ALLOWED_CHANNELS:
        problems.append(
            f"input has {channels} channels; the app supports "
            f"{' or '.join(str(c) for c in ALLOWED_CHANNELS)}"
        )

    if input_dtype not in ALLOWED_INPUT_DTYPES:
        problems.append(
            f"input dtype is {input_dtype}; the app supplies "
            f"{' or '.join(ALLOWED_INPUT_DTYPES)}"
        )

    classes = list(output_shape)[-1] if len(output_shape) else 0
    if classes != OUTPUT_CLASSES:
        problems.append(
            f"output has {classes} classes; the app needs exactly "
            f"{OUTPUT_CLASSES}: {list(CLASS_NAMES)}"
        )

    if shape[1] != shape[2]:
        notes.append(
            f"input is {shape[1]}x{shape[2]}, not square; the app resizes to "
            f"whatever the model asks for, so this works but is unusual"
        )
    if shape[1] != IMAGE_SIZE:
        notes.append(
            f"input is {shape[1]}px; the app reads the size from the model, so "
            f"this is fine, but training defaults to {IMAGE_SIZE}px"
        )
    if output_dtype == "uint8":
        notes.append(
            "output is quantised; the app dequantises with the tensor's own "
            "scale and zero point before taking the probability"
        )

    return ContractResult(not problems, problems, notes)
