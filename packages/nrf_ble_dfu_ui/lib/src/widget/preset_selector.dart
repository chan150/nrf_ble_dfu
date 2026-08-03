import 'package:flutter/material.dart';
import 'package:nrf_ble_dfu_ui/nrf_ble_dfu_ui.dart';

class PresetSelector extends StatelessWidget {
  const PresetSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final dfu = NrfBleDfu();

    return ListenableBuilder(
      listenable: dfu.setup,
      builder: (context, _) {
        final storedIdx = dfu.selectedPresetIndex;
        final selectedIdx = (storedIdx != null &&
                storedIdx >= 0 &&
                storedIdx < dfu.presets.length)
            ? storedIdx
            : null;
        return Row(
          children: [
            const Text('Preset: ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<int>(
                isExpanded: true,
                value: selectedIdx,
                hint: const Text('Select a preset',
                    style: TextStyle(fontSize: 12)),
                underline: Container(), // Removes underline
                items: List.generate(dfu.presets.length, (i) {
                  return DropdownMenuItem(
                    value: i,
                    child: Text(dfu.presets[i].name,
                        style: const TextStyle(fontSize: 12)),
                  );
                }),
                onChanged: (index) {
                  if (index != null) {
                    dfu.loadPreset(index);
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            // Action Menu for managing presets
            PopupMenuButton<String>(
              icon: const Icon(Icons.menu, size: 20),
              tooltip: 'Preset Menu',
              onSelected: (action) {
                switch (action) {
                  case 'save':
                    if (selectedIdx != null) dfu.updatePreset(selectedIdx);
                    break;
                  case 'add':
                    _addNew(context);
                    break;
                  case 'rename':
                    if (selectedIdx != null) _rename(context, selectedIdx);
                    break;
                  case 'delete':
                    if (selectedIdx != null) dfu.deletePreset(selectedIdx);
                    break;
                }
              },
              itemBuilder: (context) => [
                if (selectedIdx != null)
                  PopupMenuItem(
                    value: 'save',
                    child: Row(
                      children: [
                        Icon(Icons.save, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text('Save changes',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'add',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline,
                          size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      const Text('Save as new...',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                if (selectedIdx != null)
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit,
                            size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        const Text('Rename...', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                if (selectedIdx != null && dfu.presets.length > 1)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        const Text('Delete',
                            style: TextStyle(fontSize: 12, color: Colors.red)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _addNew(BuildContext context) async {
    final dfu = NrfBleDfu();
    final controller = TextEditingController(text: 'New Preset');
    final name = await _showNameDialog(context, 'New Preset Name', controller);
    if (name != null && name.isNotEmpty) {
      dfu.addNewPreset(name);
    }
  }

  void _rename(BuildContext context, int index) async {
    final dfu = NrfBleDfu();
    final controller = TextEditingController(text: dfu.presets[index].name);
    final name = await _showNameDialog(context, 'Rename Preset', controller);
    if (name != null && name.isNotEmpty) {
      dfu.renamePreset(index, name);
    }
  }

  Future<String?> _showNameDialog(
      BuildContext context, String title, TextEditingController controller) {
    return showAdaptiveDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(isDense: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
