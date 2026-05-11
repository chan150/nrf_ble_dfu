import 'dart:convert';

class DfuPreset {
  String name;
  String entryControlPoint;
  List<int> entryPacket;
  String autoEntryDeviceName;
  String autoDfuDeviceName;

  DfuPreset({
    required this.name,
    required this.entryControlPoint,
    required this.entryPacket,
    required this.autoEntryDeviceName,
    required this.autoDfuDeviceName,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'entryControlPoint': entryControlPoint,
        'entryPacket': entryPacket,
        'autoEntryDeviceName': autoEntryDeviceName,
        'autoDfuDeviceName': autoDfuDeviceName,
      };

  factory DfuPreset.fromJson(Map<String, dynamic> json) => DfuPreset(
        name: json['name'] as String,
        entryControlPoint: json['entryControlPoint'] as String,
        entryPacket: (json['entryPacket'] as List).cast<int>(),
        autoEntryDeviceName: json['autoEntryDeviceName'] as String,
        autoDfuDeviceName: json['autoDfuDeviceName'] as String,
      );
}
