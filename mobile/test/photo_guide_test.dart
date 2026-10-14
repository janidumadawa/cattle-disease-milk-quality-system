import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medfarm_mobile/features/image_detection/scan_screen.dart';

/// A tall phone screen, so the whole scrolling guide is built at once.
void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('scan screen shows the photo guide and pick buttons', (
    tester,
  ) async {
    _useTallScreen(tester);
    await tester.pumpWidget(const MaterialApp(home: ScanScreen()));

    expect(find.text('Take a good photo'), findsOneWidget);
    expect(find.text('What are you photographing?'), findsOneWidget);
    expect(find.text('Open camera'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
  });

  testWidgets('choosing close-up changes the tips', (tester) async {
    _useTallScreen(tester);
    await tester.pumpWidget(const MaterialApp(home: ScanScreen()));

    expect(
      find.text('Photograph the whole animal from the side'),
      findsOneWidget,
    );

    await tester.tap(find.text('Close-up'));
    await tester.pump();

    expect(find.text('Fill the frame with the affected part'), findsOneWidget);
    expect(
      find.text('Photograph the whole animal from the side'),
      findsNothing,
    );
  });
}
