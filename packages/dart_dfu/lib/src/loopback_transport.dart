import 'dart:typed_data';

import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

/// An in-memory stand-in for a device, so the tool can be run and tested
/// without one.
///
/// It answers the handful of commands [SmpDfuManager] issues and keeps whatever
/// is uploaded in [received], which is what lets a test assert that an image
/// arrived whole and in order. It is not a simulator: it does not verify
/// signatures, swap slots or reboot.
class LoopbackTransport implements SmpTransport {
  LoopbackTransport({this.mtu = 247});

  @override
  final int mtu;

  /// Bytes accepted so far, in the order they were written.
  final BytesBuilder received = BytesBuilder();

  /// Total the uploader declared on its first frame.
  int? declaredLength;

  /// Offset of a frame to drop once, answering as if it never arrived.
  int? dropOnceAt;

  /// The image state write: hash and confirm flag, once one arrives.
  List<int>? markedHash;
  bool? markedConfirm;

  bool wasReset = false;

  Map<String, dynamic> _slot1() {
    final bytes = received.toBytes();
    List<int> hash;
    try {
      hash = mcubootImageHash(bytes);
    } on FormatException {
      hash = Uint8List(32);
    }
    return {
      'slot': 1,
      'version': '0.0.1',
      'hash': hash,
      'bootable': true,
      'pending': markedHash != null,
      'permanent': markedConfirm == true,
    };
  }

  @override
  Future<Map<dynamic, dynamic>> sendRequest(
    int op,
    int group,
    int commandId,
    Map<dynamic, dynamic> payload,
  ) async {
    if (group == SmpGroup.defaultGroup && commandId == 0) {
      return {'r': payload['d']};
    }
    if (group == SmpGroup.defaultGroup && commandId == 5) {
      wasReset = true;
      return {'rc': 0};
    }
    if (group == SmpGroup.image && commandId == SmpImageCmd.state) {
      final images = [
        {
          'slot': 0,
          'version': '0.0.0',
          'hash': Uint8List(32),
          'bootable': true,
          'confirmed': true,
          'active': true,
        },
        if (received.length > 0) _slot1(),
      ];
      if (op == SmpOp.write) {
        final hash = payload['hash'] as List<int>;
        if (received.length == 0 || _slot1()['hash'].toString() != hash.toString()) {
          return {'rc': 3}; // EINVAL: no such image
        }
        markedHash = hash;
        markedConfirm = payload['confirm'] == true;
        return {'images': [images[0], _slot1()]};
      }
      return {'images': images};
    }
    if (group == SmpGroup.image && commandId == SmpImageCmd.upload) {
      final off = payload['off'] as int;
      // Like Zephyr, a frame that does not continue where the last one
      // stopped is dropped and answered with the offset expected instead.
      if (off != received.length || off == dropOnceAt) {
        if (off == dropOnceAt) dropOnceAt = null;
        return {'rc': 0, 'off': received.length};
      }
      if (off == 0) {
        declaredLength = payload['len'] as int?;
      }
      received.add(payload['data'] as List<int>);
      return {'rc': 0, 'off': received.length};
    }
    return {'rc': 8}; // ENOTSUP
  }
}
