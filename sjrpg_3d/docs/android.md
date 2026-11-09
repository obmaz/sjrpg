# Android APK 내보내기

같은 `sjrpg_3d/` 프로젝트를 GL Compatibility로 내보냅니다. 패키지 ID는 `com.obmaz.sjrpg3d`, 앱 이름은 “자연의 수호자”, CPU는 `arm64-v8a`입니다. 기존 앱 저장 경로를 유지합니다.

## 로컬 빌드와 설치

APK는 사용자 명시 요청 시에만 빌드합니다. 푸시·PR·웹 배포로 자동 빌드하지 않으며 GitHub Actions 워크플로는 두지 않습니다.
저장소 루트에서 실행합니다. Linux와 JDK 17 이상이 필요합니다.

```sh
tools/setup_godot.sh
sjrpg_3d/tools/setup_android.sh
sjrpg_3d/tools/export_android.sh
adb install -r sjrpg_3d/build/android/sjrpg_3d-debug.apk
```

시험 설치용 디버그 APK이며 서명·16KiB ZIP 정렬·패키지·GPU 리소스를 검증합니다.

- 도구 버전은 `tools/android-toolchain.env`에 고정합니다. 현재 compile/target SDK 36, Build Tools 36.1.0이며 최소 Android API는 24입니다.
- Godot의 미리 빌드된 APK 템플릿을 사용하므로 현재 APK 경로에는 Gradle·NDK가 필요 없습니다.
- `ANDROID_HOME`은 SDK 경로, `JAVA_HOME`은 JDK 경로를 지정합니다. XDG 설정·데이터 경로도 지원합니다.
- 설치 도구는 공식 Godot 템플릿 ZIP에서 Android 파일만 범위 다운로드합니다. 버전·ZIP 엔트리 CRC·크기를 검증하고 개별 파일 SHA-256을 계산해 기록합니다. 전체 ZIP의 SHA-256을 검증했다는 뜻은 아닙니다.
- 디버그 키스토어는 기본 `~/.android/debug.keystore`에 생성합니다. `GODOT_ANDROID_KEYSTORE_DEBUG_PATH`로 기존 키를 사용할 수 있습니다. 키를 저장소에 넣지 않습니다.

`export_android.sh`는 서명·16KiB ZIP 정렬·arm64·패키지 ID·최소 SDK 24/target SDK 36·ETC2 리소스를 검사합니다. 이 검사는 Android 기기나 에뮬레이터에서 실행한 결과가 아닙니다.

## Dropbox 플러그인으로 전달

로컬 빌드 후 **ChatGPT에 연결된 Dropbox 플러그인으로만 업로드**합니다. 전체 절차는 [APK 전달 스킬](../../.agents/skills/dropbox-apk/SKILL.md)을 따릅니다. APK 빌드·업로드는 사용자 명시 요청 시에만 수행합니다.

- 기본 폴더는 `/앱/sjrpg`이며 APK 이름은 `sjrpg-<실제 versionName>-arm64-<빌드한 커밋의 짧은 SHA>.apk`입니다. 같은 이름의 `.json` 빌드 기록도 전달합니다. 사용자가 지정한 기본 설정이므로 같은 요청마다 목적지를 재확인하지 않습니다.
- `list_folder`로 폴더와 이름 충돌을 확인한 뒤 `upload_file`에 로컬 파일 절대 경로와 전체 Dropbox 목적지를 전달합니다. 비동기 업로드는 `check_upload_file_status`로 완료를 확인합니다.
- APK 전달 완료 후 실제 버전·커밋·크기·서명 지문·로컬 SHA-256·Dropbox 방식 content hash·검증 범위를 담은 JSON을 업로드합니다. 서버 해시를 받지 않았다면 서버 해시 검증을 주장하지 않습니다.
- 직접 API·환경변수 토큰·별도 업로드 스크립트로 우회하지 않습니다. 기존 `build_apk_dropbox.sh`, `upload_dropbox.py`, `dropbox_auth.py`는 이 전달 절차에서 사용하지 않습니다. 플러그인이 없으면 APK를 보존하고 연결이 필요함을 알립니다.
- 이름 충돌 시 덮어쓰기·삭제·다른 이름 재시도를 임의로 하지 않습니다. 공유 링크는 별도로 요청받았을 때만 만듭니다.
- 완료 응답의 실제 경로·크기를 확인합니다. APK와 JSON의 성공 여부를 구분하고 기기·에뮬레이터 실행 여부도 보고합니다.

## GPU 텍스처와 포함 리소스

[플랫폼별 텍스처 정책](platform-exports.md)의 불투명 표면 10개를 ETC2로 넣습니다. Android 패키지에는 해당 표면의 S3TC 복사본을 넣지 않습니다. UI·잎·유리·효과·배우 텍스처의 기존 설정과 원본 해상도는 유지합니다.

`tools/export_android.sh`는 정책 적용·Godot 임포트·내보내기 후 `zipalign`, `apksigner`, `aapt2`, 실제 APK 리소스 검사까지 수행합니다. 결과는 `build/android/export-report.json`, 패키지 정보는 `build/android/package.txt`입니다. 개발 도구·테스트·웹 셸·에셋 원본 보관 폴더는 앱에 넣지 않습니다.

화면 방향은 기본 자동 회전이며 설정에서 `자동 / 가로 / 세로`를 선택할 수 있습니다. 선택은 기기에 저장되어 다음 시작과 변경 즉시 적용됩니다. 설치 앱은 몰입 모드의 전체화면으로 시작합니다. 저장과 설정은 `user://`를 사용합니다. 실제 휴대폰에서 터치·화면 비율·음악·진동·장시간 메모리 안정성을 추가 확인해야 합니다.

## 릴리스 서명

본인 키스토어를 외부에 보관하고 환경 변수로 전달합니다. 기존 설치를 업데이트하려면 같은 서명 키를 유지해야 합니다.

```sh
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/secure/sjrpg-release.jks
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=sjrpg
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='본인 키 비밀번호'
sjrpg_3d/tools/export_android.sh --release
```

시험 설치용 디버그 APK는 로컬에서만 만듭니다. Google Play 제출용 AAB·Gradle 구성과 스토어 업로드는 별도 작업입니다.
