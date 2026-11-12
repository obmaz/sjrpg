# 로컬 검증과 CI

푸시 전 로컬에서 검증하고, GitHub는 같은 명령을 깨끗한 환경에서 다시 확인합니다.
자동 워크플로는 `web.yml`의 **CI 한 개**입니다. `main` 푸시와 PR의 코드·도구 변경에 실행하며 문서만 바뀌면 실행하지 않습니다. 같은 브랜치의 새 커밋은 이전 검증을 취소합니다. 실패를 무시하거나 커밋 메시지로 검사를 건너뛰지 않습니다.

## 로컬 실행

처음 환경을 준비할 때:

```sh
tools/setup_env.sh --project=3d --templates web --npm
python3 -m pip install -r tools/requirements-ci.txt
```

푸시 전에 GitHub와 같은 명령을 실행합니다.

```sh
tools/ci.sh
```

워크플로 정책·검증 도구 회귀 검사·3D 자산 검증·전체 Godot 테스트·Web export를 순서대로 실행합니다. 실패하면 후속 빌드는 진행하지 않습니다. 결과는 `build/ci/web/3d/`에 모읍니다. 동결한2D판을 매 푸시마다 다시 검사·빌드하지 않습니다.

화면·입력·렌더링 변경은 관련 장면을 실제 브라우저에서 추가 확인합니다. 넓은 검수가 필요하면 같은 export로 여섯 검사를 순차 실행합니다.

```sh
npx playwright install chromium
tools/ci.sh --browser
# 이미 tools/ci.sh를 통과한 같은 소스의 export가 있으면 검사만 실행:
tools/check_browser_review.sh native
tools/check_browser_review.sh all
```

`native`는 예배당·동굴의 실제 세로→가로→세로 회전, 나머지는 저장·로딩·게임패드·음악·장비 화면입니다. `build/review/`에 결과를 남깁니다. 이 명령들은 GitHub 실행·푸시·공개 배포를 하지 않습니다.

## GitHub 실행 범위

| 작업 | 실행 조건 |
| --- | --- |
| 3D 전체 검사와 Web 빌드 | 코드 변경의 자동 CI |
| 실제 브라우저 검수6종 | `web.yml` 수동 실행에서 `browser_review=true`, 또는 명시적 웹 배포 |
| 후보 비교·메모리·사진·전투·텍스처 등 개별 진단 | 필요한 워크플로를 수동 실행 |
| 동결된2D와 선택 화면 포함 검사·조립 | 로컬 `tools/ci.sh --all-editions`, 또는 명시적 웹 배포 준비 |
| GitHub Pages 공개 배포 | 사용자의 요청 후 `web.yml`을 `publish=true`로 수동 실행 |

공개 웹 배포는 전체 조립·브라우저 검수가 성공하고 기존 `.native-style-review-hold`가 없을 때만 진행합니다. 일반 푸시는 공개 사이트와 Dropbox를 변경하지 않습니다.

전투 진단은 `tools/prepare_combat_review.py <일회용 체크아웃>`으로 로컬과 수동 CI에서 동일한 관찰기를 연결합니다. 운영 체크아웃에는 연결하지 않습니다. 모델 검사는 가져온 GLB 원본과 개별 `.tscn` 경로, 실제 스켈레톤·메시를 확인하고, 동굴 횃불은 각 지점의 물리 바닥에서부터 장착 높이를 확인합니다.

워크플로 변경은 `python3 tools/check_workflows.py`, `python3 tools/test_ci.py`와 `actionlint`로 검수합니다. 자동 이벤트를 가진 진단 워크플로가 다시 추가되면 공통 검사에서 실패합니다.
