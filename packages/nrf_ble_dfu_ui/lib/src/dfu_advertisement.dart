import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// The service a Nordic Secure DFU bootloader advertises.
///
/// Nordic's assigned 16-bit UUID. A device advertising this is sitting in its
/// bootloader waiting for an image, whatever it calls itself.
final nordicDfuService = Guid.parse('FE59')!;

/// The service an MCUmgr device advertises, which is how a Zephyr target is
/// told apart from a Nordic one before either is connected to.
final zephyrSmpService = Guid.parse('8D53DC1D-1DB7-4CD3-868B-8A527460AA84')!;

/// Which update protocol a device speaks.
enum DfuProtocol { nordic, zephyr }

/// The protocol [result] advertises, or null if it advertises neither.
///
/// Guid compares by its 128-bit form, so a 16-bit UUID off the wire matches
/// the long form and there is no string munging to get wrong.
DfuProtocol? dfuProtocolOf(ScanResult result) {
  final advertised = result.advertisementData.serviceUuids;
  if (advertised.contains(nordicDfuService)) return DfuProtocol.nordic;
  if (advertised.contains(zephyrSmpService)) return DfuProtocol.zephyr;
  return null;
}

/// Whether [result] is a Nordic bootloader, by what it advertises rather than
/// by what it is called.
bool isNordicBootloader(ScanResult result) =>
    result.advertisementData.serviceUuids.contains(nordicDfuService);

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
