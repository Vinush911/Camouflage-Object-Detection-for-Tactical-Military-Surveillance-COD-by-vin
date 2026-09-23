# Target Classification Model Directory

This directory holds the target classification model and its configuration for classifying detected camouflaged regions (e.g. Soldier, Tank).

## Expected Files

1. `model.tflite`
   - TensorFlow Lite model file for target patch classification.
   - Takes cropped target regions as input (e.g. `[1, 224, 224, 3]`).
   - Produces class confidence scores / logits corresponding to the classes declared in `model_config.json`.
   - *Note: If this file is absent, the application gracefully reports "Classification model unavailable" while allowing DGNet segmentation to function fully.*

2. `model_config.json`
   - Configuration file declaring input dimensions, data type, normalization method, and the ordered list of supported class names (e.g., `["Soldier", "Tank"]`).

## How to Swap this Model

1. Place your trained TFLite classification model file in this folder.
2. Rename the model file to `model.tflite`.
3. Update `model_config.json` with the model's input resolution (e.g. 224x224) and the exact list of output class labels in matching index order.
4. Rebuild the application (`flutter clean && flutter run`). The application will inspect the runtime tensor shapes and seamlessly begin classifying segmented targets.
