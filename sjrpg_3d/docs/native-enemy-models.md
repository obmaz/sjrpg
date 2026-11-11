# 몬스터 모델과 애니메이션

몬스터 여섯 종류는 모두 **GLB + 종별 `visual.tscn`**을 사용합니다. GLB는 메시·UV·재질·골격·클립을 담고 씬은 모델·피격 피벗·효과 부착점을 조립합니다. AI·이동·충돌·피해·체력·저장·시체 수명은 기존 `Enemy`와 `SpatialWorld3D`가 소유합니다. 카메라는45°/35.2643897°의120° 직교 쿼터뷰입니다.

| 폴더 | 실제 원본·라이선스 | 삼각형 / 서피스 / 관절 / 최대 가중치 |
| --- | --- | --- |
| `goblin` | CDmir·TinyWorlds — Goblin, CC0-1.0 | 3,664 / 3 / 46 / 8 |
| `wolf` | CoinCoin — [Animated] Wolf, CC-BY-4.0 | 1,334 / 1 / 32 / 4 |
| `boar` | Teh_Bucket — Boar, CC0-1.0 | 4,768 / 2 / 25 / 8 |
| `skeleton` | KevDev — Skeleton Outlaw, CC0-1.0 | 5,516 / 2 / 56 / 4 |
| `golem` | Dm3d·hendori-sama·umask007 — Rock Golem, CC-BY-3.0 선택 | 3,368 / 1 / 41 / 4 |
| `cave_crawler` | City Building Game Art / HorrorGameMaker.com — 3D Horror Game Monster, CC0-1.0 | 3,584 / 1 / 58 / 8 |

폴더는 `assets/models/enemies/<kind>/` 아래에 있습니다. 모든 모델은 스킨 메시 하나와 idle/run/attack/hit/death 다섯 클립을 가집니다. 원본1024px 이하의 색 텍스처를 보존하며 스켈레톤과 잠복자의 주 텍스처만 원본2048px입니다. 임의 리사이즈하지 않습니다. 메시·클립은 공유하고 골격·플레이어·피격 재질은 인스턴스마다 분리합니다. 삼각형6,000 미만·서피스4 이하·관절64 이하의 제작 예산이며 실기기 FPS 보장은 아닙니다.

## 종별 변환

- 고블린은 원본의 실제 UV와 다중 가중치를 보존하고 짧은 칼·피격 키를 추가했습니다. 분리되는 원본 Neck 장식은 제외했습니다. 원본4가중치 제한의 최대 약30% 손실을 피하려고8가중치를 사용하며 최대 버림 비율은 약1.41%입니다.
- 늑대는 원본의 대기·이동·도약/물기·피격·사망 클립을 사용합니다.
- 멧돼지는 원본 Mirror와1단계 Catmull–Clark를 적용하고 시험 UV `projection-test` 대신 실제 `UVMap`을 사용합니다. 긴 주둥이를 포함한 AABB 중심 대신 네 발의 지지 중심에 발 원점을 둡니다. 원본 보행·공격을 보존하고 호흡·피격·쓰러짐을 추가했습니다. 원본 가중치를 단순히8개로 자르면 최대 약13%를 버리므로 `skin_weights.py`가 보행/공격34포즈의 LBS 정점 궤적에 비음수 가중치를 피팅합니다. 최대 샘플 오차는0.009422m이며 원본과 피팅 후 화면을 함께 검수합니다.
- 스켈레톤은 원본 idle/run/attack/damage/dead 동작을 사용하며 모발·금속 턱·어깨 갑옷·장화·안구 장식을 제외했습니다. 원본 뼈 발·뼈 턱·허리 장구·도끼는 남깁니다. 오래된 ASCII FBX는 잠근 FBX2glTF0.9.7로 읽고 각 클립의 실제 노드 변환을 같은 골격에 구웁니다.
- 골렘은 원본 Mirror와 idle/run/attack/hurt/death를 사용하고 별도 투척 돌은 가져오지 않습니다. 모델·UV·기존 표면/동작의 실제 저작자와 상류 출처를 함께 기록합니다.
- 동굴 잠복자는 원본 몸·피부·골격과 달리기를 사용합니다. 실제 미터 공간에서 굽힌 상체·대기 호흡·할퀴기/턱 닫기·피격·쓰러짐을 오프라인 키프레임으로 추가합니다. 소스의 Jaw 제어 뼈는 스킨에 직접 쓰이지 않아 내보낼 때 제거되며, 실제 가중치를 가진 `joint18`에 구워진 턱 동작을 검사합니다.

