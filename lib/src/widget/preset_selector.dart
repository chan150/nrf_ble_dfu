import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nrf_ble_dfu/nrf_ble_dfu.dart';

class PresetSelector extends StatelessObserverWidget {
  const PresetSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final dfu = NrfBleDfu();
    
    // 현재 설정과 일치하는 프리셋이 있는지 확인 (단순 구현을 위해 인덱스 추적은 생략하거나 첫 매칭 사용)
    // 여기서는 별도의 selectedIndex 없이 드롭다운 선택 시 로드만 수행하는 방식으로 구현합니다.
    
    return Row(
      children: [
        const Text('Preset: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<int>(
            isExpanded: true,
            value: dfu.selectedPresetIndex.value,
            hint: const Text('Select a preset', style: TextStyle(fontSize: 12)),
            underline: Container(), // 하단 라인 제거
            items: List.generate(dfu.presets.length, (i) {
              return DropdownMenuItem(
                value: i,
                child: Text(dfu.presets[i].name, style: const TextStyle(fontSize: 12)),
              );
            }),
            onChanged: (index) {
              if (index != null) {
                dfu.loadPreset(index);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        // 현재 선택된(가장 최근에 로드된) 슬롯에 저장하거나 관리하는 버튼들
        // 드롭다운 방식에서는 특정 슬롯을 선택 후 '저장' 버튼을 누르는 형태가 일반적입니다.
        // 여기서는 편의를 위해 마지막으로 선택했던 인덱스를 알 수 없으므로, 
        // 팝업이나 별도의 UI를 통해 저장할 슬롯을 고르게 할 수도 있지만, 
        // 일단 드롭다운 옆에 '현재 설정을 저장'하는 공통 버튼을 두겠습니다.
        
        PopupMenuButton<int>(
          icon: const Icon(Icons.save, size: 20),
          tooltip: 'Save current to...',
          onSelected: (i) => dfu.updatePreset(i),
          itemBuilder: (context) => List.generate(dfu.presets.length, (i) {
            return PopupMenuItem(
              value: i,
              child: Text('Save to ${dfu.presets[i].name}', style: const TextStyle(fontSize: 12)),
            );
          }),
        ),
        PopupMenuButton<int>(
          icon: const Icon(Icons.edit, size: 20),
          tooltip: 'Rename...',
          onSelected: (i) => _rename(context, i),
          itemBuilder: (context) => List.generate(dfu.presets.length, (i) {
            return PopupMenuItem(
              value: i,
              child: Text('Rename ${dfu.presets[i].name}', style: const TextStyle(fontSize: 12)),
            );
          }),
        ),
      ],
    );
  }

  void _rename(BuildContext context, int index) async {
    final dfu = NrfBleDfu();
    final controller = TextEditingController(text: dfu.presets[index].name);
    final name = await showAdaptiveDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Preset'),
        content: TextField(
          controller: controller,
          autofocus: true,
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
    if (name != null && name.isNotEmpty) {
      dfu.renamePreset(index, name);
    }
  }
}
