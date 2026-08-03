import 'package:flutter_test/flutter_test.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NrfBleDfu Pure Dart Core Tests', () {
    late NrfBleDfu dfu;

    setUp(() {
      dfu = NrfBleDfu();
      dfu.initialize();
    });

    test('Singleton initialization', () {
      final dfu2 = NrfBleDfu();
      expect(identical(dfu, dfu2), isTrue);
    });

    test('Initial states non-null', () {
      expect(dfu.setup, isNotNull);
      expect(dfu.file, isNotNull);
      expect(dfu.progress, isNotNull);
      expect(dfu.entry, isNotNull);
      expect(dfu.dfu, isNotNull);
    });

    test('Preset management (add, load, update, rename, delete)', () {
      dfu.presets.clear();
      expect(dfu.presets.length, equals(0));

      dfu.addNewPreset('Test Preset 1');
      expect(dfu.presets.length, equals(1));
      expect(dfu.presets.first.name, equals('Test Preset 1'));
      expect(dfu.selectedPresetIndex, equals(0));

      dfu.entryControlPoint = '12345678-0000-1000-8000-00805f9b34fb';
      dfu.updatePreset(0);
      expect(dfu.presets[0].entryUuid,
          equals('12345678-0000-1000-8000-00805f9b34fb'));

      dfu.renamePreset(0, 'Renamed Preset');
      expect(dfu.presets[0].name, equals('Renamed Preset'));

      dfu.loadPreset(0);
      expect(dfu.setup.entryControlPoint,
          equals('12345678-0000-1000-8000-00805f9b34fb'));

      // Delete (won't delete if length <= 1 as per implementation safety)
      dfu.addNewPreset('Test Preset 2');
      expect(dfu.presets.length, equals(2));
      dfu.deletePreset(1);
      expect(dfu.presets.length, equals(1));
    });

    test('History management and stream events', () async {
      dfu.setup.history.clear();
      dfu.setup.updatedMacs.clear();

      final historyEvents = <DfuHistoryEntry>[];
      final subscription = dfu.onHistory.listen(historyEvents.add);

      dfu.addHistoryEntry(
        remoteId: 'AA:BB:CC:DD:EE:FF',
        deviceName: 'NEUL_1234',
        status: 'success',
      );

      await Future.delayed(Duration.zero);

      expect(dfu.setup.history.length, equals(1));
      expect(dfu.setup.history.first.remoteId, equals('AA:BB:CC:DD:EE:FF'));
      expect(dfu.setup.updatedMacs.contains('AA:BB:CC:DD:EE:FF'), isTrue);
      expect(historyEvents.length, equals(1));

      await subscription.cancel();
    });

    test('Log stream events', () async {
      final logEvents = <LogEntry>[];
      final subscription = dfu.onLog.listen(logEvents.add);

      dfu.log('Test log message', level: 'INFO');

      await Future.delayed(Duration.zero);

      expect(logEvents.length, equals(1));
      expect(logEvents.first.message, equals('Test log message'));
      expect(
          dfu.setup.logs.any((l) => l.message == 'Test log message'), isTrue);

      await subscription.cancel();
    });

    test('Clear history stream events', () async {
      bool clearCalled = false;
      final subscription = dfu.onHistoryClear.listen((_) {
        clearCalled = true;
      });

      await dfu.clearHistory();

      expect(clearCalled, isTrue);
      expect(dfu.setup.history.isEmpty, isTrue);

      await subscription.cancel();
    });
  });
}
