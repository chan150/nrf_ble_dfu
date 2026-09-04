/// A characteristic on a connected device.
abstract class DfuCharacteristic {
  String get uuid;

  /// The negotiated ATT MTU, or 23 where none has been negotiated.
  int get mtu;

  /// What the device sends once notifications are on.
  Stream<List<int>> get values;

  Future<void> write(List<int> value, {bool withoutResponse = false});

  Future<void> setNotify(bool enable);
}

/// A device a transfer can be run against.
///
/// There is deliberately no scanning here. Finding a device is the caller's
/// business, and leaving it out is most of why this package needs no
/// Bluetooth stack of its own.
abstract class DfuDevice {
  String get id;

  Future<void> connect({Duration? timeout});

  Future<void> disconnect();

  /// Every characteristic of every service, flattened, because the transfer
  /// only ever looks them up by uuid.
  Future<List<DfuCharacteristic>> discoverCharacteristics();
}
