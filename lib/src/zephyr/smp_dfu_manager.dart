import 'dart:math' as math;
import 'dart:typed_data';
import 'smp_transport.dart';
import 'smp_header.dart';

class ImageState {
  final int slot;
  final String version;
  final Uint8List hash;
  final bool bootable;
  final bool pending;
  final bool confirmed;
  final bool active;
  final bool permanent;

  ImageState({
    required this.slot,
    required this.version,
    required this.hash,
    required this.bootable,
    required this.pending,
    required this.confirmed,
    required this.active,
    required this.permanent,
  });

  factory ImageState.fromMap(Map map) {
    dynamic hashData = map['hash'];
    Uint8List hash;
    if (hashData is Uint8List) {
      hash = hashData;
    } else if (hashData is List) {
      hash = Uint8List.fromList(hashData.cast<int>());
    } else {
      hash = Uint8List(0);
    }

    return ImageState(
      slot: map['slot'] ?? 0,
      version: map['version']?.toString() ?? '',
      hash: hash,
      bootable: map['bootable'] ?? false,
      pending: map['pending'] ?? false,
      confirmed: map['confirmed'] ?? false,
      active: map['active'] ?? false,
      permanent: map['permanent'] ?? false,
    );
  }
}

/// Bytes the SMP header and the CBOR envelope around an upload chunk occupy,
/// taken at their worst case.
///
/// The largest upload frame is the first one, whose map carries three entries:
///
///     {'data': <bytes>, 'off': <int>, 'len': <int>}
///
/// which encodes as 1 (map header) + 5 + 3 ('data' key and a byte-string
/// header up to 64 KiB) + 4 + 5 ('off' and a uint32) + 4 + 5 ('len' likewise)
/// = 27 bytes, plus the 8-byte SMP header. Rounded up from 35 to leave slack.
const int smpFrameOverhead = 48;

/// Payload bytes one upload chunk may carry over a link of [mtu] bytes.
///
/// Floored at 128 because mcumgr answers EINVAL (rc 3) when the frame at
/// offset 0 is too small to parse the image header out of, and 128 is the size
/// this has actually been exercised with. Below an MTU of 176 the frame no
/// longer fits a single ATT packet, which is why [SmpManager.sendRequest]
/// falls back to a long write.
int smpChunkSize(int mtu) => math.max(128, mtu - smpFrameOverhead);

/// An SMP request the device answered with a non-zero `rc`.
class SmpException implements Exception {
  SmpException(this.request, this.rc);

  final String request;
  final int rc;

  @override
  String toString() => 'SmpException: $request failed with rc $rc';
}

void _checkRc(Map<dynamic, dynamic> response, String request) {
  final rc = response['rc'];
  if (rc is int && rc != 0) throw SmpException(request, rc);
}

