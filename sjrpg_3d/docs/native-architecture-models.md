# 건물 GLB와 개별 씬

마을 주택 네 채·예배당·성곽/성문·다리는 `assets/models/architecture/<id>/`의 GLB와 `visual.tscn`을 사용합니다. 운영 중에는 이 자산을 인스턴스화하며, 메시 생성 코드는 앱에 넣지 않습니다. 나무·분수·바위 등 다른 소품의 제작 방식까지 변경한 것은 아닙니다.

| 자산 id | 내용 | 삼각형 | 재질 역할 |
| --- | --- | ---: | ---: |
| shop | 상점 | 11,420 | 6 |
| smith | 대장간 | 10,176 | 6 |
| stable | 마구간 | 7,700 | 6 |
| home | 주택 | 10,480 | 6 |
| chapel | 예배당 | 6,124 | 5 |
| fortress | 성벽·망루·성문 네 곳, 여덟 문짝 | 36,928 | 4 |
| bridge | 갑판·석조 아치·교각·난간 | 4,356 | 4 |

## 파일과 책임

- `model.glb`: 미터 단위 정점·법선·기존 UV·이름 있는 재질 슬롯·성문 피벗. 외부 모델 도구에서 열어 편집할 수 있습니다.
- `visual.tscn`: GLB의 인스턴스와 Godot 전용 재질을 연결합니다.
- `materials/*.tres`: 기존 생성형 벽/지붕과 공유 석재·참나무·철·유리의 실제 셰이더/텍스처 연결입니다. 이미지를 중복 복사하지 않습니다.
- `layout.tres`: 원본의 미터 경계·문/창·계단 측정, 노드 경로·재질 역할·동적 부품 표시입니다. 메시나 콜라이더를 포함하지 않습니다.
- `asset.json`: 표면 원화 계약과 모델·씬·배치 기록의 경로를 함께 지정합니다.

GLB의 `Material_<역할>`은 중립 PBR 슬롯입니다. Godot 전용 전체 면 투영·예배당 원화 보정·성벽 셰이더는 glTF 표준에 포함되지 않으므로 **게임 외형은 GLB와 씬을 함께 열어 확인**합니다. GLB 하나에 셰이더를 베이크했다고 주장하지 않습니다. 엔진 전용 표면을 유지하고 같은 이미지를 GLB에도 중복 저장하지 않기 위한 구성입니다.

`NativeArchitectureVisual`은 `@tool`로 Godot 에디터에서도 씬의 원래 재질을 연결합니다. `NativeArchitectureAssets`는 PackedScene을 캐시하고 `NativeArchitectureVisual`은 기록된 재질 슬롯과 노드를 연결합니다. 각 인스턴스의 노드는 분리하며 정적 메시와 재질은 공유합니다. 주택의 구조 재질은 기존 표시기의 공유 재질을 주입합니다. 오브젝트 가림 처리는 기존 루트 단위를 유지하고, 움직이는 문짝에는 `occlusion_dynamic`/`exclude_static_batch` 표시를 복원합니다.

`NativeHouse3D`, `Ortho3DChapel`, `NativeBridge3D`는 배치 어댑터입니다. `Ortho3DFortification`은 기존 `TownGateRuntime`의 닫힘/진행도와 동작 줄이기 설정을 여덟 문짝에 적용합니다. 새 트윈·독립 타이머·충돌체는 만들지 않습니다. 실제 계단/성문/다리 충돌은 `NativeChapelPlan`·`NativeFortressPlan`·`NativeBridgePlan`과 `SpatialWorld3D`가 소유합니다.

GLB 임포트는 `meshes/generate_lods=false`, `meshes/force_disable_compression=true`입니다. 기존 기와의 단/열 UV와 얇은 테두리 법선을 원래 정밀도로 보존합니다. 이 설정은 정점 데이터에만 적용하며 텍스처의 S3TC/ETC2 정책을 바꾸지 않습니다. 메시 수와 재질 구분은 유지하며 GLB 전환만으로 FPS가 개선됐다고 보장하지 않습니다.

