/// The service UUIDs that say which firmware-update protocol a device speaks,
/// and the little arithmetic needed to compare them.
///
/// Deliberately free of dependencies, Bluetooth stack included, so that both
/// protocol families can share it without either dragging the other's
/// packages along. Callers hand it the uuids their scanner reported; adapting
/// a platform type to a string is the caller's job.
library dfu_service_uuids;

/// A firmware-update protocol, identified by the service it advertises.
enum DfuProtocol {
  /// nRF5 SDK bootloaders. Nordic's assigned 16-bit UUID, written out long.
  nordic('0000fe59-0000-1000-8000-00805f9b34fb', 'Nordic DFU'),

  /// Zephyr and MCUboot, over MCUmgr's Simple Management Protocol.
  zephyr('8d53dc1d-1db7-4cd3-868b-8a527460aa84', 'MCUmgr SMP');

  const DfuProtocol(this.serviceUuid, this.label);

  /// The advertised service, as a lowercase 128-bit UUID.
  final String serviceUuid;

  /// How to name this protocol to a person.
  final String label;
}

/// Rewrites [uuid] as a lowercase 128-bit UUID, or returns null if it is not
/// one at all.
///
/// A 16- or 32-bit UUID is shorthand for a range of the Bluetooth base UUID,
/// and which form a platform reports is not something callers can rely on:
/// Android tends to give the long one and iOS the short one for the very same
/// service. Expanding both to one form is what makes comparison safe, and is
/// why matching a UUID by substring goes wrong.
String? normalizeUuid(String uuid) {
  final trimmed = uuid.trim().toLowerCase();
  if (!RegExp(r'^[0-9a-f-]+$').hasMatch(trimmed)) return null;

  final bare = trimmed.replaceAll('-', '');
  const baseSuffix = '00001000800000805f9b34fb';

  switch (bare.length) {
    case 4:
      return _hyphenate('0000$bare$baseSuffix');
    case 8:
      return _hyphenate('$bare$baseSuffix');
    case 32:
      return _hyphenate(bare);
    default:
      return null;
  }
}

String _hyphenate(String bare) => '${bare.substring(0, 8)}-'
    '${bare.substring(8, 12)}-'
    '${bare.substring(12, 16)}-'
    '${bare.substring(16, 20)}-'
    '${bare.substring(20)}';

/// Whether [advertisedUuids] contains the service [protocol] advertises.
bool advertises(Iterable<String> advertisedUuids, DfuProtocol protocol) =>
    advertisedUuids.map(normalizeUuid).contains(protocol.serviceUuid);

/// Which protocol [advertisedUuids] belongs to, or null for neither.
///
/// Nothing advertises both, so the first match settles it.
DfuProtocol? protocolOf(Iterable<String> advertisedUuids) {
  final normalized = advertisedUuids.map(normalizeUuid).toSet();
  for (final protocol in DfuProtocol.values) {
    if (normalized.contains(protocol.serviceUuid)) return protocol;
  }
  return null;
}
