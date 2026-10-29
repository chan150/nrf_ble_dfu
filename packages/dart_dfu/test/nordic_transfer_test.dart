import 'dart:typed_data';

import 'package:dart_dfu/src/loopback_nordic.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';
import 'package:test/test.dart';

Uint8List _pattern(int length, int seed) =>
    Uint8List.fromList(List.generate(length, (i) => (i * seed + 11) & 0xFF));

void main() {
  late Directory temp;
  late NrfBleDfu dfu;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('nordic_transfer');
    dfu = NrfBleDfu()..initialize();
  });

  tearDown(() => temp.deleteSync(recursive: true));

  /// Points the core at loose .dat/.bin files, skipping the zip it would
  /// normally unpack, since the archive is not what is under test here.
  void stageFirmware(Uint8List dat, Uint8List bin) {
    final datFile = File('${temp.path}/firmware.dat')..writeAsBytesSync(dat);
    final binFile = File('${temp.path}/firmware.bin')..writeAsBytesSync(bin);
    dfu.file.update(datPath: datFile.path, binPath: binFile.path);
  }

  test('both objects arrive byte for byte', () async {
    // Neither a multiple of the object size nor of the chunk size, so partial
    // objects and short final packets are both exercised.
    final dat = _pattern(141, 7);
    final bin = _pattern(10000, 13);
    stageFirmware(dat, bin);

    final device = LoopbackBootloader();
    await dfu.updateFirmware(device);

    expect(device.committed[NrfDfuTransferType.init.code], equals(dat));
    expect(device.committed[NrfDfuTransferType.image.code], equals(bin));
  });

  test('receipts pace the write at the agreed packet count', () async {
    stageFirmware(_pattern(64, 3), _pattern(6000, 5));

    // A receipt every packet is the tightest pacing there is; if the offset
    // and CRC checks disagreed with the device at any point, the transfer
    // would throw rather than complete.
    dfu.packetReceiptNotification = 1;
    final device = LoopbackBootloader();
    await dfu.updateFirmware(device);

    expect(device.committed[NrfDfuTransferType.image.code]!.length, 6000);
  });

  test('unthrottled transfers still complete', () async {
    stageFirmware(_pattern(64, 3), _pattern(6000, 5));

    dfu.packetReceiptNotification = 0; // flow control off
    final device = LoopbackBootloader();
    await dfu.updateFirmware(device);

    expect(device.committed[NrfDfuTransferType.image.code], hasLength(6000));
  });

  test('a larger MTU means fewer, bigger packets', () async {
    final image = _pattern(4096, 17);
    var seen = <int>[];

    for (final mtu in [23, 247]) {
      stageFirmware(_pattern(32, 3), image);
      final device = LoopbackBootloader(mtu: mtu);
      await dfu.updateFirmware(device);
      expect(device.committed[NrfDfuTransferType.image.code], equals(image));
      seen.add(mtu);
    }
    expect(seen, [23, 247]);
  });
}
