import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medfarm_mobile/features/image_detection/disease_result.dart';
import 'package:medfarm_mobile/features/image_detection/disease_result_view.dart';

Map<String, dynamic> _prediction(
  String id,
  String disease,
  String? severity,
  double confidence,
) => {
  'class_id': id,
  'disease': disease,
  'severity': severity,
  'info': '$disease info',
  'confidence': confidence,
};

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  test('parses a cattle response', () {
    final result = DiseaseResult.fromJson({
      'is_cattle': true,
      'cattle_score': 0.93,
      'predictions': [
        _prediction('LSD_High', 'Lumpy Skin Disease', 'High', 0.81),
        _prediction('Healthy', 'Healthy / Normal', null, 0.12),
      ],
      'gradcam_png': base64Encode([1, 2, 3]),
    });

    expect(result.isCattle, isTrue);
    expect(result.predictions.first.disease, 'Lumpy Skin Disease');
    expect(result.predictions.first.confidence, 0.81);
    expect(result.predictions.last.severity, isNull);
    expect(result.gradcamPng, [1, 2, 3]);
  });

  test('parses a not-cattle response', () {
    final result = DiseaseResult.fromJson({
      'is_cattle': false,
      'cattle_score': 0.02,
      'predictions': <Object>[],
      'gradcam_png': null,
    });

    expect(result.isCattle, isFalse);
    expect(result.predictions, isEmpty);
    expect(result.gradcamPng, isNull);
  });

  testWidgets('shows top disease, stage and other possibilities', (
    tester,
  ) async {
    final result = DiseaseResult.fromJson({
      'is_cattle': true,
      'cattle_score': 0.93,
      'predictions': [
        _prediction('LSD_High', 'Lumpy Skin Disease', 'High', 0.81),
        _prediction('Healthy', 'Healthy / Normal', null, 0.12),
      ],
      'gradcam_png': null,
    });

    await tester.pumpWidget(_wrap(DiseaseResultView(result: result)));

    expect(find.text('Lumpy Skin Disease'), findsOneWidget);
    expect(find.text('Stage'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('81.0%'), findsOneWidget);
    expect(find.text('Healthy / Normal'), findsOneWidget);
    expect(find.textContaining('not very sure'), findsNothing);
  });

  testWidgets('warns when confidence is low', (tester) async {
    final result = DiseaseResult.fromJson({
      'is_cattle': true,
      'cattle_score': 0.9,
      'predictions': [
        _prediction('FMD_Low', 'Foot-and-Mouth Disease', 'Low', 0.4),
      ],
      'gradcam_png': null,
    });

    await tester.pumpWidget(_wrap(DiseaseResultView(result: result)));

    expect(find.textContaining('not very sure'), findsOneWidget);
  });

  testWidgets('shows a message for photos without cattle', (tester) async {
    final result = DiseaseResult.fromJson({
      'is_cattle': false,
      'cattle_score': 0.02,
      'predictions': <Object>[],
      'gradcam_png': null,
    });

    await tester.pumpWidget(_wrap(DiseaseResultView(result: result)));

    expect(find.text("This doesn't look like cattle"), findsOneWidget);
  });
}
