// ignore_for_file: public_member_api_docs

part 'table.dart';

// reference: https://gist.github.com/tijnkooijmans/10981093
class Crc16 {
  static const _initValue = 0xFFFF;
  static const _crcPolynomial = 0x1021;

  static List<int> getCcittFalse(List<int> payload) {
    var crc = _initValue;
    var byteIndex = 0;

    for (var n = 0; n < payload.length; n++) {
      final tableIndex = 0xFF & (crc >> 8 ^ payload[byteIndex++]);
      crc = 0xFFFF & (crc << 8 ^ _ccittFalseTable[tableIndex]);
    }
    return [(crc & 0xFF00) >> 8, crc & 0xFF];
  }

  static List<int> getCcittFalseCompute(List<int> payload) {
    var crc = _initValue;
    var c15 = false;
    var bit = false;

    for (var n = 0; n < payload.length; n++) {
      for (var i = 0; i < 8; i++) {
        bit = (payload[n] >> (7 - i) & 1) == 1;
        c15 = (crc >> 15 & 1) == 1;
        if (c15 ^ bit) {
          crc ^= _crcPolynomial;
        }
      }
    }

    crc &= _initValue;

    return [(crc & 0xFF00) >> 8, crc & 0xFF];
  }
}
