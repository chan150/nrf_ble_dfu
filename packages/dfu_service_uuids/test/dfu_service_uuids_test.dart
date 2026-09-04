import 'package:dfu_service_uuids/dfu_service_uuids.dart';
import 'package:test/test.dart';

void main() {
  group('normalizeUuid', () {
    test('expands the short forms a platform may report', () {
      // Android tends to report the long form and iOS the short one, for the
      // very same service.
      expect(normalizeUuid('FE59'), DfuProtocol.nordic.serviceUuid);
      expect(normalizeUuid('0000fe59-0000-1000-8000-00805f9b34fb'),
          DfuProtocol.nordic.serviceUuid);
      expect(normalizeUuid('0000FE59'), DfuProtocol.nordic.serviceUuid);
    });

    test('leaves a 128-bit uuid alone but for its case', () {
      expect(normalizeUuid('8D53DC1D-1DB7-4CD3-868B-8A527460AA84'),
          DfuProtocol.zephyr.serviceUuid);
    });

    test('declines what is not a uuid', () {
      for (final input in ['', 'nope', 'FE5', 'FE59FE', 'zzzz']) {
        expect(normalizeUuid(input), null, reason: input);
      }
    });
  });

  group('protocolOf', () {
    test('names each protocol from its service', () {
      expect(protocolOf(['FE59']), DfuProtocol.nordic);
      expect(protocolOf(['8d53dc1d-1db7-4cd3-868b-8a527460aa84']),
          DfuProtocol.zephyr);
    });

    test('is null when neither is advertised', () {
      expect(protocolOf([]), null);
      expect(protocolOf(['180a', '180f']), null); // device info, battery
    });

    test('does not confuse the two', () {
      expect(advertises(['FE59'], DfuProtocol.zephyr), isFalse);
      expect(advertises(['FE59'], DfuProtocol.nordic), isTrue);
    });

    test('finds the service among unrelated ones', () {
      expect(protocolOf(['180a', 'FE59', '180f']), DfuProtocol.nordic);
    });
  });
}
