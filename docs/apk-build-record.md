# APK 빌드 기록 형식

Dropbox의 해당 앱 폴더에 있는 `latest-build.json`을 다음 `versionCode`의 기준으로 읽습니다. 파일명은 `latest-build.json`이며 `lates-build.json`이 아닙니다. 다른 앱의 기록은 번호 기준으로 사용하지 않습니다.

## 빌드 전 번호 결정

1. Dropbox 플러그인의 `list_folder`와 `fetch` 또는 `download_link`로 해당 앱의 `latest-build.json` 및 전달 기록을 읽습니다. 플러그인이 반환한 원문을 로컬 JSON 파일로 저장합니다. 환경변수 토큰이나 직접 API로 가져오지 않습니다.
2. `versionCode`는 실제 전달 APK의 값입니다. `latest-build.json` 이후에 전달된 APK나 이미 존재하는 과거 JSON이 있으면 그 번호도 확인합니다. APK는 전달됐지만 기록 업로드가 실패한 경우도 포함합니다.
3. 다음 번호는 해당 앱의 `latest-build.json`, 확인된 후속 전달본, 현재 Android 프리셋의 `version/code` 중 최댓값에 1을 더합니다. 단순 재빌드도 기존 번호를 재사용하지 않습니다. 새 `buildNumber`와 `versionCode`는 그 번호이며 `versionName`은 `1.0.<번호>`입니다.
4. 기준 파일이 없거나 읽기에 실패했거나 실제 앱·설치본·기록이 모순되면 빌드 전에 멈추고 올바른 경로와 번호를 확인합니다. 누락을 최초 빌드로 간주해 1을 쓰거나 다른 앱의 번호를 가져오지 않습니다. 사용자가 최초 파일이 없음을 확인하고 현재 설치본의 `versionCode`를 명시한 경우에만, 그 번호와 해당 앱의 확인된 이전 전달 기록으로 로컬 초기 기준을 만듭니다. 이때 `versionBaseline`에 사용자 확인에 따른 초기화임을 기록하고, 다음 번호의 APK 전달 성공 후 최초 `latest-build.json`을 생성합니다.
5. `tools/prepare_apk_version.py`는 플러그인에서 읽어 저장한 로컬 기록만 받아 Android 프리셋의 버전을 갱신합니다. 업로드·토큰 처리·네트워크 요청은 하지 않습니다. 빌드 후에는 `aapt` 또는 `aapt2`로 실제 APK 버전이 결정한 번호와 정확히 일치하는지 확인합니다.

## JSON 필드

버전 관리 기록은 `latest-build.json` 한 개만 사용하고 아래 camelCase 필드명으로 작성합니다. APK와 같은 이름의 빌드별 JSON은 생성하거나 업로드하지 않습니다.

| 필드 | 형식과 의미 |
| --- | --- |
| `buildNumber` | 정수. 이번에 결정한 빌드 번호 |
| `versionName` | 문자열. APK에서 실제 확인한 버전 이름 |
| `versionCode` | 정수. APK에서 실제 확인한 버전 코드 |
| `commit` | 빌드한 소스의 전체 Git SHA |
| `sourceDirty` | 불리언. 빌드 당시 프리셋 버전 변경을 포함한 미커밋 변경 여부 |
| `fileName` | 실제 전달 APK 파일명 |
| `sha256` | 로컬 APK의 SHA-256 |
| `sizeBytes` | 로컬 APK 크기(바이트) |
| `signingCertificateSha256` | 실제 APK 서명 인증서의 SHA-256 지문 |
| `contentHash` | 로컬에서 계산한 Dropbox 방식 content hash |
| `builtAt` | 시간대가 포함된 ISO 8601 빌드 시각 |

`project`, `abi`, `validation`, `deviceTested`, `versionBaseline` 등 추가 필드는 사용할 수 있습니다. `contentHash`를 계산했다는 사실만으로 Dropbox 서버 해시까지 검증했다고 보고하지 않습니다. 예전 snake_case 빌드별 기록은 이력 확인용으로만 읽을 수 있으며 새 기록은 위 형식을 사용합니다.

APK 전달 성공 후 `latest-build.json`을 생성하거나 플러그인이 지원하는 방식으로 갱신합니다. 플러그인이 기존 파일 갱신을 지원하지 않으면 APK 전달 성공과 기록 갱신 미완료를 구분해 보고합니다. 직접 API·삭제 후 재생성·빌드별 JSON 추가로 우회하지 않습니다. 다음 번호 결정 시 기준 파일 이후 전달된 APK도 확인하여 중복 번호를 쓰지 않습니다.
