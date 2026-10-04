# DGNet Segmentation Model Directory

This directory holds the DGNet-based Camouflaged Object Detection (COD) segmentation model and its configuration.

## Current Active Model

**dgnet_best_fp16.tflite** (copied here as model.tflite)
- Backbone: DGNet with MobileNetV3 Context Branch and Texture Branch
- Input tensor : `[1, 384, 384, 3]` — RGB float32, normalized 0.0–1.0
- Output tensor: `[1, 384, 384, 1]` — single-channel probability map, float32
- Precision: Float16 weights, Float32 input/output
- File size: 7,193,228 bytes
- SHA-256: `b4839976cba4a3fb1bb6910ef2687808f49dc30821a1162da8522dfa47654ce5`

## Backup Models Kept for Safety

1. `model_dgnet_s_int8_backup.tflite` (also available as `dgnet_s_int8_backup.tflite`)
   - Previous INT8 quantized DGNet model (3,856,736 bytes)
   - SHA-256: `72bf84a830699a69d788f8cbc6909bd1bbb03dcb8325bfb8aeb615f0b482acdc`
2. `model_mobilenet_v3_384_backup.tflite`
   - Initial MobileNetV3 384 backup model (4,145,144 bytes)

## Expected Files

1. `model.tflite`
   - TensorFlow Lite model file for camouflage segmentation.
   - Exact byte-for-byte copy of `dgnet_best_fp16.tflite`.
   - Default expected input tensor: `[1, 384, 384, 3]` (RGB float32).
   - Expected output tensor: `[1, 384, 384, 1]` (single-channel binary segmentation mask/probability map).

2. `model_config.json`
   - Configuration file declaring model name, input dimensions, data type, normalization method, default sensitivity threshold, and minimum connected region area.

## How to Swap this Model

1. Place your new TFLite model file in this folder.
2. Rename the new model file to `model.tflite`.
3. If the input resolution or normalization changed, update `model_config.json` accordingly.
4. Rebuild the application (`flutter clean && flutter run`). The application dynamically inspects runtime tensor shapes and uses the new model.
