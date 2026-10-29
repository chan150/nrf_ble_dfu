import 'dart:typed_data';

import 'package:nrf_ble_dfu_smp/nrf_ble_dfu_smp.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pipelined upload against a fake mcumgr that, like the real one, takes
/// only the frame starting at the offset it expects and answers with that
/// offset. Whatever frames get lost, the slot has to end up holding the file.
void main() {
  final image = Uint8List.fromList([for (var i = 0; i < 5000; i++) i * 7 % 251]);

  // Frames with these indices (counted over the whole upload) find no buffer
  // and are never answered, as when mcumgr's pool runs dry. [rc] makes the
  // device refuse every frame.
  Future<({Uint8List slot, int maxInFlight, List<double> progress})> upload(int window,
      {Set<int> lose = const {}, int? rc}) async {
    final slot = Uint8List(image.length);
    var expected = 0, frames = 0, inFlight = 0, maxInFlight = 0;
    final progress = <double>[];
    await pipelinedUpload(
      image,
      chunkSize: 200,
      window: window,
      onProgress: progress.add,
      send: (payload) {
        final frame = frames++;
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        if (lose.contains(frame)) {
          // Unanswered: the transport gives up on it later.
          return Future.delayed(const Duration(milliseconds: 50), () {
            inFlight--;
            throw TimeoutException('lost frame $frame');
          });
        }
        final off = payload['off']! as int;
        final data = payload['data']! as Uint8List;
        if (rc == null && off == expected) {
          slot.setAll(off, data);
          expected = off + data.length;
        }
        // Its answer says where it stood after this frame, not after later ones.
        final answer = {'rc': rc ?? 0, 'off': expected};
        return Future(() {
          inFlight--;
          return answer;
        });
      },
    );
    return (slot: slot, maxInFlight: maxInFlight, progress: progress);
  }

  test('with nothing lost the image lands whole, window frames at a time', () async {
    final r = await upload(3);
    expect(r.slot, image);
    expect(r.maxInFlight, 3);
    expect(r.progress.last, 1.0);
  });

  test('lost frames, the last one too, are resent from where the device is', () async {
    // 5000 / 200 = 25 frames when nothing is lost; 24 is the last of those.
    final r = await upload(4, lose: {3, 9, 10, 24, 30});
    expect(r.slot, image);
    expect(r.progress.last, 1.0);
  });

  test('a device that keeps refusing ends the upload with an error', () async {
    await expectLater(upload(2, rc: 3), throwsStateError);
  });
}
