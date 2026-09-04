/// The listener half of ChangeNotifier, without Flutter.
///
/// ChangeNotifier is the only reason these state classes ever imported
/// package:flutter, and these three members are all that was used of it. The
/// UI package bridges this to a real Listenable.
class DfuListenable {
  final _listeners = <void Function()>[];

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  void notifyListeners() {
    // Iterate a copy: a listener that removes itself while being notified
    // would otherwise mutate the list underneath the loop.
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }
}
