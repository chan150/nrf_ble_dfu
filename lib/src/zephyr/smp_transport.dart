/// What [SmpDfuManager] needs from a link to the device, and nothing more.
///
/// Holding the seam to these two members is what lets the DFU logic stay pure
/// Dart. The Bluetooth stack, the CBOR framing and the notification
/// reassembly all sit behind this, in a package that can afford those
/// dependencies.
abstract class SmpTransport {
  /// The negotiated ATT MTU, or 23 where none has been negotiated.
  int get mtu;

  /// Sends one SMP request and completes with the decoded response map.
  Future<Map<dynamic, dynamic>> sendRequest(
    int op,
    int group,
    int commandId,
    Map<dynamic, dynamic> payload,
  );
}
