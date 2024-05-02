extension Int32ByteArray on int {
  List<int> get toBytes => [
        for (var i = 0; i < 4; i++) (this & (0xFF << (i * 8))) >> (i * 8),
      ];
}

extension ByteArray2Int32 on List<int> {
  int getInt32([int offset = 0]) => [
        for (var i = 0; i < 4 && i + offset < length; i++) this[i + offset] << (i * 8),
      ].fold(0, (l, r) => l + r);
}

extension PacketExtensionToString on List<int> {
  List<String> get hex => [
        ...map((e) => '0x${e.toRadixString(16).toUpperCase().padLeft(2, '0')}'),
      ];

  String get hexString => hex.toString();
}

extension PacketExtensionFromString on String {
  List<int> get list {
    if (!startsWith('[')) return [];
    if (!endsWith(']')) return [];

    final trim = substring(1, length - 1);
    final split = trim.split(',');
    final parsed = split.map((e) => int.tryParse(e));
    if (parsed.contains(null)) throw Exception('Invalid integer format');
    return [...parsed.map((e) => e!)];
  }
}
