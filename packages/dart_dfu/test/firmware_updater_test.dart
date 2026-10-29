import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dart_dfu/src/loopback_nordic.dart';
import 'package:dart_dfu/src/loopback_transport.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';
import 'package:test/test.dart';

Uint8List _pattern(int length, int seed) =>
    Uint8List.fromList(List.generate(length, (i) => (i * seed + 11) & 0xFF));

/// The one check the shared interface earns: each adapter, driven only
/// through [FirmwareUpdater], gets the whole image onto its loopback device
/// and reports progress reaching the end.
void main() {
  test('Nordic: a .zip package is unpacked and both objects arrive', () async {
    final dat = _pattern(141, 7);
    final bin = _pattern(10000, 13);
    final zip = ZipEncoder().encode(Archive()
      ..addFile(ArchiveFile('fw.dat', dat.length, dat))
      ..addFile(ArchiveFile('fw.bin', bin.length, bin)));

    final device = LoopbackBootloader();
    final FirmwareUpdater updater = NordicFirmwareUpdater(device);
    final seen = <double>[];

    await updater.flash(zip, onProgress: seen.add);

    expect(updater.protocol, DfuProtocol.nordic);
    expect(device.committed[NrfDfuTransferType.init.code], equals(dat));
    expect(device.committed[NrfDfuTransferType.image.code], equals(bin));
    expect(seen, isNotEmpty);
    expect(seen.last, 1.0);
  });

  test('Zephyr: a .bin image arrives whole, with its length declared',
      () async {
    final image = _pattern(5000, 3);
    final transport = LoopbackTransport();
    final FirmwareUpdater updater =
        SmpFirmwareUpdater(transport);
    final seen = <double>[];

    await updater.flash(image, onProgress: seen.add);

    expect(updater.protocol, DfuProtocol.zephyr);
    expect(transport.received.toBytes(), equals(image));
    expect(transport.declaredLength, image.length);
    expect(seen.last, 1.0);
  });
}
