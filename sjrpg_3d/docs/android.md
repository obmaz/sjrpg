# Android APK 내보내기

같은 `sjrpg_3d/` 프로젝트를 GL Compatibility로 내보냅니다. 패키지 ID는 `com.obmaz.sjrpg3d`, 앱 이름은 “자연의 수호자”, CPU는 `arm64-v8a`입니다. 기존 앱 저장 경로를 유지합니다.

## 빌드와 설치

저장소 루트에서 실행합니다. Linux와 JDK 17 이상이 필요합니다.

```sh
tools/setup_godot.sh
sjrpg_3d/tools/setup_android.sh
sjrpg_3d/tools/export_android.sh
adb install -r sjrpg_3d/build/android/sjrpg_3d-debug.apk
```

- 도구 버전은 `tools/android-toolchain.env`에 고정합니다. 현재 compile/target SDK 36, Build Tools 36.1.0이며 최소 Android API는 24입니다.
- Godot의 미리 빌드된 APK 템플릿을 사용하므로 현재 APK 경로에는 Gradle·NDK가 필요 없습니다.
- `ANDROID_HOME`은 SDK 경로, `JAVA_HOME`은 JDK 경로를 지정합니다. XDG 설정·데이터 경로도 지원합니다.
- 설치 도구는 공식 Godot 템플릿 ZIP에서 Android 파일만 범위 다운로드합니다. 버전·ZIP 엔트리 CRC·크기를 검증하고 개별 파일 SHA-256을 계산해 기록합니다. 전체 ZIP의 SHA-256을 검증했다는 뜻은 아닙니다.
- 디버그 키스토어는 기본 `~/.android/debug.keystore`에 생성합니다. `GODOT_ANDROID_KEYSTORE_DEBUG_PATH`로 기존 키를 사용할 수 있습니다. 키를 저장소에 넣지 않습니다.

`Build Android APK` Actions가 같은 명령으로 APK를 만들고 다운로드 가능한 아티팩트를 보관합니다. [검증된 빌드](https://github.com/obmaz/sjrpg/actions/runs/42474336402)는 61,677,523바이트이며, 서명·16KiB ZIP 정렬·arm64·패키지 ID·최소 SDK 24/target SDK 36·ETC2 리소스를 통과했습니다. Android 기기나 에뮬레이터에서 실행한 결과는 아닙니다.

## GPU 텍스처와 포함 리소스

[플랫폼별 텍스처 정책](platform-exports.md)의 불투명 표면 10개를 ETC2로 넣습니다. Android 패키지에는 해당 표면의 S3TC 복사본을 넣지 않습니다. UI·잎·유리·효과·배우 텍스처의 기존 설정과 원본 해상도는 유지합니다.

`tools/export_android.sh`는 정책 적용·Godot 임포트·내보내기 후 `zipalign`, `apksigner`, `aapt2`, 실제 APK 리소스 검사까지 수행합니다. 결과는 `build/android/export-report.json`, 패키지 정보는 `build/android/package.txt`입니다. 개발 도구·테스트·웹 셸·에셋 원본 보관 폴더는 앱에 넣지 않습니다.

화면은 자동 회전·몰입 모드이며 설치 앱은 전체화면으로 시작합니다. 저장과 설정은 `user://`를 사용합니다. 실제 휴대폰에서 터치·화면 비율·음악·진동·장시간 메모리 안정성을 추가 확인해야 합니다.

## 릴리스 서명

본인 키스토어를 외부에 보관하고 환경 변수로 전달합니다. 기존 설치를 업데이트하려면 같은 서명 키를 유지해야 합니다.

```sh
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/secure/sjrpg-release.jks
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=sjrpg
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='본인 키 비밀번호'
sjrpg_3d/tools/export_android.sh --release
```

현재 CI는 시험 설치용 디버그 APK를 만듭니다. Google Play 제출용 AAB·Gradle 구성과 스토어 업로드는 별도 작업입니다.
