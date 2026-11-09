# 자연의 수호자

Godot **4.7.2**로 만드는 120° 직교 쿼터뷰 액션 RPG입니다.

[버전 선택](https://obmaz.github.io/sjrpg/) · [2D 모험](https://obmaz.github.io/sjrpg/2d/) · [3D 모험](https://obmaz.github.io/sjrpg/3d/)

| 폴더 | 역할 |
| --- | --- |
| `sjrpg_2d/` | 기존 Godot 프로젝트와 원화·문서·검사를 보존한 2D판 |
| `sjrpg_3d/` | 실제 3D 물리·지형·배우를 기준으로 전환하는 독립 프로젝트 |
| `web/` | 게임 다운로드 전에 보이는 버전 선택 화면 |
| `tools/` | 두 프로젝트의 검사·빌드·배포물 통합 |

3D판도 방위45°·고도35.264°의 직교 카메라를 유지합니다. 주요 건축·캐릭터·몬스터·나무는 입체 모델을 사용하며, 남은 원화 효과·표면은 개별 3D 평면으로 배치합니다. 전체 2D 화면을 3D 배경으로 붙이는 방식은 사용하지 않습니다. 진행·스킬·의뢰·UI는 기존 규칙을 재사용하며, 이동과 충돌·높낮이·공격 차폐는 `SpatialWorld3D`가 담당합니다. 전환 대상은 숲1장과 기존 선택형 동굴이며 후속 스테이지는 추가하지 않습니다.

두 프로젝트는 저장 경로를 분리해 서로 진행을 덮어쓰지 않습니다. 루트 주소에서는 항상 버전을 선택하며, 설정에서는 저장 후 버전 선택 화면으로 돌아갈 수 있습니다. 실행 중 렌더링 방식을 전환하지 않습니다. 이전 `/3d.html` 주소와 `?preview3d=1` 북마크는 `/3d/`로 이어집니다.

3D판은 네 개의 독립 저장 슬롯에서 모험을 만들고 이어 하거나 삭제할 수 있습니다. 설정 맨 위에서 전체화면을 켜고 끄며, 설치한 웹 앱은 지원되는 기기에서 전체화면으로 시작합니다. 자세한 조작과 현재 입체 자산은 [3D판 안내](sjrpg_3d/README.md)를 참고하세요.

```sh
tools/setup_env.sh                # 새 클론에서 한 번: Godot 설치 + 두 프로젝트 임포트 (--check: 상태만 확인)
tools/setup_env.sh --templates web  # 웹 빌드가 필요하면 export 템플릿도 설치
tools/check.sh                    # 두 프로젝트 전체 검사
tools/check.sh --project=3d       # 3D판 검사
tools/check.sh --export           # 검사 후 선택 화면 + 두 버전 웹 빌드
tools/serve.sh                    # http://localhost:8765/
```

Godot 에디터에서는 각 폴더의 `project.godot`를 별도로 엽니다. 자세한 구조는 [개발 안내](docs/development.md), 기존 기능과 아트 기준은 [2D판 문서](sjrpg_2d/README.md), 3D 전환 구조는 [3D판 문서](sjrpg_3d/README.md)를 참고하세요.

새 모델·재질은 [3D 에셋 제작 기준](docs/3d-asset-guide.md)의 실제 미터 배율·120° 직교 카메라·공유 재질·충돌·모바일 검수 규격을 따릅니다. 기존2D 제작 가이드는2D판에 보존합니다. 2D판의 기존3D 비교 코드는 분리 정리를 마쳤습니다. 이후2D판은 동결하고 기능·디자인 개선은3D판에서만 진행합니다.

3D 개발 문서는 [문서 목록](sjrpg_3d/docs/README.md)에서 찾습니다. 검수 캡처와 일회성 진단 출력은 `build/`와 Actions 아티팩트로 관리합니다.

Android 시험 APK는 `obmaz/commuzip`과 같은 공용 디버그 키를 사용합니다. 로컬 준비와 서명 설정은 [Android 안내](sjrpg_3d/docs/android.md)를 따릅니다.
