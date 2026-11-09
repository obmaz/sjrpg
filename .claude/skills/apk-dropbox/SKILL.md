---
name: apk-dropbox
description: sjrpg_3d의 Android 디버그 APK를 로컬에서 빌드해 Dropbox에 올립니다. 사용자가 APK 빌드·재빌드·APK 전달(Dropbox 업로드)을 명시적으로 요청했을 때만 사용합니다. 일반 개발·리뷰·푸시·웹 배포에는 쓰지 않습니다.
---

# APK 로컬 빌드 → Dropbox 업로드

GitHub Actions의 APK 워크플로는 제거했습니다. APK는 이 컨테이너(또는 개발 PC)에서 직접 빌드하고 Dropbox로 전달합니다.
**사용자가 APK 빌드를 명시적으로 요청했을 때만** 실행합니다. 검증을 이유로 자동 실행하지 않습니다.

## 실행

저장소 루트에서 한 번에 실행합니다. 첫 실행은 Godot·Android SDK·템플릿 다운로드와 전체 임포트 때문에 오래 걸립니다(빌드는 백그라운드로 실행하고 로그 파일을 확인).

```sh
sjrpg_3d/tools/build_apk_dropbox.sh --link
```

- `--skip-build`: 이미 만든 `sjrpg_3d/build/android/sjrpg_3d-debug.apk`를 다시 빌드하지 않고 업로드만 합니다.
- `--dest-dir /폴더`: Dropbox 폴더(기본 `/sjrpg`). 앱 폴더형 앱이면 앱 폴더 기준 경로입니다.
- `--link`: 공유 링크를 만들어 출력합니다(`sharing.write` 권한 필요, 실패해도 업로드는 유지).

단계별로 나누려면 `sjrpg_3d/tools/setup_android.sh` → `sjrpg_3d/tools/export_android.sh` → `python3 sjrpg_3d/tools/upload_dropbox.py <apk> --name <이름>`입니다.
파일명은 `sjrpg_3d-debug-<UTC날짜>-<커밋>.apk`(작업 트리가 더럽으면 `-dirty`)입니다.

## 자격 증명

환경 변수로만 받으며 저장소·로그·출력에 남기지 않습니다. 값을 `echo`/`env`로 출력하지 않습니다.

- `DROPBOX_APP_KEY`, `DROPBOX_APP_SECRET`, `DROPBOX_REFRESH_TOKEN` (권장: 짧은 액세스 토큰을 자동 갱신)
- 또는 일회성으로 `DROPBOX_ACCESS_TOKEN`
- 필요한 앱 권한: `files.content.write` (공유 링크는 `sharing.write`). 권한을 바꾼 뒤에는 리프레시 토큰을 다시 발급합니다.

`invalid_grant (refresh token is invalid or revoked)`이면 토큰이 잘못되었거나 폐기된 것입니다. 사용자에게 새 리프레시 토큰
(`token_access_type=offline`으로 인증한 값, 보통 64자 안팎)을 환경 변수로 다시 설정해 달라고 요청합니다. 다른 토큰을 찾아 쓰지 않습니다.

## 검증과 보고

- 빌드는 `export_android.sh`가 서명·16KiB ZIP 정렬·패키지·ETC2 리소스를 검사하고 `build/android/export-report.json`을 만듭니다.
- 업로드는 Dropbox가 돌려준 `content_hash`·크기를 로컬 파일과 비교해 일치할 때만 성공으로 처리합니다.
- 보고에는 APK 크기, 올라간 Dropbox 경로(공유 링크가 있으면 링크), 검증 결과를 적습니다. 기기·에뮬레이터 실행은 하지 않았으면 그렇게 밝힙니다.
- 빌드는 성공했는데 업로드만 실패한 경우, 실패 원인과 APK 위치(`sjrpg_3d/build/android/`)를 그대로 보고합니다.
