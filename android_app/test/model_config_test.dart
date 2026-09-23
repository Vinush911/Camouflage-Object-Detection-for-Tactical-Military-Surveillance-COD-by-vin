import 'package:flutter_test/flutter_test.dart';
import 'package:android_app/model/model_config.dart';

void main() {
  group('ModelConfig Tests', () {
    test('parses DGNet segmentation config JSON properly', () {
      final json = {
        'model_name': 'DGNet-MobileNetV3',
        'task': 'segmentation',
        'input_width': 384,
        'input_height': 384,
        'input_channels': 3,
        'input_type': 'float32',
        'normalization': 'zero_to_one',
        'output_activation': 'none',
        'threshold': 0.35,
        'min_region_area': 150,
      };

      final config = ModelConfig.fromJson(json);

      expect(config.modelName, 'DGNet-MobileNetV3');
      expect(config.task, 'segmentation');
      expect(config.inputWidth, 384);
      expect(config.inputHeight, 384);
      expect(config.inputChannels, 3);
      expect(config.inputType, 'float32');
      expect(config.normalization, 'zero_to_one');
      expect(config.outputActivation, 'none');
      expect(config.threshold, 0.35);
      expect(config.minRegionArea, 150);
      expect(config.classes, isEmpty);
    });

    test('parses Classifier config JSON with class labels properly', () {
      final json = {
        'model_name': 'Target Classifier',
        'task': 'classification',
        'input_width': 224,
        'input_height': 224,
        'input_channels': 3,
        'input_type': 'float32',
        'normalization': 'minus_one_to_one',
        'classes': ['Soldier', 'Tank', 'Armored Vehicle'],
      };

      final config = ModelConfig.fromJson(json);

      expect(config.modelName, 'Target Classifier');
      expect(config.task, 'classification');
      expect(config.inputWidth, 224);
      expect(config.inputHeight, 224);
      expect(config.normalization, 'minus_one_to_one');
      expect(config.classes.length, 3);
      expect(config.classes, ['Soldier', 'Tank', 'Armored Vehicle']);
    });

    test('falls back safely when optional fields are missing', () {
      final json = <String, dynamic>{};
      final config = ModelConfig.fromJson(json);

      expect(config.modelName, 'Unnamed Model');
      expect(config.task, 'segmentation');
      expect(config.inputWidth, 384);
      expect(config.inputHeight, 384);
      expect(config.threshold, 0.30);
      expect(config.minRegionArea, 120);
      expect(config.classes, isEmpty);
    });

    test('serializes config to JSON map accurately', () {
      const config = ModelConfig(
        modelName: 'Custom-Classifier',
        task: 'classification',
        inputWidth: 256,
        inputHeight: 256,
        classes: ['Sniper', 'Vehicle'],
      );

      final json = config.toJson();

      expect(json['model_name'], 'Custom-Classifier');
      expect(json['task'], 'classification');
      expect(json['input_width'], 256);
      expect(json['input_height'], 256);
      expect(json['classes'], ['Sniper', 'Vehicle']);
    });
  });
}