## 재현과 자산별 작업

원래 제작 모델링 코드는 `tools/architecture_art/{house,chapel,fortress,bridge}_builder.gd`로 옮겼습니다. `bake.gd`는 운영 Game이나 기존 GLB를 열지 않고 원본 Village 데이터·공유 주택 규격으로 제작합니다. `NativeHousePlan`이 주택의 공통 수치와 재질 선택을 한 곳에 보관합니다.

```sh
# 저장소 루트에서 실행. --only를 생략하면 일곱 자산을 모두 재생성합니다.
sjrpg_3d/tools/godot.sh --headless res://tools/architecture_art/bake.tscn -- --only=shop
sjrpg_3d/tools/import_project.sh
python3 sjrpg_3d/tools/check_architecture_assets.py
sjrpg_3d/tools/check.sh --only=native_architecture_assets,native_house_family,ortho_3d_chapel,ortho_3d_fortification,wild_vegetation_bridge,village_structures,player_occlusion
```

실제 입력·도구·GLB/씬/재질/배치 해시는 `assets/source/architecture/<id>/model-provenance.json`에 있습니다. 기존 생성 원화와 원문 출처는 그대로 보존합니다. 원본 이미지를 편집하거나, 중립 슬롯을 완성된 PBR 재질로 표시하지 않습니다.

외부 제작자나 다른 AI는 **자기 자산 폴더와 대응 소스 기록**을 수정합니다. 기존 노드 이름·재질 역할·성문 피벗과 미터 단위를 보존하면 공용 게임 코드를 수정할 필요가 없습니다. 노드 구조를 바꿀 때는 같은 폴더의 `layout.tres` 경로와 측정도 갱신합니다. 새 GLB를 채택할 때 기존 생성기를 다시 실행해 외부 모델을 덮어쓰지 말고 새 제작 원본·도구·실측과 출력 해시를 기록합니다.

닫힌 문, 작업 홈, 계단 높이, 통로 폭, 성문 경첩 위치와 회전 방향은 기존 실제 충돌과 맞아야 합니다. 배율로 임의 보정하거나 충돌을 삭제하지 않습니다. 구조 변경은 공유 Plan과 실제 동선 검수를 함께 진행합니다. 같은 GLB를 두 작업자가 동시에 편집하지 않고 자산 단위로 담당을 나눕니다.

## 검수

`native_architecture_assets`는 실제 가져온 씬의 출처·독립 노드·공유 메시/재질·삼각형·시각/물리 분리를 확인합니다. 기존 주택 검사, 예배당, 성문 개폐, 다리와 가림 검사는 임포트된 실제 메시를 계속 측정합니다. `tools/check.sh`가 몬스터와 건물의 자산 해시/구조 검사도 실행합니다.

네 방향 건물 렌더는 `tools/preview3d/render_facades.tscn`을 사용합니다. 실제 모바일 가로/세로에서 마을·성문·다리를 확인하고 기존 화면과 같은 카메라·광원으로 비교합니다. 일회성 비교와 진단 출력은 `build/`에 둡니다. 실제 Android 기기 실행과 로컬 브라우저 검수는 구분합니다.

성곽은 2D 기준 원화(`assets/source/style/{wall-base-design,gate-wall-design}.png`)의 열린 원형 망루·양쪽 흉벽·목재 통로·외측 아치 음각을 따른다. 정적 재질은 5개에서4개로 줄이고, 열린 난간과 안쪽 흉벽을 추가한 기하 예산은38,000삼각형 미만이다. 그림과 충돌의 상부는 `NativeFortressPlan.crown_parts`를 공유한다. 실제 중앙 수직 광선이 지붕 없이 목재 바닥에 도달하며, 화살창·문짝·지상 통로 검사를 유지한다.
