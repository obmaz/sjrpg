# 안드로이드 빌드

3D판을 안드로이드 앱(APK)으로 만드는 방법입니다. 같은 Godot 프로젝트(GL Compatibility)를 그대로 쓰며, 별도 소스는 없습니다.
패키지 이름은 `com.obmaz.sjrpg3d`, 앱 이름은 "자연의 수호자", 아키텍처는 `arm64-v8a`(최근 휴대폰 대부분)입니다.

```sh
tools/setup_android.sh                # 한 번만: Android SDK·Godot 안드로이드 템플릿·디버그 키스토어·에디터 설정 (JDK 17+ 필요)
tools/export_android.sh               # build/android/sjrpg_3d-debug.apk   (디버그 키로 서명, 시험 설치용)
tools/export_android.sh --release     # build/android/sjrpg_3d-release.apk (릴리스 키가 필요, 아래 참고)
adb install -r build/android/sjrpg_3d-debug.apk
```

## 구성

- `export_presets.cfg`의 `Android` 프리셋: 그래들 빌드 없이 Godot가 제공하는 미리 만든 APK 템플릿에 게임 리소스를 넣어 서명합니다.
  NDK·그래들이 필요 없고 빌드는 20초 안팎입니다. 테스트·도구·웹 셸(`tests/*`, `tools/*`, `web/*`)은 제외합니다.
- 화면: 가로·세로 자동 회전(`window/handheld/orientation=4`), 몰입 모드(항상 전체화면), 진동 권한만 요청합니다.
- `project.godot`의 `textures/vram_compression/import_etc2_astc=true`는 안드로이드 내보내기에 필수입니다. 웹 빌드에는 영향이 없습니다.
- 안드로이드에서만 달라지는 곳: 설정의 전체화면 토글(항상 전체화면이라 비활성)과 "저장하고 선택 화면으로" 버튼(웹 전용이라 숨김).
  나머지 웹 전용 코드는 `OS.has_feature("web")`로 막혀 있습니다. 저장·설정은 `user://`에 저장됩니다.
- 용량: 디버그 약 57MB, 릴리스 약 56MB(네이티브 라이브러리 약 76MB를 압축한 값 포함).

## 릴리스 서명

릴리스 APK는 **본인의 키스토어**로 서명해야 하며 키스토어는 저장소에 넣지 않습니다. 같은 키로 서명해야 이후 업데이트가 덮어 설치됩니다.

```sh
keytool -genkey -v -keystore ~/sjrpg-release.jks -alias sjrpg -keyalg RSA -keysize 2048 -validity 10000
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=~/sjrpg-release.jks
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=sjrpg
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='...'
tools/export_android.sh --release
```

디버그 APK는 모든 개발자가 같은 디버그 키를 쓰므로 스토어에 올리면 안 됩니다. 플레이 스토어는 APK 대신 AAB를 요구하므로, 올리려면 `gradle_build/use_gradle_build=true`
(그래들 빌드, `android_source.zip` 템플릿과 NDK 필요)와 `gradle_build/export_format=1`로 바꿔 별도 설정해야 합니다.

## 알려진 한계

- **실제 기기·에뮬레이터에서 실행해 보지 못했습니다.** 빌드 환경에는 기기와 KVM이 없어, APK의 패키지 정보·서명·네이티브 라이브러리·리소스 포함 여부만 정적으로 검사했습니다.
  첫 실행에서 터치 조작, 화면 비율, 성능(3D 네이티브 장면), 음악·진동을 직접 확인해야 합니다.
- 런처 아이콘은 `web/install-192.png`입니다. 적응형(adaptive) 아이콘이 필요하면 프리셋의 `launcher_icons/adaptive_*`에 432×432 이미지를 지정합니다.
- 소리·진동 설정, 저장은 웹판과 같은 설정 화면을 씁니다. 안드로이드 뒤로가기 버튼 처리는 따로 하지 않았습니다.
- 현재 CI는 웹 빌드만 만듭니다. APK를 CI에서 만들려면 `setup_android.sh`와 `export_android.sh`를 워크플로에 추가하면 됩니다.