현재 몬스터의 런타임 절차형 생성기와 전용으로만 사용하던 털·뼈·흉터 타일은 제거했습니다. 일반 지형·건축·다른 배우의 제작 방식까지 바꾸지는 않습니다.

## 게임과 표시의 연결

`NativeEnemyModels`는 게임 상태를 읽는 표시 어댑터입니다. `NativeEnemyAssets`는 종별 `visual.tscn`을 캐시하며 `NativeEnemyVisual`이 GLB의 `AnimationPlayer`를 수동 시계로 샘플링합니다. `asset.json`은 실제 클립 이름·길이·타격 시각·높이·사망 접지·몸통 기준 뼈·공격 기준 뼈를 보관합니다. 존재하지 않는 제어 뼈 이름을 런타임 마커로 쓰지 않습니다.

기존 준비/회복 진행도0.60이 실제 피해 판정 시점입니다. 표시기는 클립별 `contact_time`을 이 시점에 맞추고 마지막에 같은 idle로 돌아갑니다. 보행은 원래 거리 주기를 따르며 root motion으로 물리를 이동시키지 않습니다. idle은 전달된 delta로 진행하고 일시정지·개별 hitstop 때 고정합니다. 화면 밖 모델은 포즈·색·그림자 갱신을 생략합니다. 피격은 씬의 `HitPivot` 전체에 적용하며 실제 캡슐·발 위치는 옮기지 않습니다.

마지막 death 스킨 자세를 실제 사망 위치 중심에 정렬하고 최저점을 오프라인에서 접지합니다. 시체는 그 자세를 고정하며 실제 바닥 위0.012m에 놓습니다. 바인드 AABB를 회전해 접지를 추측하지 않습니다. 기존0.18초 사망 페이드·30초 수명·소모·숲/동굴 소유권은 유지합니다.

`Enemy.NATIVE_HEIGHT_METRES`가 크기 기준이며 고블린/잠복자1.69m, 늑대1.469m, 멧돼지1.586m, 스켈레톤2.21m, 골렘3.705m입니다. +Y 위·+Z 정면·미터·발 원점·단위 배율로 내보냅니다. 높이는 제작/바인드 자세 기준이며 웅크림·도약 중에도 같은 높이라는 뜻은 아닙니다. 기존 이동/공격/투사체 캡슐은 몸통 중심을 담당하고 발끝·꼬리·주둥이·무기·장식을 각각 충돌체로 만들지 않습니다. 실제 몸통 중심·발 기준·벽 접근·공격 도달을 함께 검사합니다.

## 제작·원본·출처

`assets/source/enemies/<kind>/`에는 채택한 원본 바이트, 원문 페이지, 라이선스, 파일/런타임/변환기 해시, 변환 측정을 보존합니다. 원본 폴더는 배포물에서 제외하고 설정 ‘아트 출처’에 저작자·원본·라이선스 URL과 수정 표기를 표시합니다. 잠복자 배포 ZIP의 사용하지 않는 영상·다른 포즈는 보관하지 않고 실제 채택한 Idle/Run FBX·알베도·README 원본과 ZIP 해시/내부 경로를 보존합니다. 각 보조 입력도 해시로 잠급니다.

