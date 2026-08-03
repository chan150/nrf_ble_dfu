import 'package:flutter/foundation.dart';

class DfuFileState extends ChangeNotifier {
  String? path;
  String? outputPath;
  String? binPath;
  String? datPath;

  void update({
    String? path,
    String? outputPath,
    String? binPath,
    String? datPath,
  }) {
    this.path = path ?? this.path;
    this.outputPath = outputPath ?? this.outputPath;
    this.binPath = binPath ?? this.binPath;
    this.datPath = datPath ?? this.datPath;
    notifyListeners();
  }

  void reset() {
    path = null;
    outputPath = null;
    binPath = null;
    datPath = null;
    notifyListeners();
  }
}
