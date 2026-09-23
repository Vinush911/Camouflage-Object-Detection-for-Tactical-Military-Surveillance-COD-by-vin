import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controllers/detection_controller.dart';
import 'model/classifier/classifier_service.dart';
import 'model/dgnet/dgnet_service.dart';
import 'model/model_registry.dart';
import 'screens/home/home_screen.dart';
import 'services/cod_pipeline_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set device orientation preference to portrait for consistent camera handling
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize the central ModelRegistry (loads DGNet and Classifier models from assets)
  final modelRegistry = ModelRegistry();
  await modelRegistry.initialize();

  // Instantiate pipeline services connecting DGNet segmentation and target classification
  final dgnetService = DgnetSegmentationService(registry: modelRegistry);
  final classifierService = TargetClassificationService(registry: modelRegistry);

  final pipelineService = CodPipelineService(
    dgnet: dgnetService,
    classifier: classifierService,
  );

  // Instantiate controller for managing detection state
  final detectionController = DetectionController(pipeline: pipelineService);

  runApp(CodVisionApp(controller: detectionController));
}

// Root Application Widget
class CodVisionApp extends StatelessWidget {
  final DetectionController controller;

  const CodVisionApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'COD Vision Research',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A), // Deep Navy
          primary: const Color(0xFF1E3A8A),
          secondary: const Color(0xFF0D9488), // Teal
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: HomeScreen(controller: controller),
    );
  }
}
