import 'disease_result.dart';

/// One row of `GET /api/v1/disease/history`.
class ScanSummary {
  const ScanSummary({
    required this.id,
    required this.createdAt,
    required this.topPrediction,
    required this.photoPath,
  });

  factory ScanSummary.fromJson(Map<String, dynamic> json) {
    return ScanSummary(
      id: json['id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      topPrediction: DiseasePrediction.fromJson(
        json['top_prediction'] as Map<String, dynamic>,
      ),
      photoPath: json['photo_url'] as String,
    );
  }

  final int id;
  final DateTime createdAt;
  final DiseasePrediction topPrediction;

  /// Path of the stored photo, relative to the API base URL.
  final String photoPath;
}

/// A page of scan history, newest first.
class ScanHistoryPage {
  const ScanHistoryPage({required this.total, required this.items});

  factory ScanHistoryPage.fromJson(Map<String, dynamic> json) {
    return ScanHistoryPage(
      total: json['total'] as int,
      items: [
        for (final s in json['items'] as List)
          ScanSummary.fromJson(s as Map<String, dynamic>),
      ],
    );
  }

  /// Number of scans stored, across all pages.
  final int total;
  final List<ScanSummary> items;
}

/// Response of `GET /api/v1/disease/history/{id}`.
class ScanDetail {
  const ScanDetail({
    required this.id,
    required this.createdAt,
    required this.cattleScore,
    required this.predictions,
    required this.photoPath,
    required this.gradcamPath,
  });

  factory ScanDetail.fromJson(Map<String, dynamic> json) {
    return ScanDetail(
      id: json['id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      cattleScore: (json['cattle_score'] as num).toDouble(),
      predictions: [
        for (final p in json['predictions'] as List)
          DiseasePrediction.fromJson(p as Map<String, dynamic>),
      ],
      photoPath: json['photo_url'] as String,
      gradcamPath: json['gradcam_url'] as String?,
    );
  }

  final int id;
  final DateTime createdAt;
  final double cattleScore;

  /// Most likely first.
  final List<DiseasePrediction> predictions;
  final String photoPath;
  final String? gradcamPath;
}
