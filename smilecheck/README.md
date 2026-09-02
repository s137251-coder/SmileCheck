# SmileCheck

SmileCheck is a privacy-first local dental smile analysis app built with Flutter.

## Local model contract

The application expects a local TensorFlow Lite model at:

assets/models/smilecheck.tflite

The current model integration supports:
- input tensor shape: [1, 224, 224, 3]
- 3-channel RGB image preprocessing
- binary output probability vector of length 2
- output convention: [clean_score, dirty_score]

If the model is not present, the app falls back to a transparent local quality estimate and a visible demo label instead of pretending a model ran.

## Runtime flow

1. Capture image from camera
2. Preprocess to a 224x224 RGB tensor
3. Run the local TFLite interpreter
4. Normalize probabilities to a score in the range 0-100
5. Render result screen with the model label or fallback label
