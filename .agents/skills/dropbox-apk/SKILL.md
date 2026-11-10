---
name: dropbox-apk
description: SJRPG 3D APK를 로컬에서 빌드하고 연결된 Dropbox 플러그인으로 /앱/sjrpg에 전달한다. APK 빌드 후 드롭박스 업로드 요청에 사용한다.
---

# SJRPG 3D APK → Dropbox

## 사용자가 지정한 기본 전달 설정

- 대상 프로젝트는 `obmaz/sjrpg`이다.
- 사용자의 “배포”는 Dropbox APK 전달을 뜻한다. 웹 배포는 별도로 명시할 때만 수행하며, 일반 푸시나 APK 전달로 GitHub Pages를 갱신하지 않는다.
- 기본 Dropbox 폴더는 `/앱/sjrpg`이다.
- APK 이름은 `sjrpg-<실제 versionName>.apk`로 한다.
- APK와 같은 폴더의 `latest-build.json`만 전달·갱신한다. 빌드별 JSON은 만들지 않는다.
- 사용자는 `latest-build.json` 교체 시 `/앱/sjrpg/latest-build.previous.json`으로 임시 이동 → 새 `latest-build.json` 업로드·재확인 → 임시 보관본 삭제, 실패 시 기존 기록 복구 절차를 이번과 이후 전달에도 명시적으로 승인했다. 이 정확한 경로와 절차의 승인을 반복해서 묻지 않는다. 기존 임시 보관본이 남아 있거나 다른 작업이 최신 기록을 변경했다면 먼저 상태를 확인한다.
- 사용자는 이 기본 경로·파일명 규칙·APK와 기록의 전달을 지정했다. 이후 APK 빌드 및 Dropbox 업로드 요청에서는 이 설정을 적용하고 경로 확인을 반복하지 않는다. 사용자가 다른 경로를 명시하면 그 요청을 따른다. 원본이나 목적지가 실제로 모호하거나 이름이 충돌하면 확인한다.
- Dropbox 플러그인만 사용한다. 직접 API·별도 업로드 스크립트·환경변수의 Dropbox 자격 증명으로 우회하지 않는다. 공유 링크는 요청받았을 때만 만든다. 플러그인을 사용할 수 없으면 APK를 보존하고 연결이 필요함을 알린다.

## 실행 조건

- APK 빌드·재빌드·Dropbox 업로드는 사용자가 명시적으로 요청했을 때만 수행한다. 일반 개발·리뷰·검증·푸시·웹 배포에 APK 빌드를 추가하지 않는다.
- 지침과 스킬은 한국어로 작성하며 명령어·경로·API 식별자는 원래 표기를 유지한다.

## 빌드 전 버전 번호 결정

- **빌드 전에** `/앱/sjrpg/latest-build.json`을 Dropbox 플러그인으로 읽는다. 이 파일의 `versionCode + 1`을 새 번호로 정한다. 후속 전달과 다르면 최신 기록부터 정정하고 빌드한다. 같은 소스의 재빌드도 이전 번호를 재사용하지 않는다.
- 기준 파일이 없거나 읽기 실패·앱 불일치·번호 모순이 있으면 빌드를 중단하고 올바른 기록 경로와 현재 번호를 확인한다. 임의로 1을 쓰거나 다른 앱의 기록으로 대체하지 않는다. 최초 파일이 없고 사용자가 현재 설치본 번호를 명시해 초기화를 승인한 경우에는 그 번호로 로컬 기준을 만든다. 초기 기준의 출처를 채팅에 기록하고 새 APK 전달 성공 후 공통 형식의 최초 `latest-build.json`을 생성한다.
- 플러그인으로 읽은 원문을 로컬 `build/reports/latest-build.json`에 저장한 뒤 아래 도구로 Android 프리셋을 갱신한다. 과거 전달 기록은 `--history <로컬 JSON 경로>`로 전달해 기준보다 높은 번호가 없는지 검사한다. 불일치 시 기준부터 정정한다. 기준 기록을 직접 API나 별도 인증 스크립트로 가져오지 않는다.

```sh
python3 tools/prepare_apk_version.py --project sjrpg \
  --latest build/reports/latest-build.json --preset sjrpg_3d/export_presets.cfg
```

- 출력된 `buildNumber`, `versionCode`, `versionName`을 기록하고 실제 빌드 결과와 대조한다. 프리셋 변경을 커밋하지 않았다면 전달 기록의 `sourceDirty`는 `true`로 남긴다.
- 계산 규칙과 새 JSON의 camelCase 필드 형식은 [APK 빌드 기록 형식](../../../docs/apk-build-record.md)을 따른다. 기존 snake_case 전달 기록은 이력 확인에만 사용한다.

