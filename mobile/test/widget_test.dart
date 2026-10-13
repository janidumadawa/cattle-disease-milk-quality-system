
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
}
