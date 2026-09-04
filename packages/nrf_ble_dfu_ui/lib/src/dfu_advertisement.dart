import 'package:dfu_service_uuids/dfu_service_uuids.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// The service a Nordic Secure DFU bootloader advertises.
///
/// A device advertising this is sitting in its bootloader waiting for an
/// image, whatever it calls itself. The uuid itself comes from
/// dfu_service_uuids, which both protocol families share.
final nordicDfuService = Guid.parse(DfuProtocol.nordic.serviceUuid)!;

/// The service an MCUmgr device advertises, which is how a Zephyr target is
/// told apart from a Nordic one before either is connected to.
final zephyrSmpService = Guid.parse(DfuProtocol.zephyr.serviceUuid)!;

/// The protocol [result] advertises, or null if it advertises neither.
DfuProtocol? dfuProtocolOf(ScanResult result) =>
    protocolOf(result.advertisementData.serviceUuids.map((g) => g.str));

/// Whether [result] is a Nordic bootloader, by what it advertises rather than
/// by what it is called.
bool isNordicBootloader(ScanResult result) =>
    dfuProtocolOf(result) == DfuProtocol.nordic;

/// The address a Nordic bootloader is expected to advertise with, given the
/// address the application was using.
///
/// Buttonless DFU without bonds reboots into a bootloader that advertises one
/// higher than the application did, so that a central which cached the
/// application's services does not reuse them. Returns null where the id is
/// not a MAC address at all: iOS and macOS hand out an opaque per-app
/// identifier, and no arithmetic on it means anything.
///
/// ponytail: increments the last octet only, which is what the SDK does and
/// covers every address that does not end in FF. If a device is ever seen
/// advertising something else after entry, widen this to a full 48-bit add
/// rather than adding another name pattern.
String? bootloaderAddressOf(String applicationAddress) {
  final octets = applicationAddress.split(':');
  if (octets.length != 6 || octets.any((o) => o.length != 2)) return null;
  final last = int.tryParse(octets.last, radix: 16);
  if (last == null) return null;
  final next = (last + 1) & 0xFF;
  return [...octets.take(5), next.toRadixString(16).padLeft(2, '0')]
      .join(':')
      .toUpperCase();
}

/// Picks the bootloader that belongs to [applicationAddress] out of [results].
///
/// Advertising the DFU service is what qualifies a candidate; the address only
/// chooses between candidates, so a single device is found whether or not it
/// shifted its address. [nameFallback], when given, is matched against the
/// advertised name for devices that advertise no service UUID at all — some
/// older bootloader builds do not.
ScanResult? findNordicBootloader(
  Iterable<ScanResult> results,
  String applicationAddress, {
  String? nameFallback,
}) {
  final expected = bootloaderAddressOf(applicationAddress);
  final candidates = results.where(isNordicBootloader).toList();

  for (final candidate in candidates) {
    final id = candidate.device.remoteId.str.toUpperCase();
    if (id == applicationAddress.toUpperCase() || id == expected) {
      return candidate;
    }
  }
  // Advertising the service is the stronger signal, so a candidate at an
  // unexpected address still beats matching a name.
  if (candidates.length == 1) return candidates.single;

  if (nameFallback != null && nameFallback.isNotEmpty) {
    final pattern = RegExp(nameFallback);
    for (final result in results) {
      if (pattern.hasMatch(result.device.platformName)) return result;
    }
  }
  return null;
}
