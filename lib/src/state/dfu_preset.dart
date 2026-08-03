class DfuPreset {
  String name;
  String entryUuid;
  String entryPkt; // Hex string to match Python
  String targetName;
  String targetDfuName;

  DfuPreset({
    required this.name,
    required this.entryUuid,
    required this.entryPkt,
    required this.targetName,
    required this.targetDfuName,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'entry_uuid': entryUuid,
        'entry_pkt': entryPkt,
        'target_name': targetName,
        'target_dfu_name': targetDfuName,
      };

  factory DfuPreset.fromJson(Map<String, dynamic> json) => DfuPreset(
        name: json['name'] as String? ?? 'Unnamed',
        entryUuid: json['entry_uuid'] as String? ?? '',
        entryPkt: json['entry_pkt'] as String? ?? '',
        targetName: json['target_name'] as String? ?? '',
        targetDfuName: json['target_dfu_name'] as String? ?? '',
      );
}

class DfuPresetsContainer {
  Map<String, dynamic> lastUsed;
  List<DfuPreset> presets;

  DfuPresetsContainer({
    required this.lastUsed,
    required this.presets,
  });

  Map<String, dynamic> toJson() => {
        'last_used': lastUsed,
        'presets': presets.map((e) => e.toJson()).toList(),
      };

  factory DfuPresetsContainer.fromJson(Map<String, dynamic> json) {
    return DfuPresetsContainer(
      lastUsed: (json['last_used'] as Map<String, dynamic>?) ?? {},
      presets: (json['presets'] as List<dynamic>?)
              ?.map((e) => DfuPreset.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
