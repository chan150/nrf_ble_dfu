import 'dart:typed_data';

class SmpHeader {
  static const int headerLength = 8;

  final int op;
  final int flags;
  final int length;
  final int group;
  final int sequence;
  final int commandId;

  SmpHeader({
    required this.op,
    required this.flags,
    required this.length,
    required this.group,
    required this.sequence,
    required this.commandId,
  });

  Uint8List toBytes() {
    final buffer = Uint8List(headerLength);
    final view = ByteData.view(buffer.buffer);
    view.setUint8(0, op);
    view.setUint8(1, flags);
    view.setUint16(2, length, Endian.big);
    view.setUint16(4, group, Endian.big);
    view.setUint8(6, sequence);
    view.setUint8(7, commandId);
    return buffer;
  }

  factory SmpHeader.fromBytes(Uint8List bytes) {
    if (bytes.length < headerLength) {
      throw Exception('Invalid SMP header length');
    }
    final view = ByteData.view(bytes.buffer, bytes.offsetInBytes, headerLength);
    return SmpHeader(
      op: view.getUint8(0),
      flags: view.getUint8(1),
      length: view.getUint16(2, Endian.big),
      group: view.getUint16(4, Endian.big),
      sequence: view.getUint8(6),
      commandId: view.getUint8(7),
    );
  }

  @override
  String toString() {
    return 'SmpHeader(op: $op, flags: $flags, length: $length, group: $group, sequence: $sequence, commandId: $commandId)';
  }
}

class SmpOp {
  static const int read = 0;
  static const int readRsp = 1;
  static const int write = 2;
  static const int writeRsp = 3;
}

class SmpGroup {
  static const int defaultGroup = 0;
  static const int image = 1;
  static const int stats = 2;
  static const int config = 3;
  static const int logs = 4;
}

class SmpImageCmd {
  static const int state = 0;
  static const int upload = 1;
  static const int hash = 2;
  static const int coreList = 3;
  static const int list = 4;
}
