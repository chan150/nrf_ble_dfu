import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nrf_ble_dfu_ui/nrf_ble_dfu_ui.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('nrf_ble_dfu_ui Package Tests', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('DfuUiManager singleton and initialization', () async {
      final manager = DfuUiManager();
      expect(manager, isNotNull);
    });

    testWidgets('Widget exports can be rendered', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DfuProgress(),
          ),
        ),
      );

      expect(find.byType(DfuProgress), findsOneWidget);
    });
  });
}
