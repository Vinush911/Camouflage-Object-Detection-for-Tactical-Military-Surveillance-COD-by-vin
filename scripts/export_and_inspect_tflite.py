#!/usr/bin/env python3
"""
Export DGNet to TFLite and inspect tensor shapes and datatypes.
This script loads the trained DGNet model, converts it to TensorFlow Lite format,
and prints detailed information about the input and output tensors.
"""

import json
import os
import sys
from pathlib import Path
import numpy as np
import tensorflow as tf

# Add the project directory so we can import our model modules
PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.models.dgnet import build_dgnet_model


def export_and_inspect():
    print("[1/4] Preparing model for export...")
    image_size = (384, 384)
    backbone = "mobilenet_v3_large"
    weights_path = PROJECT_ROOT / "models/raw_checkpoints/dgnet_best.weights.h5"
    output_tflite_path = PROJECT_ROOT / "models/quantized/dgnet_mobilenet_v3_384.tflite"
    output_tflite_path.parent.mkdir(parents=True, exist_ok=True)

    # Build the model structure
    # We set pretrained=False because we will load our trained weights
    model = build_dgnet_model(
        backbone_name=backbone,
        input_shape=(image_size[0], image_size[1], 3),
        gradient_kernel="sobel",
        pretrained=False
    )

    # Run dummy input once to initialize the weights
    dummy_input = tf.zeros((1, image_size[0], image_size[1], 3), dtype=tf.float32)
    _ = model(dummy_input, training=False)

    if weights_path.exists():
        print(f"Loading trained weights from {weights_path.resolve()}...")
        model.load_weights(str(weights_path))
        print("Trained weights loaded successfully.")
    else:
        print(f"Warning: {weights_path} not found. Proceeding with initialized model.")

    print("\n[2/4] Converting model to TensorFlow Lite...")
    # Concrete function for inference mode
    @tf.function(input_signature=[tf.TensorSpec([1, image_size[0], image_size[1], 3], tf.float32, name="image_input")])
    def serving_fn(input_tensor):
        # When training=False, DGNet returns sigmoid(mask_logits)
        return model(input_tensor, training=False)

    concrete_func = serving_fn.get_concrete_function()
    converter = tf.lite.TFLiteConverter.from_concrete_functions([concrete_func])
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

    tflite_bytes = converter.convert()

    with open(output_tflite_path, "wb") as f:
        f.write(tflite_bytes)

    file_size_mb = len(tflite_bytes) / (1024 * 1024)
    print(f"Saved TFLite model to: {output_tflite_path.resolve()} ({file_size_mb:.2f} MB)")

    print("\n[3/4] Inspecting TFLite Interpreter details...")
    interpreter = tf.lite.Interpreter(model_path=str(output_tflite_path))
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print("\n--- Model Inputs ---")
    inputs_info = []
    for i, inp in enumerate(input_details):
        info = {
            "index": i,
            "name": inp["name"],
            "shape": inp["shape"].tolist(),
            "dtype": str(np.dtype(inp["dtype"])),
            "quantization": inp["quantization"]
        }
        inputs_info.append(info)
        print(f"  Input #{i}: name='{inp['name']}', shape={inp['shape']}, dtype={inp['dtype']}, quant={inp['quantization']}")

    print("\n--- Model Outputs ---")
    outputs_info = []
    for i, out in enumerate(output_details):
        info = {
            "index": i,
            "name": out["name"],
            "shape": out["shape"].tolist(),
            "dtype": str(np.dtype(out["dtype"])),
            "quantization": out["quantization"]
        }
        outputs_info.append(info)
        print(f"  Output #{i}: name='{out['name']}', shape={out['shape']}, dtype={out['dtype']}, quant={out['quantization']}")

    # Test run with dummy data to check output values
    print("\n[4/4] Testing sample inference...")
    test_input = np.random.uniform(0.0, 1.0, size=input_details[0]["shape"]).astype(np.float32)
    interpreter.set_tensor(input_details[0]["index"], test_input)
    interpreter.invoke()
    test_output = interpreter.get_tensor(output_details[0]["index"])

    print(f"Test output shape: {test_output.shape}")
    print(f"Test output min value: {np.min(test_output):.4f}")
    print(f"Test output max value: {np.max(test_output):.4f}")
    print(f"Test output mean value: {np.mean(test_output):.4f}")

    # Save manifest for documentation and Flutter app reference
    manifest_path = PROJECT_ROOT / "docs/tflite_tensor_manifest.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_data = {
        "model_file": str(output_tflite_path.name),
        "file_size_mb": round(file_size_mb, 2),
        "backbone": backbone,
        "input_dimensions": [image_size[0], image_size[1], 3],
        "inputs": inputs_info,
        "outputs": outputs_info,
        "output_range": {
            "min": float(np.min(test_output)),
            "max": float(np.max(test_output)),
            "mean": float(np.mean(test_output))
        }
    }
    with open(manifest_path, "w") as f:
        json.dump(manifest_data, f, indent=2)

    print(f"\nManifest successfully written to: {manifest_path.resolve()}")
    print("Export and verification complete!")


if __name__ == "__main__":
    export_and_inspect()
