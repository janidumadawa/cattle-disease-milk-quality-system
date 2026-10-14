import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medfarm_mobile/main.dart';

void main() {
  testWidgets('displays the shared MedFarm application shell',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MedFarmApp());

    expect(
      find.text('Cattle Disease Detection and Milk Quality Analysis System'),
      findsOneWidget,
    );

    expect(
      find.text('Shared mobile application foundation'),
      findsOneWidget,
    );
  });

  testWidgets('bottom nav bar switches between modules',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MedFarmApp());

    for (final label in ['Home', 'Scan', 'Voice', 'Milk', 'Chat', 'More']) {
      expect(find.text(label), findsOneWidget);
    }

    final pages = {
      'Scan': 'Image-based Detection',
      'Voice': 'Voice-based Analysis',
      'Milk': 'Milk Quality Check',
      'Chat': 'Chatbot',
    };
    for (final MapEntry(key: tab, value: title) in pages.entries) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, title), findsOneWidget);
    }

    // Tap the raised camera button itself, not just its label.
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.camera_alt_outlined).last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Image-based Detection'), findsOneWidget);
  });
}
