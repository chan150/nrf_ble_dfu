import 'dart:developer';

import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';

extension Int32ByteArray on int {
  List<int> get toBytes => [
        for (var i = 0; i < 4; i++) (this & (0xFF << (i * 8))) >> (i * 8),
      ];
}

extension ByteArray2Int32 on List<int> {
  int getInt32([int offset = 0]) => [
        for (var i = offset; i < offset + 4 && i < length; i++) this[i] << (i * 8),
      ].fold(0, (l, r) => l + r);
}

extension BluetoothCharacteristicRead on BluetoothCharacteristic {
  Future<List<int>> writeWaitForCompletion(List<int> packet) async {
    final result = <int>[];

    print(packet.hex);

    final subscription = onValueReceived.listen((event) => result.addAll(event));
    await write(packet);

    /// TODO: busy waiting => async when 으로 수정 필요
    while (result.isEmpty) {}

    log((packet.hex, result.hex).toString());
    subscription.cancel();
    return result;
  }
}

extension PacketExtension on List<int> {
  List<String> get hex => [...map((e) => '0x${e.toRadixString(16).toUpperCase()}')];
}
