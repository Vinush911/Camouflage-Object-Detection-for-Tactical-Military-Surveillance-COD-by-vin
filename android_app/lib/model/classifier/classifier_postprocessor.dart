import 'dart:math';
import '../model_config.dart';

// Postprocesses the raw output from the classification model.
// Finds the predicted category index and assigns the corresponding class label and confidence score.

class ClassificationPrediction {
  final String className;
  final double confidence;
  final int classIndex;

  const ClassificationPrediction({
    required this.className,
    required this.confidence,
    required this.classIndex,
  });
}

class ClassifierPostprocessor {
  // Postprocesses classification output tensor [1, num_classes]
  ClassificationPrediction process(
    dynamic rawOutput,
    ModelConfig config,
  ) {
    List<double> scores = [];

    if (rawOutput is List && rawOutput.isNotEmpty) {
      final first = rawOutput[0];
      if (first is List) {
        scores = first.map((e) => (e as num).toDouble()).toList();
      }
    }

    if (scores.isEmpty) {
      return const ClassificationPrediction(
        className: 'Unknown',
        confidence: 0.0,
        classIndex: -1,
      );
    }

    // Check if scores are raw logits or already probabilities
    final minScore = scores.reduce(min);
    final maxScore = scores.reduce(max);
    final sumScore = scores.reduce((a, b) => a + b);

    // Apply softmax if scores are logits (e.g. values < 0 or sum does not approximate 1.0)
    List<double> probabilities;
    if (minScore < 0.0 || (sumScore - 1.0).abs() > 0.05) {
      final expScores = scores.map((s) => exp(s - maxScore)).toList();
      final sumExp = expScores.reduce((a, b) => a + b);
      probabilities = expScores.map((e) => e / (sumExp == 0 ? 1.0 : sumExp)).toList();
    } else {
      probabilities = scores;
    }

    // Find highest scoring class (argmax)
    int bestIndex = 0;
    double bestConfidence = probabilities[0];
    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > bestConfidence) {
        bestConfidence = probabilities[i];
        bestIndex = i;
      }
    }

    // Map class index to class name from configuration
    String label;
    if (bestIndex < config.classes.length) {
      label = config.classes[bestIndex];
    } else {
      label = 'Class #$bestIndex';
    }

    return ClassificationPrediction(
      className: label,
      confidence: bestConfidence,
      classIndex: bestIndex,
    );
  }
}
