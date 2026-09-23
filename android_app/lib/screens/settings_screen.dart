import 'package:flutter/material.dart';
import '../controllers/detection_controller.dart';
import 'model_info/model_info_screen.dart';

// SettingsScreen wrapper maintaining compatibility while routing to ModelInfoScreen
class SettingsScreen extends StatelessWidget {
  final DetectionController controller;

  const SettingsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ModelInfoScreen(controller: controller);
  }
}
