import 'dart:convert';
import 'dart:typed_data';

/// One possible disease returned by `POST /api/v1/disease/predict`.
class DiseasePrediction {
  const DiseasePrediction({
    required this.classId,
    required this.disease,
    required this.severity,
    required this.info,
    required this.confidence,
  });

  factory DiseasePrediction.fromJson(Map<String, dynamic> json) {
    return DiseasePrediction(
      classId: json['class_id'] as String,
      disease: json['disease'] as String,
      severity: json['severity'] as String?,
      info: json['info'] as String,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  final String classId;
  final String disease;

  /// "High" or "Low"; null for Healthy.
  final String? severity;
  final String info;

  /// Model confidence from 0 to 1.
  final double confidence;
}

/// Response of `POST /api/v1/disease/predict`.
class DiseaseResult {
  const DiseaseResult({
    required this.isCattle,
    required this.cattleScore,
    required this.predictions,
    required this.gradcamPng,
  });

  factory DiseaseResult.fromJson(Map<String, dynamic> json) {
    final gradcam = json['gradcam_png'] as String?;
    return DiseaseResult(
      isCattle: json['is_cattle'] as bool,
      cattleScore: (json['cattle_score'] as num).toDouble(),
      predictions: [
        for (final p in json['predictions'] as List)
          DiseasePrediction.fromJson(p as Map<String, dynamic>),
      ],
      gradcamPng: gradcam == null ? null : base64Decode(gradcam),
    );
  }

  /// False when the photo does not appear to show cattle. No disease check
  /// is done then, and [predictions] is empty.
  final bool isCattle;
  final double cattleScore;

  /// Most likely first.
  final List<DiseasePrediction> predictions;

  /// Photo with a heatmap of the areas that drove the top prediction.
  final Uint8List? gradcamPng;
}
