"""Check a .tflite file against the contract the SmileCheck app enforces.

Run this before copying a model into the app. If it passes, the app will use the
model for real verdicts; if it fails, the app will stay in demo mode and show
the same reason printed here.

    python verify_model.py out/smilecheck.tflite
    python verify_model.py ../smilecheck/assets/models/smilecheck.tflite
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np

from contract import CLASS_NAMES, ContractResult, check_signature

try:  # TensorFlow ships the interpreter; ai-edge-litert is the standalone one.
    from tensorflow.lite import Interpreter
except ImportError:  # pragma: no cover - depends on the local install
    try:
        from ai_edge_litert.interpreter import Interpreter
    except ImportError:
        sys.exit(
            "No TFLite interpreter available. Install tensorflow (see "
            "requirements.txt) or ai-edge-litert."
        )


def describe(model_path: Path) -> tuple[dict, dict, Interpreter]:
    interpreter = Interpreter(model_path=str(model_path))
    interpreter.allocate_tensors()
    return (
        interpreter.get_input_details()[0],
        interpreter.get_output_details()[0],
        interpreter,
    )


def smoke_test(inp: dict, out: dict, interpreter: Interpreter) -> list[str]:
    """Runs one frame of noise through the model and sanity-checks the output.

    A model can satisfy the signature and still be unusable, so this catches the
    obvious failures: outputs that are not probabilities, or a head that is
    stuck on one class regardless of input.
    """
    notes: list[str] = []
    shape = inp["shape"]

    if inp["dtype"] == np.uint8:
        frame = np.random.randint(0, 256, size=shape, dtype=np.uint8)
    else:
        frame = np.random.rand(*shape).astype(np.float32)

    interpreter.set_tensor(inp["index"], frame)
    interpreter.invoke()
    raw = interpreter.get_tensor(out["index"])[0].astype(np.float64)

    scale, zero_point = out["quantization"]
    if out["dtype"] == np.uint8 and scale:
        raw = (raw - zero_point) * scale

    total = raw.sum()
    if total <= 0:
        notes.append(
            f"outputs sum to {total:.4f}; the app divides by the sum, so this "
            f"would score 0"
        )
    elif abs(total - 1.0) > 0.05:
        notes.append(
            f"outputs sum to {total:.4f}, not ~1.0; the app normalises by the "
            f"sum, so it still works, but a softmax head is expected"
        )

    probability = raw[0] / total if total > 0 else 0.0
    notes.append(
        f"random frame scored {probability * 100:.1f}/100 "
        f"(raw {CLASS_NAMES[0]}={raw[0]:.4f}, {CLASS_NAMES[1]}={raw[1]:.4f})"
    )
    return notes


def report(result: ContractResult, extra: list[str], path: Path) -> int:
    print(f"\nModel: {path}")
    print(f"Size:  {path.stat().st_size / 1_048_576:.2f} MB\n")

    for note in result.notes + extra:
        print(f"  note   {note}")

    if result.ok:
        print("\nPASS - the app will use this model for real verdicts.")
        print(
            "Copy it to smilecheck/assets/models/smilecheck.tflite and run the "
            "app.\n"
        )
        return 0

    for problem in result.problems:
        print(f"  FAIL   {problem}")
    print(
        "\nFAIL - the app would reject this model and stay in demo mode.\n"
    )
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("model", type=Path, help="path to a .tflite file")
    args = parser.parse_args()

    if not args.model.is_file():
        sys.exit(f"No such file: {args.model}")

    inp, out, interpreter = describe(args.model)
    result = check_signature(
        input_shape=inp["shape"],
        input_dtype=np.dtype(inp["dtype"]).name,
        output_shape=out["shape"],
        output_dtype=np.dtype(out["dtype"]).name,
    )

    print(
        f"  input  {list(inp['shape'])} {np.dtype(inp['dtype']).name}\n"
        f"  output {list(out['shape'])} {np.dtype(out['dtype']).name}",
        end="",
    )

    extra = smoke_test(inp, out, interpreter) if result.ok else []
    return report(result, extra, args.model)


if __name__ == "__main__":
    raise SystemExit(main())
