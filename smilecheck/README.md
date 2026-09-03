# SmileCheck

SmileCheck is a privacy-first smile check built with Flutter. It captures a
selfie, analyses it entirely on the device, and shows the result. No image, and
no derived data, ever leaves the phone — the Android manifest does not even
request the `INTERNET` permission.

## Local model contract

The app looks for a TensorFlow Lite model at:

```
assets/models/smilecheck.tflite
```

To be used for a verdict, the model must satisfy all of:

| Property | Required value |
| --- | --- |
| Input rank | 4 — `[1, height, width, channels]` |
| Input channels | 1 or 3 |
| Input type | `float32` (0..1) or `uint8` (0..255) |
| Output classes | exactly 2 — `[clean_score, dirty_score]` |

Input width and height are read from the model, not hard-coded, so a 128x128 or
192x192 model works without a code change. Quantised outputs are dequantised
with the tensor's own scale and zero point before the probability is taken;
outputs that can be negative are treated as logits and softmaxed.

### When the contract is not met

The app does **not** fall back to a guess dressed up as a prediction. If the
model is missing, fails to open, has the wrong signature, or throws during
inference, the result is returned in **demo mode**: the screen shows a capture
quality score, the measurements taken from the frame, and the exact reason no
verdict was produced.

> The model currently committed to this repository is
> `mobilenet_v1_1.0_224_quant` — a general-purpose ImageNet classifier with 1001
> outputs. It does not meet the contract, so the app runs in demo mode until a
> real binary clean/dirty model is trained and dropped in at the path above.
> That is the one remaining piece of work before SmileCheck gives real verdicts.

## Runtime flow

1. Capture a frame from the front camera.
2. Decode, resize and measure it in a background isolate.
3. If a contract-matching model is loaded, run the local interpreter.
4. Normalise to a 0-100 score.
5. Render the verdict, or the demo-mode explanation.

## Project layout

```
lib/
├── core/app_theme.dart          design tokens, typography, component themes
├── models/                      AnalysisResult, ImageStats, thresholds
├── screens/                     splash, home (camera), processing, result
├── services/                    camera, analysis, image preprocessing
└── widgets/                     smile guide, scan overlay, score ring, chrome
```

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --release
```

CI runs analyze, test and a release APK build on every push to `main`.
