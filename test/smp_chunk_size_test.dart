import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:test/test.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

/// The largest frame an upload can produce: the one at offset 0, which alone
/// carries 'len' and 'confirm'. Offsets and lengths are pinned to their widest
/// encoding so the budget is measured against the worst case, not a typical one.
int worstCaseFrameLength(int chunk) {
  final encoded = cbor.encode(CborMap({
    CborString('data'): CborBytes(Uint8List(chunk)),
    CborString('off'): CborInt(BigInt.from(0xFFFFFFFF)),
    CborString('len'): CborInt(BigInt.from(0xFFFFFFFF)),
    CborString('confirm'): CborBool(true),
  }));
  return SmpHeader.headerLength + encoded.length;
}

void main() {
  test('floors at the chunk mcumgr needs to parse the image header', () {
    expect(smpChunkSize(23), 128); // no MTU negotiated yet
    expect(smpChunkSize(175), 128); // just under where the floor stops binding
  });

  test('follows the negotiated MTU once it clears the floor', () {
    expect(smpChunkSize(247), 247 - smpFrameOverhead);
    expect(smpChunkSize(517), 517 - smpFrameOverhead);
  });

  test('smpFrameOverhead really covers the CBOR envelope', () {
    for (final mtu in [176, 247, 300, 517]) {
      final frame = worstCaseFrameLength(smpChunkSize(mtu));
      expect(frame, lessThanOrEqualTo(mtu), reason: 'MTU $mtu produced $frame');
    }
  });
}
