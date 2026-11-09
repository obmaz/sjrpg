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

## Dropbox 업로드

빌드한 APK를 Dropbox로 전달하려면 한 번에 실행합니다. 환경 변수 `DROPBOX_APP_KEY`, `DROPBOX_APP_SECRET`, `DROPBOX_REFRESH_TOKEN`(또는 일회성 `DROPBOX_ACCESS_TOKEN`)이 필요하며 빌드 전에 먼저 확인합니다. 값은 저장소·로그에 남기지 않습니다.

```sh
sjrpg_3d/tools/build_apk_dropbox.sh --link
```

- `sjrpg_3d/tools/upload_dropbox.py`가 리프레시 토큰으로 액세스 토큰을 갱신해 `/sjrpg/sjrpg_3d-debug-날짜-커밋.apk`로 올립니다(앱 폴더형 앱이면 앱 폴더 기준).
- 업로드 후 Dropbox의 `content_hash`·크기를 로컬 파일과 비교하며 일치할 때만 성공입니다.
- `--skip-build`는 이미 만든 APK만 올리고, `--dest-dir`로 폴더를 바꾸며, `--link`는 공유 링크(`sharing.write` 권한)를 출력합니다.
- 100MiB 대신 16MiB 이하만 단일 업로드하고 그 이상은 8MiB 청크로 나눕니다. 끊긴 연결은 최대 4번 재시도하고, 이미 저장된 청크는 Dropbox가 알려 주는 오프셋부터 이어 올립니다.

### 토큰 발급

Dropbox는 앱 소유자가 브라우저에서 승인해야만 리프레시 토큰을 발급하므로 AI 세션이 대신할 수 없습니다. 사람이 한 번만 실행합니다.

1. [App Console](https://www.dropbox.com/developers/apps)의 Permissions 탭에서 `files.content.write`(링크용 `sharing.write`)를 켜고 Submit합니다. 토큰은 승인 시점에 켜진 권한만 가지므로 권한을 먼저 켭니다.
2. 본인 터미널에서 `DROPBOX_APP_KEY=… DROPBOX_APP_SECRET=… python3 sjrpg_3d/tools/dropbox_auth.py`를 실행해 안내 URL에서 Allow를 누르고, 화면에 나온 코드를 붙여 넣으면 `DROPBOX_REFRESH_TOKEN` 값이 출력됩니다.
3. 그 값을 클라우드 환경 설정의 환경 변수 `DROPBOX_REFRESH_TOKEN`에 넣습니다. 저장소·채팅에 붙여 넣지 않습니다. 새 세션부터 적용됩니다.

콘솔의 "Generated access token"(`sl.`로 시작, 약 4시간 유효)은 리프레시 토큰이 아닙니다. 그 값이 `DROPBOX_REFRESH_TOKEN`에 들어 있으면 업로더가 경고하고 액세스 토큰으로 쓰지만 곧 만료됩니다.
`missing_scope … files.content.write`는 권한이 꺼진 상태에서 발급된 토큰이라는 뜻이므로 권한을 켠 뒤 토큰을 다시 발급합니다. `invalid_grant`는 토큰이 폐기·오류라는 뜻입니다.

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

현재 CI는 시험 설치용 디버그 APK를 만듭니다. Google Play 제출용 AAB·Gradle 구성과 스토어 업로드는 별도 작업입니다.
