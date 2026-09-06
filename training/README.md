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

## 1b. Generate the positive class

Two ways, sharing the same teeth-finding code, the same `__synth` tag and the
same guarantee that nothing generated reaches val or test.

### Inpainting (better, costs money)

```bash
# offline first: check the masks and framing without spending anything
python inpaint_dirty.py --clean raw/clean --out raw/dirty --dry-run

set STABILITY_API_KEY=...
python inpaint_dirty.py --clean raw/clean --out raw/dirty --per-image 3
```

Masks the teeth in a real photo and asks a diffusion model to paint residue
there. Background, lighting, skin and face stay real; only the masked region is
generated.

That distinction is the whole point. If the positive class were generated whole
and the negative class photographed, the classifier would learn to separate
rendered pixels from camera pixels. That is a much easier problem, it scores
near-perfectly in validation, and it fails on the first real user. Editing one
region of a real photo removes the shortcut, because both classes come from the
same source frames. For the same reason, never generate only one class from a
source set you do not also use for the other.

`--dry-run` needs no key and makes no calls: it writes the masks to
`<out>/masks/` and a locally composited preview for each image, so the framing
can be judged first. Two guards stand between a typo and a bill: a missing key
stops the run, and `--max-requests` (default 60) refuses a batch larger than the
cap.

Providers are `stability` (default) and `openai`. Each is one function; if an
API changes, that function is the only thing to fix.

### Compositing (free, cruder)

```bash
python synthesize_dirty.py --clean raw/clean --out raw/dirty --per-image 3
```


Finds the teeth in each clean photo and composites irregular, blurred,
food-coloured lumps near the gum line. No dependencies beyond numpy and Pillow,
and no cost, but the result is obviously painted at close range.

This multiplies a small clean set into a usable training set, but it cannot tell
you whether the model works: trained on synthetic residue alone, a classifier
learns the synthesiser. So the tooling enforces the separation rather than
trusting you to remember it — `prepare_dataset.py` routes every `__synth` file
into `train`, and `verify_split.py` fails if one reaches `val` or `test`.

Which means you still need real `dirty` photos, but only tens of them, for
measurement rather than training. Around 30 in the test set is the point below
which the score is mostly noise, and `verify_split.py` warns when you are under
it.

## A dataset with no real photographs

If every image is generated, the evaluation cannot tell you how the model
behaves on a real camera frame. It measures how well the model recognises the
generator. Train on that basis knowingly: the accuracy printed at the end of
`train.py` is an optimistic bound, not a field result.

Two things still make the number worth reading, and the tooling enforces both.

**Split by subject, never by file.** Matched pairs differ only in the food on
the teeth, so the same face, background, lighting and clothing appear on both
sides. Shuffling files independently drops `pair01_clean` into train and
`pair01_dirty` into test, and the model can then score on test by recognising
what it memorised in train. `prepare_dataset.py` groups by subject, derived
from the filename, and moves whole subjects; `verify_split.py` fails the split
if any subject straddles the wall.

Name files so the grouping works: `pair01_clean.jpg`, `pair01_dirty.jpg`.
Anything not matching the convention becomes its own subject, which is safe
but wastes the protection.

**Vary the subjects, not the shots.** Thirty generated people beat three
hundred images of one. When the split is by identity, a dataset of few
subjects leaves almost nothing to test on, and `prepare_dataset.py` refuses a
split it cannot make.

## 1b-check. Validate a delivered batch first

```bash
python validate_batch.py path/to/batch.zip
python validate_batch.py path/to/batch.zip --accept-into raw
```

Every check exists because a real delivery failed it: images at 128x138 where
a mouth crop is 70x43 and residue is sub-pixel; filenames printed into the
pixels, which a model learns to read instead of looking at teeth; tiles sliced
out of a gallery screenshot, each holding fragments of two faces; and pairs
that were regenerated rather than edited, so clean and dirty differ everywhere
and the model can separate them without seeing a tooth.

`--accept-into` copies the batch into `raw/clean` and `raw/dirty` only if
everything passes, so a bad batch cannot reach the dataset by accident.

## 1c. Crop to the mouth

```bash
python crop_mouth.py --in raw/clean --out cropped/clean
python crop_mouth.py --in raw/dirty --out cropped/dirty
```

The app resizes the whole captured frame to 224x224. In an arm's-length selfie
that leaves the teeth around 25 pixels tall and a piece of food two or three
pixels across, which caps accuracy no matter how much data is thrown at it.
Cropping to the mouth lifts that ceiling.

Uses OpenCV's YuNet detector, which returns mouth-corner landmarks directly, so
the crop follows the mouth rather than assuming a centred face. The model file
is fetched once on first run. Filenames are preserved, so subject grouping
survives.

Run everything downstream on `cropped/`, not `raw/`.

**The app must apply the same crop before inference.** Training on mouths and
running on whole frames is the same mismatch in the other direction, and it
would be invisible until the app met a real user.

Note that `synthesize_dirty.py` and `inpaint_dirty.py` locate teeth by
brightness and low saturation. That works on a mouth crop and fails on a whole
selfie, where pale skin and lit walls match the same rule, so run them on
`cropped/` too.

## 2. Split

```bash
python prepare_dataset.py --raw cropped --out dataset
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
