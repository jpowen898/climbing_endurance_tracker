import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:climb_endurance/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('shows the recording home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ClimbEnduranceApp());
    await tester.pumpAndSettle();

    expect(find.text('Climb Endurance'), findsOneWidget);
    expect(find.text('Ready to record'), findsOneWidget);
    expect(find.text('Start workout'), findsOneWidget);
  });
}
