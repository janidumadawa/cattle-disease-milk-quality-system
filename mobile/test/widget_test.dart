
import 'package:flutter_test/flutter_test.dart';
import 'package:medfarm_mobile/main.dart';

void main() {
  testWidgets(
    'navigation opens the milk-quality dashboard',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MedFarmApp());

      // The app should start on Home.
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Voice'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);

      // Open the existing milk-quality dashboard.
      await tester.tap(find.text('Milk'));
      await tester.pumpAndSettle();

      expect(find.text('Milk quality'), findsOneWidget);
      expect(find.text('Milk quality pre-screening'), findsOneWidget);
      expect(find.text('MedFarm MQ-01'), findsOneWidget);
      expect(find.text('Test a sample'), findsOneWidget);
      expect(find.text('Sensor readings'), findsOneWidget);
      expect(find.text('Start PASS demo'), findsOneWidget);
      expect(find.text('Start FAIL demo'), findsOneWidget);
    },
  );
}
