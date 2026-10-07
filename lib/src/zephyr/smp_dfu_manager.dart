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
/// The largest upload frame is the first one, whose map carries four entries:
///
///     {'data': <bytes>, 'off': <int>, 'len': <int>, 'confirm': <bool>}
///
/// which encodes as 1 (map header) + 5 + 3 ('data' key and a byte-string
/// header up to 64 KiB) + 4 + 5 ('off' and a uint32) + 4 + 5 ('len' likewise)
/// + 8 + 1 ('confirm' and a bool) = 36 bytes, plus the 8-byte SMP header.
/// Rounded up from 44 to leave a little slack.
const int smpFrameOverhead = 48;

/// Payload bytes one upload chunk may carry over a link of [mtu] bytes.
///
/// Floored at 128 because mcumgr answers EINVAL (rc 3) when the frame at
/// offset 0 is too small to parse the image header out of, and 128 is the size
/// this has actually been exercised with. Below an MTU of 176 the frame no
/// longer fits a single ATT packet, which is why [SmpManager.sendRequest]
/// falls back to a long write.
int smpChunkSize(int mtu) => math.max(128, mtu - smpFrameOverhead);

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

  Future<void> uploadImage(Uint8List data, {bool confirm = false, Function(double)? onProgress}) async {
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
        if (confirm) {
          payload['confirm'] = true;
        }
      }

      try {
        final resp = await transport.sendRequest(SmpOp.write, SmpGroup.image, SmpImageCmd.upload, payload);
        
        if (resp['rc'] != null && resp['rc'] != 0) {
          if (resp['rc'] == 3 && retryCount < maxRetries) {
            onLog?.call("Received rc: 3 (EINVAL) at offset $offset. Retrying...");
            retryCount++;
            // Small delay before retry
            await Future.delayed(const Duration(milliseconds: 200));
            continue; 
          }
          throw Exception("Upload failed at offset $offset with rc: ${resp['rc']}");
        }

        // Successful chunk
        retryCount = 0;
        offset = end;
        if (onProgress != null) {
          onProgress(offset / data.length);
        }
      } catch (e) {
        if (retryCount < maxRetries) {
          onLog?.call("Request failed with error: $e. Retrying...");
          retryCount++;
          await Future.delayed(Duration(milliseconds: 500 * retryCount));
          continue;
        }
        rethrow;
      }
    }
  }

  Future<void> testImage(Uint8List hash) async {
    await transport.sendRequest(SmpOp.write, SmpGroup.image, SmpImageCmd.state, {
      'hash': hash,
      'confirm': false, // Setting to false with hash means "test" on next reboot
    });
  }

  Future<void> confirmImage(Uint8List hash) async {
    await transport.sendRequest(SmpOp.write, SmpGroup.image, SmpImageCmd.state, {
      'hash': hash,
      'confirm': true,
    });
  }

  Future<void> reset() async {
    // Reset is Group 0, Command 5
    await transport.sendRequest(SmpOp.write, SmpGroup.defaultGroup, 5, {});
  }
}
