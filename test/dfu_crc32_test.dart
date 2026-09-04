import 'package:flutter_test/flutter_test.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

void main() {
  // The bootloader reports its CRC as an unsigned 32-bit value, so anything
  // negative can never compare equal to it no matter how right the maths is.
  test('stays in unsigned 32-bit range', () {
    for (final input in [
      <int>[],
      '123456789'.codeUnits,
      List<int>.filled(4096, 0xA5),
    ]) {
      final crc = dfuCrc32(input);
      expect(crc, greaterThanOrEqualTo(0));
      expect(crc, lessThanOrEqualTo(0xFFFFFFFF));
    }
  });

  test('matches the CRC-32/ISO-HDLC vectors the bootloader uses', () {
    expect(dfuCrc32(<int>[]), 0x00000000);
    expect(dfuCrc32('123456789'.codeUnits), 0xCBF43926);
    expect(dfuCrc32('a'.codeUnits), 0xE8B7BE43);
    expect(dfuCrc32(<int>[0x00]), 0xD202EF8D);
  });

  test('is cumulative, which is how receipts are checked mid-object', () {
    // A receipt reports the CRC of everything received so far, so the prefix
    // of a buffer must hash the same as that prefix taken on its own.
    final image = List<int>.generate(1000, (i) => (i * 31) & 0xFF);
    expect(dfuCrc32(image.sublist(0, 240)), dfuCrc32(image.take(240).toList()));
    expect(dfuCrc32(image.sublist(0, 240)), isNot(dfuCrc32(image)));
  });
}
