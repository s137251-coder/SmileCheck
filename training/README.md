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

## Where the images come from

The two classes have opposite availability, and that shapes everything else.

**`clean` is downloadable.** Roboflow Universe carries casual smile and mouth
photos (a 2,093-image `smile` set, `mouth-seg`, `open-mouth`), which are close
to the app's own domain. Open dental sets such as AlphaDent add more.

**`dirty` is not.** Food residue on teeth is not a clinical category, so no
research dataset covers it. Two apparent sources do not work:

* *Clinical dental datasets* (caries, gingivitis, plaque segmentation) are
  intraoral photographs taken with retractors and professional lighting from a
  few centimetres away. The app takes arm's-length selfies. A model trained on
  one does not transfer to the other, and plaque is not food debris.
* *Stock libraries* do carry the right images, but the real supply is far
  smaller than the search counts suggest, and a stock licence covers publication
  of the photograph, not its use as training data.

**Check licences before training.** CelebA is restricted to non-commercial
research and the restriction extends to derived data, which includes model
weights. FFHQ's images are CC BY-NC and the dataset is CC BY-NC-SA 4.0. If
SmileCheck is going to Google Play, neither can be in its training set.

## 1. Collect photos

Given the above, the practical route is: obtain or photograph clean smiles, then
synthesise the positive class from them with `synthesize_dirty.py`, keeping a
small set of *real* residue photos aside for validation and test.

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

## 1b. Synthesise the positive class

```bash
python synthesize_dirty.py --clean raw/clean --out raw/dirty --per-image 3
```

Finds the teeth in each clean photo and composites irregular, blurred,
food-coloured lumps near the gum line. Every output is named `__synth`.

This multiplies a small clean set into a usable training set, but it cannot tell
you whether the model works: trained on synthetic residue alone, a classifier
learns the synthesiser. So the tooling enforces the separation rather than
trusting you to remember it — `prepare_dataset.py` routes every `__synth` file
into `train`, and `verify_split.py` fails if one reaches `val` or `test`.

Which means you still need real `dirty` photos, but only tens of them, for
measurement rather than training. Around 30 in the test set is the point below
which the score is mostly noise, and `verify_split.py` warns when you are under
it.

## 2. Split

```bash
python prepare_dataset.py --raw raw --out dataset
python verify_split.py --dataset dataset
```

`verify_split.py` audits the result: it fails on a synthetic image in val or
test, and on the same photo appearing in two splits. Both ruin a model while
leaving the accuracy number looking healthy.

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
