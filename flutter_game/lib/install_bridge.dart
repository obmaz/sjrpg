import 'install_bridge_stub.dart'
    if (dart.library.js_interop) 'install_bridge_web.dart'
    as implementation;

abstract class InstallBridge {
  bool get available;
  bool get installed;
  String get message;
  void request();
  void listen(void Function() onChange);
  void dispose();
}

InstallBridge createInstallBridge() => implementation.createBridge();
