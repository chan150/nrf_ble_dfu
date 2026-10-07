import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nrf_ble_dfu_ui/nrf_ble_dfu_ui.dart';

ScanResult _result(String id, {List<Guid> services = const []}) => ScanResult(
      device: BluetoothDevice(remoteId: DeviceIdentifier(id)),
      advertisementData: AdvertisementData(
        advName: id,
        txPowerLevel: null,
        appearance: null,
        connectable: true,
        manufacturerData: const {},
        serviceData: const {},
        serviceUuids: services,
      ),
      rssi: -60,
      timeStamp: DateTime.fromMillisecondsSinceEpoch(0),
    );

void main() {
  test('the advertised uuid matches however the platform reports it', () {
    // Short and long forms have to both count, since which one arrives is the
    // platform's business.
    expect(advertisesSmp(_result('a', services: [zephyrSmpService])), isTrue);
    expect(
        advertisesSmp(_result('b', services: [
          Guid.parse('8d53dc1d-1db7-4cd3-868b-8a527460aa84')!
        ])),
        isTrue);
  });

  test('a device advertising nothing relevant is not claimed', () {
    expect(advertisesSmp(_result('c')), isFalse);
    expect(dfuProtocolOf(_result('c')), null);
  });

  test('a Nordic bootloader is named, not merely rejected', () {
    // The app cannot flash it, but saying which protocol it speaks beats
    // listing it as an ordinary device the user might pick.
    final nordic = _result('d', services: [Guid.parse('FE59')!]);
    expect(advertisesSmp(nordic), isFalse);
    expect(dfuProtocolOf(nordic), DfuProtocol.nordic);
    expect(DfuProtocol.nordic.label, 'Nordic DFU');
  });

  test('flashable devices come first, and nothing is dropped', () {
    final results = [
      _result('AA'),
      _result('BB', services: [zephyrSmpService]),
      _result('CC'),
      _result('DD', services: [zephyrSmpService]),
    ];

    final ordered = smpFirst(results);

    expect(ordered.map((r) => r.device.remoteId.str), ['BB', 'DD', 'AA', 'CC']);
    expect(ordered, hasLength(results.length));
  });
}
