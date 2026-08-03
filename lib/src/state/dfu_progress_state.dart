import 'package:flutter/foundation.dart';

class DfuProgressState extends ChangeNotifier {
  int? fileSize;
  int? completedSize;

  void update({
    int? fileSize,
    int? completedSize,
  }) {
    this.fileSize = fileSize ?? this.fileSize;
    this.completedSize = completedSize ?? this.completedSize;
    notifyListeners();
  }

  void reset() {
    fileSize = null;
    completedSize = null;
    notifyListeners();
  }
}
