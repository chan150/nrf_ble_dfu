import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

class BleEntrySetup extends StatelessObserverWidget {
  const BleEntrySetup({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        EditableText(
          k: 'entryControlPoint',
          v: NrfBleDfu().setup.entryControlPoint,
          updateFn: (s) => NrfBleDfu().setup.entryControlPoint = s,
        ),
        EditableText(
          k: 'entryPacket',
          v: NrfBleDfu().setup.entryPacket.hexString,
          updateFn: (s) {
            NrfBleDfu().setup.entryPacket.clear();
            NrfBleDfu().setup.entryPacket.addAll(s.list);
          },
        ),
        EditableText(
          k: 'dfuControlPoint',
          v: NrfBleDfu().setup.dfuControlPoint,
          updateFn: (s) => NrfBleDfu().setup.dfuControlPoint = s,
        ),
        EditableText(
          k: 'dfuDataPoint',
          v: NrfBleDfu().setup.dfuDataPoint,
          updateFn: (s) => NrfBleDfu().setup.dfuDataPoint = s,
        ),
      ],
    );
  }
}

class EditableText extends StatelessWidget {
  const EditableText({
    super.key,
    required this.k,
    required this.v,
    required this.updateFn,
  });

  final String k;
  final String v;
  final void Function(String) updateFn;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showDialog(context),
      child: Text('$k : $v'),
    );
  }

  Future<dynamic> _showDialog(BuildContext context) =>
      showAdaptiveDialog(context: context, builder: (context) => _buildDialog(context));

  Dialog _buildDialog(BuildContext context) {
    final controller = TextEditingController(text: v);
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onEditingComplete: () => updateFn(controller.text),
              ),
            ),
            IconButton(
              onPressed: () {
                updateFn(controller.text);
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.check),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
