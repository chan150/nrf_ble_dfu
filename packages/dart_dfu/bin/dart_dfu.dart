import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:dart_dfu/src/loopback_nordic.dart';
import 'package:dart_dfu/src/loopback_transport.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

Future<void> main(List<String> args) async {
  final runner = CommandRunner<void>(
      'dart_dfu', 'Update device firmware. Speaks Nordic DFU and MCUmgr SMP.')
    ..argParser.addFlag('verbose',
        abbr: 'v',
        negatable: false,
        help: 'Print protocol diagnostics to stderr.')
    ..argParser.addFlag('loopback',
        negatable: false,
        help: 'Run against an in-memory device instead of real hardware.')
    ..addCommand(NordicCommand())
    ..addCommand(ZephyrCommand());

  try {
    await runner.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exitCode = 64;
  } catch (e) {
    stderr.writeln('dart_dfu: $e');
    exitCode = 1;
  }
}

// Each protocol keeps its own commands but the same shape, flash verb,
// progress and logging. A verb only one protocol has is absent, not faked.

class NordicCommand extends Command<void> {
  NordicCommand() {
    addSubcommand(NordicEnterCommand());
    addSubcommand(NordicUploadCommand());
  }

  @override
  final name = 'nordic';
  @override
  final description = 'nRF5 SDK bootloaders, over Nordic DFU.';
}

class ZephyrCommand extends Command<void> {
  ZephyrCommand() {
    addSubcommand(ZephyrListCommand());
    addSubcommand(ZephyrUploadCommand());
    addSubcommand(ZephyrResetCommand());
  }

  @override
  final name = 'zephyr';
  @override
  final description = 'Zephyr and MCUboot devices, over MCUmgr SMP.';
}

class NordicEnterCommand extends Command<void> {
  @override
  final name = 'enter';
  @override
  final description = 'Reboot an app-mode device into its bootloader.';

  @override
  Future<void> run() async {
    await _nordicCore(this).enterDfuMode(openNordicDevice(globalResults));
    stdout.writeln('Entry packet written.');
  }
}

class NordicUploadCommand extends Command<void> {
  @override
  final name = 'upload';
  @override
  final description = 'Flash a Nordic DFU package.';
  @override
  final invocation = 'dart_dfu nordic upload <package.zip>';

  @override
  Future<void> run() async {
    final file = _singleFile(this, 'package');
    // A package holds an init packet and an image, transferred one after the
    // other, so the percentage fills twice.
    final progress = _Progress('Flashing');

    await NordicFirmwareUpdater(
      openNordicDevice(globalResults),
      core: _nordicCore(this),
      packageName: file.path,
    ).flash(await file.readAsBytes(), onProgress: progress.report);
    progress.finish('Flashed ${file.path}.');
  }
}

class ZephyrListCommand extends Command<void> {
  @override
  final name = 'list';
  @override
  final description = 'List the firmware images on the device.';

  @override
  Future<void> run() async {
    final images = await _zephyrManager(this).listImages();
    if (images.isEmpty) {
      stdout.writeln('No images reported.');
      return;
    }
    for (final image in images) {
      stdout.writeln('slot ${image.slot}  v${image.version}'
          '${image.active ? '  active' : ''}'
          '${image.confirmed ? '  confirmed' : ''}');
    }
  }
}

class ZephyrUploadCommand extends Command<void> {
  ZephyrUploadCommand() {
    argParser.addFlag('confirm',
        negatable: false, help: 'Mark the image confirmed once it is written.');
  }

  @override
  final name = 'upload';
  @override
  final description = 'Flash a firmware image.';
  @override
  final invocation = 'dart_dfu zephyr upload <image.bin>';

  @override
  Future<void> run() async {
    final file = _singleFile(this, 'image');
    final image = await file.readAsBytes();
    final progress = _Progress('Flashing');

    final updater = SmpFirmwareUpdater(
      openZephyrTransport(globalResults),
      onLog: _verboseLog(this),
    );
    await updater.flash(image, onProgress: progress.report);
    if (argResults!['confirm'] as bool) {
      await updater.manager.markUploaded(image, confirm: true);
    }
    progress.finish('Flashed ${image.length} bytes.');
  }
}

class ZephyrResetCommand extends Command<void> {
  @override
  final name = 'reset';
  @override
  final description = 'Reboot the device.';

  @override
  Future<void> run() async {
    await _zephyrManager(this).reset();
    stdout.writeln('Reset requested.');
  }
}

/// Resolves the link to a Nordic bootloader.
///
/// This and [openZephyrTransport] are the only two places that know hardware
/// exists. Implement the interface, return it from here, and nothing above
/// these lines changes.
DfuDevice openNordicDevice(ArgResults? globals) =>
    globals?['loopback'] == true
        ? LoopbackBootloader()
        : _notWired('DfuDevice', 'openNordicDevice');

/// Resolves the link to a Zephyr device; see [openNordicDevice].
SmpTransport openZephyrTransport(ArgResults? globals) =>
    globals?['loopback'] == true
        ? LoopbackTransport()
        : _notWired('SmpTransport', 'openZephyrTransport');

Never _notWired(String type, String function) => throw StateError(
      'No transport is wired up yet. Pass --loopback to run against an '
      'in-memory device, or implement $type for your hardware and return it '
      'from $function().',
    );

NrfBleDfu _nordicCore(Command<void> cmd) {
  final dfu = NrfBleDfu()..initialize();
  if (cmd.globalResults?['verbose'] == true) {
    dfu.onLog.listen((entry) => stderr.writeln(entry.message));
  }
  return dfu;
}

SmpDfuManager _zephyrManager(Command<void> cmd) => SmpDfuManager(
      openZephyrTransport(cmd.globalResults),
      onLog: _verboseLog(cmd),
    );

/// stderr under --verbose, so diagnostics never land in whatever is reading
/// stdout; nothing otherwise.
void Function(String)? _verboseLog(Command<void> cmd) =>
    cmd.globalResults?['verbose'] == true ? stderr.writeln : null;

File _singleFile(Command<void> cmd, String what) {
  final rest = cmd.argResults!.rest;
  if (rest.length != 1) cmd.usageException('Expected exactly one $what path.');
  final file = File(rest.single);
  if (!file.existsSync()) throw StateError('No such file: ${file.path}');
  return file;
}

/// Redraws a percentage in place, and only when the whole number moves, so
/// piping to a file does not produce a line per packet.
class _Progress {
  _Progress(this.label);

  final String label;
  var _last = -1;

  void report(double fraction) {
    final percent = (fraction * 100).floor();
    if (percent == _last) return;
    _last = percent;
    stdout.write('\r$label: $percent%');
  }

  void finish(String message) => stdout.writeln('\r$message        ');
}
