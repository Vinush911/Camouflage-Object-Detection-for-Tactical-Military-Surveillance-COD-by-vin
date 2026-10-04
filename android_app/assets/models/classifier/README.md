# Target Classification Model Directory

This directory holds the target classification model and its configuration for classifying detected camouflaged regions (Class 0: "Non-Target", Class 1: "Camouflaged Target").

## Current Status: TRAINED DEMONSTRATION CLASSIFIER

- **Model File**: `model.tflite` (exact copy of `classifier_demonstration.tflite`)
- **Architecture**: EfficientNet-B0 backbone (with ImageNet pretrained weights) + Global Average Pooling + Dropout(0.2) + 2-class Softmax classification head
- **Training**: Trained on demonstration camouflage patterns (woodland, desert, tactical disruption) vs natural non-target textures
- **Input Dimensions**: `[1, 224, 224, 3]` (RGB float32 normalized 0.0–1.0)
- **Output Dimensions**: `[1, 2]` (Softmax class probabilities)
- **Classes**:
  - Index 0: `Non-Target`
  - Index 1: `Camouflaged Target`
- **Purpose**: Demonstrates the end-to-end DGNet → ROI → Classifier pipeline with learned features, ready to be evaluated in the Flutter app before final production dataset training.

## How to Swap for Final Production Trained Classifier

When the final production model is trained:
1. Place your final trained TFLite classification model file in this folder.
2. Rename the trained model file to `model.tflite`.
3. If input dimensions or class labels change, update `model_config.json`.
4. Rebuild the application (`flutter clean && flutter run`). The application dynamically inspects runtime tensor shapes and uses the new model without needing changes to Dart code.
