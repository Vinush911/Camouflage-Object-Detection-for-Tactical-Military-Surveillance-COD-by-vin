import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:android_app/config/app_config.dart';
import 'package:android_app/controllers/detection_controller.dart';
import 'package:android_app/data_models/detection_result.dart';
import 'package:android_app/data_models/model_metadata.dart';
import 'package:android_app/main.dart';
import 'package:android_app/services/cod_inference_service.dart';

// Mock inference service for host widget testing
class MockInferenceService implements CodInferenceService {
  @override
  ModelMetadata get metadata => ModelMetadata.dgnetMobileNetV3();

  @override
  Future<void> initialize() async {}

  @override
  Future<DetectionResult> runInference(
    img.Image inputImage, {
    double threshold = AppConfig.defaultThreshold,
    int minRegionArea = AppConfig.defaultMinRegionAreaPixels,
  }) async {
    return DetectionResult(
      originalWidth: inputImage.width,
      originalHeight: inputImage.height,
      maskWidth: AppConfig.inputWidth,
      maskHeight: AppConfig.inputHeight,
      probabilityMask: Float32List(AppConfig.inputWidth * AppConfig.inputHeight),
      binaryMask: Uint8List(AppConfig.inputWidth * AppConfig.inputHeight),
      regions: [],
      preprocessingMs: 5.0,
      inferenceMs: 30.0,
      postprocessingMs: 3.0,
      totalMs: 38.0,
    );
  }

  @override
  void dispose() {}
}

void main() {
  testWidgets('App renders Home Screen with main action buttons', (WidgetTester tester) async {
    final mockService = MockInferenceService();
    final controller = DetectionController(inferenceService: mockService);

    await tester.pumpWidget(CodVisionApp(controller: controller));

    // Verify Title and Subtitle
    expect(find.text('COD VISION'), findsOneWidget);
    expect(find.text('Camouflaged Object Detection'), findsOneWidget);

    // Verify Action Buttons
    expect(find.text('CAPTURE IMAGE'), findsOneWidget);
    expect(find.text('SELECT FROM GALLERY'), findsOneWidget);
    expect(find.text('LIVE CAMERA STREAM'), findsOneWidget);
    expect(find.text('PERFORMANCE BENCHMARK'), findsOneWidget);

    // Verify Technical Footer
    expect(find.text('Offline / On-Device TFLite'), findsOneWidget);
  });
}
