import 'install_bridge.dart';

InstallBridge createBridge() => _UnavailableInstall();

class _UnavailableInstall implements InstallBridge {
  @override
  bool get available => false;
  @override
  bool get installed => false;
  @override
  String get message => '브라우저 메뉴에서 앱 설치 또는 홈 화면에 추가를 선택하세요.';
  @override
  void request() {}
  @override
  void listen(void Function() onChange) {}
  @override
  void dispose() {}
}
