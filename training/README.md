# SmileCheck model training

Produces the `assets/models/smilecheck.tflite` the app expects: a binary
`[clean, dirty]` classifier that runs on-device.

Until such a model exists, the app runs in demo mode — it reports capture
quality and says plainly that no verdict was produced. Dropping a
contract-matching model in is the only step left; no app code changes.

## Setup

TensorFlow has no wheel for Python 3.14, which is what is currently installed on
this machine. Use 3.11 or 3.12:

```bash
py -3.12 -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

## 1. Collect photos

This is the real cost of the project. There is no public dataset of food residue
on teeth, so the images have to be collected.

```
raw/
├── clean/     smiles with nothing between or on the teeth
└── dirty/     smiles with visible food residue
```

**How many.** A few hundred per class is the floor for something that behaves
sensibly; a thousand or more per class before trusting it. Below ~100 per class
the model will memorise rather than learn, and `prepare_dataset.py` warns about
it.

**What to vary.** The spec calls for handling changing light and shooting
conditions, so the dataset has to contain them: indoor and outdoor light, warm
and cool light, front-camera and rear-camera captures, slightly different angles
and distances, with and without braces or dental work, and a genuine range of
skin and lip tones. A model trained on one person in one room will score 99% in
validation and fail on the first real user.

**How to label.** One label per photo, decided by a single rule agreed up front,
for example "visible residue between or on the front teeth at arm's length".
Borderline cases should be thrown away rather than guessed at — an inconsistent
label is worse than a missing one.

**Consent and storage.** These are photos of identifiable people. Collect them
with explicit agreement, and keep them out of the repository:
`training/.gitignore` already excludes `raw/` and `dataset/`, which matches the
app's own promise that images stay on the device.

## 2. Split

```bash
python prepare_dataset.py --raw raw --out dataset
```

Splits per class so both classes keep their proportions, seeded so re-running
gives the same result. Prints the class balance, which is worth reading — real
collections are usually lopsided, and `train.py` counter-weights that during
training.

## 3. Train

```bash
python train.py --dataset dataset --out out
```

Transfer learning on MobileNetV2: a head trained on frozen ImageNet features,
then the top 40 layers fine-tuned at a low learning rate. Exports a uint8
quantised TFLite model by default; `--float` exports float32 instead.

Writes `out/smilecheck.tflite`, `out/smilecheck.keras` and `out/metrics.json`.

## 4. Verify

```bash
python verify_model.py out/smilecheck.tflite
```

Checks the model against the same four rules the app applies at runtime, then
runs a frame through it to confirm the outputs behave like probabilities. If
this passes, the app will accept the model; if it fails, the app would reject it
and show the same reason.

The check also works on the model currently committed to the app, which is how
the 1001-class problem is visible from here:

```bash
python verify_model.py ../smilecheck/assets/models/smilecheck.tflite
```

## 5. Install

```bash
copy out\smilecheck.tflite ..\smilecheck\assets\models\smilecheck.tflite
cd ..\smilecheck
flutter run
```

The demo-mode badge should disappear and the result screen should show a real
clean/needs-check verdict.

## The contract

`contract.py` mirrors `ModelContract.validate` in
`smilecheck/lib/services/analysis_service.dart`. Change one and you must change
the other.

| Property | Required |
| --- | --- |
| Input rank | 4 — `[1, height, width, channels]` |
| Input channels | 1 or 3 |
| Input dtype | `float32` or `uint8` |
| Output classes | exactly 2 — `[clean, dirty]` |

Two details that are easy to get wrong and produce a model that loads, runs, and
returns confident nonsense:

**Input domain.** The app sends float32 models values in `[0, 1]` and uint8
models raw `0..255` bytes. MobileNetV2 expects `[-1, 1]`, so `train.py` puts a
`Rescaling` layer *inside* the model. If you train your own architecture, its
input must accept `[0, 1]`.

**Class order.** `output[0]` is P(clean), `output[1]` is P(dirty). `train.py`
pins `class_names` and asserts the order rather than relying on directory
sorting.

## Localisation of the residue

The app currently reports a verdict for the whole frame. Marking *where* the
residue is (spec 6.4) does not need a different dataset: Grad-CAM over the last
convolutional block of this same classifier gives a coarse heat map from the
labels already collected.

That is the reason to stay with one label per image rather than bounding boxes.
Boxes would give a sharper region, but cost several times more to label, and
re-labelling later is the expensive mistake. Start here; add boxes only if the
heat map proves too coarse in practice.
