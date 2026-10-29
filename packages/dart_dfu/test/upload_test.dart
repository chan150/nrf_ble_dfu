import 'dart:typed_data';

import 'package:dart_dfu/src/loopback_transport.dart';
import 'package:test/test.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

void main() {
  test('an uploaded image arrives whole, in order, and intact', () async {
    final device = LoopbackTransport(mtu: 247);
    // Deliberately not a multiple of the chunk size, so the short final frame
    // is exercised too.
    final image = Uint8List.fromList(
        List<int>.generate(5000, (i) => (i * 7 + 13) & 0xFF));

    final progress = <double>[];
    await SmpDfuManager(device)
        .uploadImage(image, onProgress: progress.add);

    expect(device.received.toBytes(), equals(image));
    expect(device.declaredLength, image.length);
    expect(progress.last, closeTo(1.0, 1e-9));
  });

  test('a frame the device dropped is resent from the offset it reports',
      () async {
    final device = LoopbackTransport(mtu: 247)..dropOnceAt = smpChunkSize(247);
    final image = Uint8List.fromList(
        List<int>.generate(5000, (i) => (i * 7 + 13) & 0xFF));

    await SmpDfuManager(device).uploadImage(image);

    // Trusting its own offset, the uploader would skip the dropped frame and
    // still finish at 100% with a gap in the slot.
    expect(device.received.toBytes(), equals(image));
  });

  test('a signed image yields its TLV hash', () {
    expect(mcubootImageHash(_signed(0xAA)), equals(List.filled(32, 0xAA)));
    expect(() => mcubootImageHash(Uint8List(64)), throwsFormatException);
  });

  test('markUploaded marks the slot holding this exact image', () async {
    final device = LoopbackTransport();
    final dfu = SmpDfuManager(device);
    final image = _signed(0xAA);

    await dfu.uploadImage(image);
    await dfu.markUploaded(image, confirm: true);

    expect(device.markedHash, equals(List.filled(32, 0xAA)));
    expect(device.markedConfirm, isTrue);
  });

  test('markUploaded refuses a slot holding some other image', () async {
    final device = LoopbackTransport();
    final dfu = SmpDfuManager(device);

    await dfu.uploadImage(_signed(0xAA));

    await expectLater(dfu.markUploaded(_signed(0xBB), confirm: true),
        throwsStateError);
    expect(device.markedHash, isNull);
  });

  test('a state write the device refuses throws', () async {
    final dfu = SmpDfuManager(LoopbackTransport());
    await expectLater(
        dfu.confirmImage(Uint8List(32)), throwsA(isA<SmpException>()));
  });

  test('chunking follows the MTU the transport reports', () async {
    final wide = LoopbackTransport(mtu: 247);
    final narrow = LoopbackTransport(mtu: 23);
    final image = Uint8List(4096);

    final wideCalls = <double>[];
    final narrowCalls = <double>[];
    await SmpDfuManager(wide).uploadImage(image, onProgress: wideCalls.add);
    await SmpDfuManager(narrow).uploadImage(image, onProgress: narrowCalls.add);

    expect(wideCalls.length, (image.length / smpChunkSize(247)).ceil());
    expect(narrowCalls.length, (image.length / smpChunkSize(23)).ceil());
    expect(wideCalls.length, lessThan(narrowCalls.length));
  });

  test('list and reset round-trip through the core', () async {
    final device = LoopbackTransport();
    final dfu = SmpDfuManager(device);

    expect((await dfu.listImages()).single.slot, 0);
    expect(await dfu.echo('ping'), 'ping');

    await dfu.reset();
    expect(device.wasReset, isTrue);
  });
}

/// A minimal signed-image layout: 32-byte header, [body] bytes, then an
/// unprotected TLV area holding one SHA-256 entry filled with [hashByte].
Uint8List _signed(int hashByte, {int body = 600}) {
  final b = ByteData(32 + body + 4 + 4 + 32);
  b.setUint32(0, 0x96f3b83d, Endian.little);
  b.setUint16(8, 32, Endian.little);
  b.setUint32(12, body, Endian.little);
  final tlv = 32 + body;
  b.setUint16(tlv, 0x6907, Endian.little);
  b.setUint16(tlv + 2, 4 + 4 + 32, Endian.little);
  b.setUint16(tlv + 4, 0x10, Endian.little);
  b.setUint16(tlv + 6, 32, Endian.little);
  for (var i = 0; i < 32; i++) {
    b.setUint8(tlv + 8 + i, hashByte);
  }
  return b.buffer.asUint8List();
}