## 로컬 빌드와 검증

1. `AGENTS.md`, 현재 브랜치와 작업 트리를 읽고 원격 HEAD를 확인한다. 동기화를 요청받지 않았다면 작업 트리를 임의로 변경하지 않는다.
2. [Android 안내](../../../sjrpg_3d/docs/android.md)와 [개발 안내](../../../docs/development.md)를 따른다. 기본 대상은 `sjrpg_3d/`이며 `sjrpg_2d/`는 수정하지 않는다. 엔진은 `.godot-version`에 고정한 Godot 4.7.2를 사용한다. 저장소 루트에서 `tools/setup_godot.sh`, `sjrpg_3d/tools/setup_android.sh`, `sjrpg_3d/tools/export_android.sh` 순서로 로컬 빌드한다. 기본은 `obmaz/commuzip`과 동일한 저장소의 공용 시험 키 `sjrpg_3d/tools/keys/debug-keystore.jks`를 사용하며 산출물은 `sjrpg_3d/build/android/sjrpg_3d-debug.apk`이다. 정식 배포용 서명은 명시적으로 요청받았을 때만 사용한다.
3. SDK·템플릿·Java 경로를 확인한다. `JAVA_HOME`은 실제 Java 설치 디렉터리를 가리켜야 한다. `XDG_CONFIG_HOME`을 사용한다면 빌드 도구가 저장한 설정을 엔진도 같은 위치에서 읽도록 맞춘다. Android 도구 버전은 `sjrpg_3d/tools/android-toolchain.env`를 따른다. `XDG_DATA_HOME`을 사용한다면 Android export template도 엔진이 읽는 위치에 있어야 한다.
4. 필요한 저장소 검사와 3D판 회귀 검사를 `tools/check.sh --project=3d`로 수행한다. 같은 소스에서 이미 통과한 검사는 반복하지 않는다. 검증 실패 시 전달하지 않는다.
5. 새 APK 생성과 빌드 성공을 확인한다. 실패한 빌드 대신 이전 산출물을 전달하지 않는다. `aapt2 dump badging`으로 실제 버전·패키지·arm64 ABI·권한을 확인하고 `apksigner verify --verbose --print-certs` 및 `zipalign -c -P 16 4`로 서명과 정렬을 확인한다. `export_android.sh`의 패키지·SDK·ETC2 리소스 검사 및 `export-report.json`도 확인한다. 기기에서 실행하지 않았다면 그 범위를 명시한다.
6. 실제 APK의 `versionCode`와 `versionName`이 빌드 전에 결정한 번호·이름과 정확히 일치하는지 확인한다. 일치하지 않으면 업로드하지 않는다. Flutter 전용 빌드 번호·서명·JNI 명령을 이 Godot 프로젝트에 적용하지 않는다.

## 업로드

1. 플러그인의 `list_folder`로 `/앱/sjrpg`의 존재와 이름 충돌을 확인하고 페이지가 남으면 이어 읽는다. 반환된 namespace 경로는 그대로 재사용한다.
2. APK의 로컬 SHA-256과 Dropbox content hash를 계산한다. JSON은 [APK 빌드 기록 형식](../../../docs/apk-build-record.md)의 camelCase 필드로 작성하고 실제 버전·빌드 번호·빌드한 커밋·미커밋 변경 여부·파일명·크기·서명 SHA-256 지문·로컬 해시를 공통 11개 필드로 기록한다. 검증 범위는 채팅에 보고한다. 스킬이나 문서만 나중에 커밋했다면 APK를 실제로 빌드한 SHA를 유지한다.
3. `upload_file`에 로컬 APK의 절대 경로를 `source_file`로, 기본 폴더와 규칙에 따른 전체 경로를 `destination_path`로 전달한다. `in_progress`이면 반환된 작업 ID와 권장 간격으로 `check_upload_file_status`를 사용한다. `completed`가 확인된 뒤 `latest-build.json`을 갱신한다.
4. APK 이름 충돌 시 임의로 재시도하지 않는다. 최신 기록 교체·실패 복구·성공 후 임시 기록 정리는 [공통 전달 절차](../../../docs/apk-build-record.md)를 따른다. 빌드별 JSON은 업로드하지 않는다.
5. 완료 응답의 실제 경로와 크기를 확인하고 보고한다. APK만 성공하고 JSON이 실패했다면 구분해 보고하고 APK를 다시 올리지 않는다. 서버 해시를 받지 않았다면 서버 해시 검증을 주장하지 않는다.
6. 빌드·전달 요청에 GitHub Actions, 공개 릴리스, 태그 또는 웹 배포를 추가하지 않는다.
