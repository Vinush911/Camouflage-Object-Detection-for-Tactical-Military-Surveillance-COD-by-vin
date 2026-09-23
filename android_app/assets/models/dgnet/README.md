# DGNet Segmentation Model Directory

This directory holds the DGNet-based Camouflaged Object Detection (COD) segmentation model and its configuration.

## Current Active Model

**dgnet_s_int8.tflite** (copied here as model.tflite)
- Backbone: DGNet-S (small variant)
- Input tensor : `[1, 384, 384, 3]` — RGB float32, normalized 0.0–1.0
- Output tensor: `[1, 384, 384, 1]` — single-channel probability map, float32
- External quantization: none (scale=0.0, zero_point=0)
- Note: "int8" in the filename refers to internal weight quantization; I/O tensors remain float32.

## Expected Files

1. `model.tflite`
   - TensorFlow Lite model file for camouflage segmentation.
   - Default expected input tensor: `[1, 384, 384, 3]` (RGB float32).
   - Expected output tensor: `[1, 384, 384, 1]` (single-channel binary segmentation mask/probability map).

2. `model_config.json`
   - Configuration file declaring model name, input dimensions, data type, normalization method, default sensitivity threshold, and minimum connected region area.

## How to Swap this Model

1. Place your new TFLite model file in this folder.
2. Rename the new model file to `model.tflite`.
3. If the input resolution or normalization changed (for example, from 384x384 to 640x640), update `model_config.json` accordingly.
4. Rebuild the application (`flutter clean && flutter run`). The application will dynamically inspect the runtime tensor shapes and use the new model without needing changes to Dart code.