/// The image hash MCUboot keeps in the TLV trailer of a signed [image]: the
/// hash the device reports for whichever slot holds that image.
///
/// Throws [FormatException] when [image] is not a signed MCUboot image, e.g.
/// a bare `zephyr.bin` instead of `zephyr.signed.bin` / `app_update.bin`.
Uint8List mcubootImageHash(Uint8List image) {
  final b = ByteData.sublistView(image);
  if (image.length < 32 || b.getUint32(0, Endian.little) != 0x96f3b83d) {
    throw const FormatException('Not a signed MCUboot image (bad magic)');
  }
  final headerSize = b.getUint16(8, Endian.little);
  final bodySize = b.getUint32(12, Endian.little);
  // Protected TLVs (0x6908), if any, then unprotected ones (0x6907), each
  // area led by {magic, total size including this 4-byte info}.
  var area = headerSize + bodySize;
  while (area + 4 <= image.length) {
    final magic = b.getUint16(area, Endian.little);
    if (magic != 0x6907 && magic != 0x6908) break;
    final end = area + b.getUint16(area + 2, Endian.little);
    if (end < area + 4) break; // a size that cannot hold its own header
    var p = area + 4;
    while (p + 4 <= end && end <= image.length) {
      final type = b.getUint16(p, Endian.little);
      final len = b.getUint16(p + 2, Endian.little);
      // SHA-256, SHA-384, SHA-512: whichever the image was built with.
      if ((type == 0x10 || type == 0x11 || type == 0x12) &&
          p + 4 + len <= end) {
        return Uint8List.fromList(image.sublist(p + 4, p + 4 + len));
      }
      p += 4 + len;
    }
    area = end;
  }
  throw const FormatException('No hash TLV in the MCUboot image');
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _hex(List<int> bytes) =>
    bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

class SmpDfuManager {
  final SmpTransport transport;

  /// Where diagnostics go, if anywhere.
  ///
  /// A library has no business writing to stdout: doing so corrupts the
  /// output of any tool built on it. Silent unless a caller asks for these.
  final void Function(String message)? onLog;

  SmpDfuManager(this.transport, {this.onLog});

  Future<String> echo(String message) async {
    final response = await transport.sendRequest(SmpOp.write, SmpGroup.defaultGroup, 0, {'d': message});
    return response['r']?.toString() ?? '';
  }

  Future<List<ImageState>> listImages() async {
    final response = await transport.sendRequest(SmpOp.read, SmpGroup.image, SmpImageCmd.state, {});
    onLog?.call("SmpDfuManager.listImages raw response: $response");
    
    if (response['rc'] != null && response['rc'] != 0) {
      onLog?.call("SmpDfuManager.listImages error: rc ${response['rc']}");
      return [];
    }

    final imagesList = response['images'];
    if (imagesList is! List) {
      onLog?.call("SmpDfuManager.listImages: 'images' key missing or not a list. Response keys: ${response.keys.toList()}");
      return [];
    }
    return imagesList.map((img) => ImageState.fromMap(img as Map)).toList();
  }

  /// Writes [data] into the secondary slot. Only writes: the image runs once
  /// it is marked with [markUploaded] (or [testImage] / [confirmImage]) and
  /// the device is [reset].
  Future<void> uploadImage(Uint8List data, {Function(double)? onProgress}) async {
    int offset = 0;

    final chunkSize = smpChunkSize(transport.mtu);
    onLog?.call('Upload: ${data.length} bytes in $chunkSize-byte chunks '
        '(MTU ${transport.mtu})');

    int retryCount = 0;
    const int maxRetries = 3;

    while (offset < data.length) {
      int end = (offset + chunkSize > data.length) ? data.length : offset + chunkSize;
      Uint8List chunk = data.sublist(offset, end);

      Map<String, dynamic> payload = {
        'data': chunk,
        'off': offset,
      };

      if (offset == 0) {
        payload['len'] = data.length;
      }

      final Map<dynamic, dynamic> resp;
      try {
        resp = await transport.sendRequest(SmpOp.write, SmpGroup.image, SmpImageCmd.upload, payload);
      } catch (e) {
        if (retryCount < maxRetries) {
          onLog?.call("Request failed with error: $e. Retrying...");
          retryCount++;
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
          continue;
        }
        rethrow;
      }

      final rc = resp['rc'];
      if (rc is int && rc != 0) {
        if (retryCount < maxRetries) {
          onLog?.call("Received rc: $rc at offset $offset. Retrying...");
          retryCount++;
          await Future.delayed(const Duration(milliseconds: 200));
          continue;
        }
        throw SmpException('upload at offset $offset', rc);
      }

      // Go on from where the device says it is, not from [end]: a frame it did
      // not expect is dropped and answered with rc 0 and its own offset, so
      // trusting [end] turns one lost frame into a gapped image at 100%.
      final next = resp['off'];
      if (next is! int || next < 0 || next > data.length) {
        throw StateError('Upload: device reported offset $next after '
            'writing $offset..$end of ${data.length}');
      }
      if (next <= offset) {
        if (++retryCount > maxRetries) {
          throw StateError('Upload stuck: device keeps asking for offset $next');
        }
        onLog?.call('Device expects offset $next, not $end. Resending.');
      } else {
        retryCount = 0;
      }
      offset = next;
      if (onProgress != null) {
        onProgress(offset / data.length);
      }
    }
  }

  /// Marks [image], just written with [uploadImage], to run on the next boot:
  /// once (a test boot MCUboot reverts unless the new firmware confirms
  /// itself), or for good when [confirm] is set.
  ///
  /// Refuses unless the secondary slot holds exactly [image], so a stale or
  /// half-written slot is never marked in its place.
  Future<void> markUploaded(Uint8List image, {required bool confirm}) async {
    final want = mcubootImageHash(image);
    final staged = (await listImages()).where((i) => !i.active).toList();
    if (staged.isEmpty) {
      throw StateError('No image in the secondary slot after the upload');
    }
    if (!_sameBytes(staged.first.hash, want)) {
      throw StateError('Secondary slot holds ${_hex(staged.first.hash)}, '
          'the file is ${_hex(want)}: the upload did not land intact');
    }
    await _writeState(want, confirm: confirm);
  }

  Future<void> testImage(Uint8List hash) => _writeState(hash, confirm: false);

  Future<void> confirmImage(Uint8List hash) => _writeState(hash, confirm: true);

  Future<void> _writeState(Uint8List hash, {required bool confirm}) async {
    final what = confirm ? 'confirm' : 'test';
    final resp = await transport.sendRequest(SmpOp.write, SmpGroup.image, SmpImageCmd.state, {
      'hash': hash,
      'confirm': confirm, // false with a hash means "test" on the next reboot
    });
    _checkRc(resp, 'image $what ${_hex(hash)}');
    // The reply carries the image list as it now stands; check the write took
    // rather than trusting rc 0 alone.
    final images = resp['images'];
    if (images is! List) return;
    final marked = images
        .map((img) => ImageState.fromMap(img as Map))
        .where((i) => _sameBytes(i.hash, hash) && (i.pending || i.confirmed));
    if (marked.isEmpty) {
      throw StateError('Device did not mark ${_hex(hash)} for $what');
    }
    onLog?.call('Image ${_hex(hash)} marked for $what');
  }

  /// Reboots the device. The link usually drops before any reply, which is
  /// the expected end; a reply refusing the reset is an error.
  Future<void> reset() async {
    final Map<dynamic, dynamic> resp;
    try {
      // Reset is Group 0, Command 5
      resp = await transport.sendRequest(SmpOp.write, SmpGroup.defaultGroup, 5, {});
    } catch (e) {
      onLog?.call('Reset: link dropped as the device rebooted ($e)');
      return;
    }
    _checkRc(resp, 'reset');
  }
}