Blender4.3.2로 원본의 실제 월드 변화를 미터/FK 골격에 구워30fps 클립을 만듭니다. Mirror/표면 분할과 UV·스킨을 함께 처리하고 EditBone의 길이를 먼저 정한 뒤 행렬을 적용합니다. 역바인드·정점·관절 이동은 같은 변환을 쓰며 휴지 행렬 오차와 최종 LBS 접지, 가중치 손실/피팅 오차를 측정합니다. 원본 골격의 이름이나 배율이 같다고 가정하지 않습니다.

저장소 루트에서 실행합니다. Blender와 스켈레톤용 변환기를 설치한 뒤에는 재현 과정에 네트워크나 유료 서비스가 필요하지 않습니다.

```sh
python3 sjrpg_3d/tools/enemy_art/rebuild.py --kind boar
python3 sjrpg_3d/tools/enemy_art/rebuild.py --kind golem
python3 sjrpg_3d/tools/enemy_art/rebuild.py --kind cave_crawler
SJRPG_FBX2GLTF=/absolute/path/FBX2glTF python3 sjrpg_3d/tools/enemy_art/rebuild.py --kind skeleton
python3 sjrpg_3d/tools/check_enemy_assets.py
```

스켈레톤 변환기는 [FBX2glTF0.9.7 Linux x64](https://github.com/facebookincubator/FBX2glTF/releases/download/v0.9.7/FBX2glTF-linux-x64), SHA-256 `b38210352fdd29d50ba53a6514c3ff05ccbb5d1e0a6442db7a49834bf34a3145`입니다. 실행 전 원본 기록의 해시와 비교하며 도구 바이너리는 런타임이나 저장소에 넣지 않습니다. Blender4.3.2의 NumPy로 오프라인 스킨 피팅을 수행합니다.

고블린/늑대는 기존 `export_enemy.py`, 새 네 종류는 `export_remaining.py`와 `skin_weights.py`를 사용합니다. 멧돼지/잠복자의 형태·포즈 보정은 각 소스 폴더의 `authoring.py`에 분리하고 의존 해시로 기록합니다. Blender의 Python 오류는 재현 명령의 실패 종료 코드로 전달합니다. 새 모델을 다시 만들면 실제 변환/런타임 측정이 갱신되므로 원본 잠금은 유지하고 화면·접지·예산·라이선스를 재검수합니다. 기존 두 종의 임시 `model.bake.json`은 검수 후 소스의 `conversion.json`으로 정리하며 런타임 폴더에 남기지 않습니다.

## 검수와 협업

`native_enemy_assets`는 여섯 종의 실제 스킨 변형·소스 타격 시각·회복·접지·사망 위치·독립 골격/재질·공유 메시/클립을 검사합니다. `native_enemy_attack`은 실제 공격 기준 뼈의 준비/타격/복귀를, `native_enemy_models`는 입체·법선·조명·예산·페이드를 검사합니다. `native_enemy_recipe_cache`는 PackedScene/메시 공유·인스턴스 독립·시체 배치 캐시를, `native_enemy_scale`은 원래 게임의 높이·몸통 캡슐·공격·피격·지형을 검사합니다. `native_cave_crawler`는 실제 동굴 변종의 턱·전투·시체 소유권을 확인합니다.

다른 AI/제작자는 자기 종 폴더의 GLB·씬·manifest와 대응 소스만 교체합니다. 게임 코드의 종 등록과 전투 규칙은 통합 담당자가 다룹니다. 새 렌더 계약이나 클립 역할을 바꿀 때만 공용 표시기를 함께 수정합니다.

`tools/preview3d/render_enemy_pilot.tscn`은 종별 네 방향과 idle/run/attack/death를 같은 광원·직교 카메라로 촬영합니다. `--kinds=boar,skeleton,golem,cave_crawler --label=after`로 범위를 고를 수 있습니다. 실제 브라우저 가로/세로·타격·지역 전환도 확인하며 일회성 비교·측정은 루트 `build/`에 둡니다. 격리된 렌더나 헤드리스 검사만으로 스타일·실기기 성능이 승인됐다고 판단하지 않습니다.
