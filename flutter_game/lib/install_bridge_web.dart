import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'install_bridge.dart';

InstallBridge createBridge() => _BrowserInstall();

class _BrowserInstall implements InstallBridge {
  JSFunction? listener;
  String result = '';
  @override
  bool get available =>
      web.document.documentElement?.getAttribute('data-install-ready') ==
      'true';
  @override
  bool get installed =>
      web.window.matchMedia('(display-mode: standalone)').matches ||
      web.document.documentElement?.getAttribute('data-app-installed') ==
          'true';
  @override
  String get message {
    if (installed) return '앱이 설치되어 있습니다. 홈 화면에서 바로 시작하세요.';
    if (result == 'dismissed') return '설치를 취소했습니다. 원할 때 다시 설치할 수 있습니다.';
    if (result == 'accepted') return '설치를 요청했습니다. 설치 후 홈 화면에서 시작하세요.';
    if (available) return '홈 화면에서 전체화면으로 바로 실행할 수 있습니다.';
    final agent = web.window.navigator.userAgent;
    if (agent.contains('iPhone') ||
        agent.contains('iPad') ||
        (agent.contains('Macintosh') &&
            web.window.navigator.maxTouchPoints > 1)) {
      return 'Safari의 공유 버튼 → 홈 화면에 추가를 선택하세요.';
    }
    return '브라우저 메뉴에서 앱 설치 또는 홈 화면에 추가를 선택하세요.';
  }

  @override
  void request() =>
      web.document.dispatchEvent(web.Event('guardian-install-request'));
  @override
  void listen(void Function() onChange) {
    listener = ((web.Event event) {
      result =
          web.document.documentElement?.getAttribute('data-install-result') ??
          '';
      onChange();
    }).toJS;
    web.document.addEventListener('guardian-install-change', listener);
  }

  @override
  void dispose() {
    if (listener != null) {
      web.document.removeEventListener('guardian-install-change', listener);
    }
  }
}
