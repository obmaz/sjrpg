class BackActions {
  final _handlers = <void Function()>[];

  void Function() register(void Function() action) {
    _handlers.add(action);
    return () => _handlers.remove(action);
  }

  void dispatch() {
    if (_handlers.isNotEmpty) _handlers.last();
  }
}
