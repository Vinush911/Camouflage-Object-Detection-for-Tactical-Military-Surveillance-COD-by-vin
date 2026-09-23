import 'package:flutter/material.dart';
import '../models/target_region.dart';

// Card displaying detailed information for one detected camouflaged target.
// Strictly separates Segmentation Region Confidence from Classification Confidence.

class DetectionCard extends StatelessWidget {
  final TargetRegion region;

  const DetectionCard({super.key, required this.region});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target Badge Number
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A), // Deep Navy
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                '#${region.id}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Target Details & Class
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class Label
                  Row(
                    children: [
                      Text(
                        region.displayLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (region.isClassified) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: const Text(
                            'Classified',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Bounding Box Coordinates
                  Text(
                    'Bounding Box: [${region.boundingBox.left.round()}, ${region.boundingBox.top.round()} to ${region.boundingBox.right.round()}, ${region.boundingBox.bottom.round()}]',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  // Foreground Pixel Area
                  Text(
                    'Area: ${region.pixelArea} pixels',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            // Confidences (Separating Segmentation from Classification)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 1. Segmentation Region Confidence
                Text(
                  region.formattedRegionConfidence,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D9488), // Teal
                  ),
                ),
                Text(
                  'Segmentation',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 6),

                // 2. Classification Confidence
                Text(
                  region.formattedClassificationConfidence,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: region.isClassified ? const Color(0xFF1E3A8A) : Colors.grey,
                  ),
                ),
                Text(
                  'Classification',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
