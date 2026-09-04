import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nrf_ble_dfu_ui/nrf_ble_dfu_ui.dart';

void main() {
  group('bootloaderAddressOf', () {
    test('advances the last octet', () {
      expect(bootloaderAddressOf('C1:2A:3B:4C:5D:6E'), 'C1:2A:3B:4C:5D:6F');
      expect(bootloaderAddressOf('c1:2a:3b:4c:5d:09'), 'C1:2A:3B:4C:5D:0A');
    });

    test('wraps rather than overflowing', () {
      expect(bootloaderAddressOf('C1:2A:3B:4C:5D:FF'), 'C1:2A:3B:4C:5D:00');
    });

    test('declines anything that is not a MAC', () {
      // iOS and macOS hand out an opaque per-app identifier, and incrementing
      // it would produce an address belonging to nothing.
      expect(bootloaderAddressOf('9A8B7C6D-5E4F-3210-9876-543210FEDCBA'), null);
      expect(bootloaderAddressOf(''), null);
      expect(bootloaderAddressOf('C1:2A:3B:4C:5D'), null);
    });
  });

  group('service UUIDs', () {
    test('the 16-bit Nordic service matches its 128-bit form', () {
      // Whether a UUID arrives short or long is the platform's business, and
      // Guid compares by the 128-bit form, so both must match.
      expect(nordicDfuService,
          Guid.parse('0000FE59-0000-1000-8000-00805F9B34FB'));
      expect(nordicDfuService.str, 'fe59');
    });

    test('the two protocols do not collide', () {
      expect(nordicDfuService, isNot(zephyrSmpService));
    });
  });
}
