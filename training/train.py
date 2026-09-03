"""Train the SmileCheck binary classifier and export it as TFLite.

Transfer learning on MobileNetV2: train a small head on frozen ImageNet
features, then fine-tune the top of the backbone at a low learning rate.

    python train.py --dataset dataset --out out

The export is what matters for the app, and two details make it work:

* **Input domain.** The app feeds float32 models values in [0, 1] and uint8
  models raw 0..255 bytes. MobileNetV2 wants [-1, 1], so the rescaling is a
  layer *inside* the model rather than a preprocessing step the app would have
  to know about. Getting this wrong produces a model that loads, runs, and
  returns confident nonsense.
* **Class order.** output[0] is P(clean) and output[1] is P(dirty), which the
  script asserts rather than assumes.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

from contract import CLASS_NAMES, IMAGE_SIZE, OUTPUT_CLASSES

AUTOTUNE = tf.data.AUTOTUNE


def load_split(
    root: Path,
    split: str,
    batch_size: int,
    shuffle: bool,
    augment: bool = False,
):
    """Loads one split, scaled to the [0, 1] domain the model expects."""
    dataset = keras.utils.image_dataset_from_directory(
        root / split,
        labels="inferred",
        label_mode="categorical",
        class_names=list(CLASS_NAMES),
        image_size=(IMAGE_SIZE, IMAGE_SIZE),
        batch_size=batch_size,
        shuffle=shuffle,
        seed=1337,
    )
    # Keras assigns indices in the order of `class_names`, so this is the point
    # where the contract's [clean, dirty] order is fixed.
    assert dataset.class_names == list(CLASS_NAMES), dataset.class_names

    dataset = dataset.map(
        lambda x, y: (x / 255.0, y), num_parallel_calls=AUTOTUNE
    )

    if augment:
        # Augmentation belongs to the input pipeline, not the model. Keras
        # augmentation layers are inference no-ops, but leaving them in the
        # graph means the TFLite converter has to strip them, and a random op
        # that survives would randomise real predictions on the phone.
        augmentation = build_augmentation()
        dataset = dataset.map(
            lambda x, y: (augmentation(x, training=True), y),
            num_parallel_calls=AUTOTUNE,
        )

    return dataset.prefetch(AUTOTUNE)


def build_augmentation() -> keras.Sequential:
    """Augmentation aimed at the variation the spec calls out: hand-held
    selfies under changing light, from slightly different angles."""
    return keras.Sequential(
        [
            layers.RandomFlip("horizontal"),
            layers.RandomRotation(0.06),
            layers.RandomZoom(0.12),
            layers.RandomTranslation(0.06, 0.06),
            layers.RandomBrightness(0.22, value_range=(0.0, 1.0)),
            layers.RandomContrast(0.22),
        ],
        name="augmentation",
    )


def build_model(dropout: float) -> tuple[keras.Model, keras.Model]:
    backbone = keras.applications.MobileNetV2(
        input_shape=(IMAGE_SIZE, IMAGE_SIZE, 3),
        include_top=False,
        weights="imagenet",
    )
    backbone.trainable = False

    inputs = keras.Input(shape=(IMAGE_SIZE, IMAGE_SIZE, 3), name="image")
    # [0, 1] -> [-1, 1]. This is the layer that keeps the app's preprocessing
    # and MobileNetV2's expectations in agreement, and the only preprocessing
    # that belongs inside the exported model.
    x = layers.Rescaling(scale=2.0, offset=-1.0, name="to_mobilenet_range")(inputs)
    x = backbone(x, training=False)
    x = layers.GlobalAveragePooling2D(name="pool")(x)
    x = layers.Dropout(dropout, name="dropout")(x)
    outputs = layers.Dense(
        OUTPUT_CLASSES, activation="softmax", name="clean_dirty"
    )(x)

    return keras.Model(inputs, outputs, name="smilecheck"), backbone


def class_weights(root: Path) -> dict[int, float]:
    """Counter-weights an unbalanced dataset, which collected data usually is."""
    counts = []
    for name in CLASS_NAMES:
        folder = root / "train" / name
        counts.append(sum(1 for _ in folder.iterdir() if _.is_file()))

    total = sum(counts)
    return {
        index: total / (len(counts) * max(count, 1))
        for index, count in enumerate(counts)
    }


def representative_dataset(dataset, samples: int):
    """Feeds real frames to the quantiser so it can pick sensible ranges."""

    def generator():
        taken = 0
        for batch, _ in dataset:
            for image in batch:
                if taken >= samples:
                    return
                yield [tf.expand_dims(image, 0)]
                taken += 1

    return generator


def export(
    model: keras.Model,
    out_dir: Path,
    calibration,
    quantise: bool,
) -> Path:
    converter = tf.lite.TFLiteConverter.from_keras_model(model)

    if quantise:
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.representative_dataset = representative_dataset(
            calibration, samples=200
        )
        converter.target_spec.supported_ops = [
            tf.lite.OpsSet.TFLITE_BUILTINS_INT8
        ]
        # The app sends raw bytes to a uint8 model and dequantises the output
        # with the tensor's own scale and zero point.
        converter.inference_input_type = tf.uint8
        converter.inference_output_type = tf.uint8

    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / "smilecheck.tflite"
    path.write_bytes(converter.convert())
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", type=Path, default=Path("dataset"))
    parser.add_argument("--out", type=Path, default=Path("out"))
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--epochs", type=int, default=15)
    parser.add_argument("--finetune-epochs", type=int, default=10)
    parser.add_argument("--finetune-layers", type=int, default=40)
    parser.add_argument("--dropout", type=float, default=0.3)
    parser.add_argument(
        "--float",
        dest="quantise",
        action="store_false",
        help="export float32 instead of the default uint8 quantised model",
    )
    args = parser.parse_args()

    train = load_split(
        args.dataset, "train", args.batch_size, shuffle=True, augment=True
    )
    val = load_split(args.dataset, "val", args.batch_size, shuffle=False)
    test = load_split(args.dataset, "test", args.batch_size, shuffle=False)

    model, backbone = build_model(args.dropout)
    model.compile(
        optimizer=keras.optimizers.Adam(1e-3),
        loss="categorical_crossentropy",
        metrics=["accuracy", keras.metrics.AUC(name="auc")],
    )

    weights = class_weights(args.dataset)
    print(f"\nClass weights: {weights}\n")

    stop = keras.callbacks.EarlyStopping(
        monitor="val_auc", mode="max", patience=5, restore_best_weights=True
    )

    print("Phase 1: training the head on frozen features")
    model.fit(
        train,
        validation_data=val,
        epochs=args.epochs,
        class_weight=weights,
        callbacks=[stop],
    )

    if args.finetune_epochs > 0:
        print(f"\nPhase 2: fine-tuning the top {args.finetune_layers} layers")
        backbone.trainable = True
        for layer in backbone.layers[: -args.finetune_layers]:
            layer.trainable = False
        # BatchNorm statistics must stay frozen or the small dataset will wreck
        # them.
        for layer in backbone.layers:
            if isinstance(layer, layers.BatchNormalization):
                layer.trainable = False

        model.compile(
            optimizer=keras.optimizers.Adam(1e-5),
            loss="categorical_crossentropy",
            metrics=["accuracy", keras.metrics.AUC(name="auc")],
        )
        model.fit(
            train,
            validation_data=val,
            epochs=args.finetune_epochs,
            class_weight=weights,
            callbacks=[stop],
        )

    print("\nHeld-out test set:")
    scores = model.evaluate(test, return_dict=True)

    args.out.mkdir(parents=True, exist_ok=True)
    model.save(args.out / "smilecheck.keras")
    (args.out / "metrics.json").write_text(
        json.dumps(
            {
                "test": {k: float(v) for k, v in scores.items()},
                "classes": list(CLASS_NAMES),
                "input_size": IMAGE_SIZE,
                "quantised": args.quantise,
            },
            indent=2,
        )
    )

    # Calibrate on un-augmented frames: the phone sends real captures, not
    # brightness-jittered ones.
    calibration = load_split(
        args.dataset, "train", args.batch_size, shuffle=False
    )
    path = export(model, args.out, calibration=calibration, quantise=args.quantise)
    size_mb = path.stat().st_size / 1_048_576
    print(f"\nWrote {path} ({size_mb:.2f} MB)")
    print(f"Now run:  python verify_model.py {path}\n")

    # A quick self-check so an obviously broken export is caught here rather
    # than silently on the phone.
    interpreter = tf.lite.Interpreter(model_path=str(path))
    interpreter.allocate_tensors()
    detail = interpreter.get_output_details()[0]
    if detail["shape"][-1] != OUTPUT_CLASSES:
        raise SystemExit(
            f"Export produced {detail['shape'][-1]} outputs, not "
            f"{OUTPUT_CLASSES}. The app would reject this model."
        )

    return 0


if __name__ == "__main__":
    np.random.seed(1337)
    tf.random.set_seed(1337)
    raise SystemExit(main())
