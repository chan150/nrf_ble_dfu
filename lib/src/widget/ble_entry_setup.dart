import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

class BleEntrySetup extends StatelessWidget {
  const BleEntrySetup({super.key});

  @override
  Widget build(BuildContext context) {
    final dfu = NrfBleDfu();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top: Preset Management (Dropdown Row)
        const PresetSelector(),
        const Divider(),
        // Bottom: Configuration Inputs - Individually observed to prevent full rebuilds
        Observer(
          builder: (_) => DfuInputField(
            k: 'Entry UUID',
            v: dfu.entryControlPoint,
            updateFn: (s) => dfu.entryControlPoint = s,
          ),
        ),
        Observer(
          builder: (_) => DfuInputField(
            k: 'Entry Packet',
            v: dfu.entryPacket.rawHex,
            updateFn: (s) => dfu.entryPacket = s.fromRawHex,
          ),
        ),
        Observer(
          builder: (_) => DfuInputField(
            k: 'Auto Entry Name',
            v: dfu.autoEntryDeviceName,
            updateFn: (s) => dfu.autoEntryDeviceName = s,
          ),
        ),
        Observer(
          builder: (_) => DfuInputField(
            k: 'Auto DFU Name',
            v: dfu.autoDfuDeviceName,
            updateFn: (s) => dfu.autoDfuDeviceName = s,
          ),
        ),
      ],
    );
  }
}

class DfuInputField extends StatefulWidget {
  const DfuInputField({
    super.key,
    required this.k,
    required this.v,
    required this.updateFn,
  });

  final String k;
  final String v;
  final void Function(String) updateFn;

  @override
  State<DfuInputField> createState() => _DfuInputFieldState();
}

class _DfuInputFieldState extends State<DfuInputField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.v);
  }

  @override
  void didUpdateWidget(DfuInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.v != widget.v && _controller.text != widget.v) {
      _controller.text = widget.v;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              widget.k,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
              ),
              onChanged: (val) => widget.updateFn(val),
            ),
          ),
        ],
      ),
    );
  }
}
