import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

/// An in-memory Nordic DFU bootloader, enough of one to run a transfer against.
///
/// It implements the object protocol the core drives: select, create, receive,
/// report a CRC, execute. That makes it the only thing that exercises packet
/// receipt notifications and the offset and CRC checks without hardware.
///
/// ponytail: happy path only. It never reports a short offset or a bad CRC, so
/// it proves the checks pass when they should, not that they fail when they
/// should. Add a fault-injection flag when a device is seen misbehaving.
class LoopbackBootloader implements DfuDevice {
  LoopbackBootloader({this.mtu = 247, this.maxObjectSize = 4096});

  final int mtu;
  final int maxObjectSize;

  /// Bytes accepted and executed, keyed by transfer type (init packet, image).
  final Map<int, List<int>> committed = {};

  late final _control = _Characteristic(this, _controlUuid, mtu);
  late final _data = _Characteristic(this, _dataUuid, mtu);
  late final _entry = _Characteristic(this, _entryUuid, mtu);

  static const _controlUuid = '8ec90001-f315-4f60-9fb8-838830daea50';
  static const _dataUuid = '8ec90002-f315-4f60-9fb8-838830daea50';
  static const _entryUuid = '00002cf0-0000-1000-8000-00805f9b34fb';

  /// The packet an app-mode device is sent to make it reboot into DFU.
  List<int>? entryPacket;

  int _prn = 0;
  int _type = 0;
  List<int> _pending = [];
  int _packetsSinceReceipt = 0;

  @override
  String get id => 'loopback';

  @override
  Future<void> connect({Duration? timeout}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<DfuCharacteristic>> discoverCharacteristics() async =>
      [_entry, _control, _data];

  List<int> get _accepted => [...?committed[_type], ..._pending];

  void _respond(int op) => _control.emit([0x60, op, 0x01]);

  void _receipt() {
    final accepted = _accepted;
    _packetsSinceReceipt = 0;
    _control.emit([
      0x60,
      NrfDfuOp.crcGet.code,
      0x01,
      ...accepted.length.toBytes,
      ...dfuCrc32(accepted).toBytes,
    ]);
  }

  void _onControlWrite(List<int> command) {
    final op = command.first;
    if (op == NrfDfuOp.receiptNotifSet.code) {
      _prn = command[1] | (command[2] << 8);
      _respond(op);
    } else if (op == NrfDfuOp.objectSelect.code) {
      _type = command[1];
      final accepted = _accepted;
      _control.emit([
        0x60,
        op,
        0x01,
        ...maxObjectSize.toBytes,
        ...accepted.length.toBytes,
        ...dfuCrc32(accepted).toBytes,
      ]);
    } else if (op == NrfDfuOp.objectCreate.code) {
      _pending = [];
      _packetsSinceReceipt = 0;
      _respond(op);
    } else if (op == NrfDfuOp.crcGet.code) {
      _receipt();
    } else if (op == NrfDfuOp.objectExecute.code) {
      committed[_type] = [...?committed[_type], ..._pending];
      _pending = [];
      _respond(op);
    } else {
      _control.emit([0x60, op, 0x02]); // not supported
    }
  }

  void _onDataWrite(List<int> packet) {
    _pending = [..._pending, ...packet];
    _packetsSinceReceipt++;
    // A real bootloader reports on its own once the agreed number of packets
    // has arrived; a short batch is left for an explicit request.
    if (_prn > 0 && _packetsSinceReceipt >= _prn) _receipt();
  }
}

class _Characteristic implements DfuCharacteristic {
  _Characteristic(this._device, this.uuid, this.mtu);

  final LoopbackBootloader _device;
  final _controller = StreamController<List<int>>.broadcast();
  List<int> _last = const [];

  @override
  final String uuid;

  @override
  final int mtu;

  void emit(List<int> value) {
    _last = value;
    _controller.add(value);
  }

  /// Replays the last value, the way a real characteristic's stream does.
  ///
  /// The subscription to the source has to be in place before the replay, or
  /// the response to the write the replay provokes lands while nothing is
  /// listening and is dropped. An async* generator cannot do that: it sits
  /// suspended on its first yield and only reaches the source afterwards.
  @override
  Stream<List<int>> get values => Stream.multi((controller) {
        final subscription = _controller.stream.listen(controller.add,
            onError: controller.addError, onDone: controller.close);
        controller.onCancel = subscription.cancel;
        controller.add(_last);
      });

  @override
  Future<void> setNotify(bool enable) async {
    if (enable) emit(const []);
  }

  @override
  Future<void> write(List<int> value, {bool withoutResponse = false}) async {
    if (identical(this, _device._control)) {
      _device._onControlWrite(value);
    } else if (identical(this, _device._entry)) {
      // A real device reboots here, which is why the core tolerates the write
      // failing. There is nothing to reboot into, so just record it.
      _device.entryPacket = value;
    } else {
      _device._onDataWrite(value);
    }
  }
}
