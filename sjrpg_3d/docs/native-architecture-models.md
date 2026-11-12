# 건물 GLB와 개별 씬

마을 주택 네 채·전용 상점/대장간·예배당·성곽/성문·다리는 `assets/models/architecture/<id>/`의 GLB와 `visual.tscn`을 사용합니다. 운영 중에는 이 자산을 인스턴스화하며, 메시 생성 코드는 앱에 넣지 않습니다. 나무·분수·바위 등 다른 소품의 제작 방식까지 변경한 것은 아닙니다.

| 자산 id | 내용 | 삼각형 | 재질 역할 |
| --- | --- | ---: | ---: |
| shop | 보존한 기존 상점 주택 | 11,008 | 6 |
| smith | 보존한 기존 대장간 주택 | 10,476 | 6 |
| stable | 마구간 | 8,008 | 6 |
| home | 주택 | 10,492 | 6 |
| chapel | 예배당 | 6,284 | 5 |
| fortress | 성벽·망루·성문 네 곳, 여덟 문짝 | 37,472 | 4 |
| bridge | 갑판·석조 아치·교각·난간 | 4,356 | 4 |
| market_shop | C 원화 전용 상점: 천막·진열 상품·간판 | 19,764 | 7 |
| open_smithy | C 원화 전용 대장간: 열린 작업장·화덕·모루 | 9,980 | 7 |

## 파일과 책임

- `model.glb`: 미터 단위 정점·법선·기존 UV·이름 있는 재질 슬롯·성문 피벗. 외부 모델 도구에서 열어 편집할 수 있습니다.
- `visual.tscn`: GLB의 인스턴스와 Godot 전용 재질을 연결합니다.
- `materials/*.tres`: 기존 생성형 벽/지붕과 공유 석재·참나무·철·유리의 실제 셰이더/텍스처 연결입니다. 이미지를 중복 복사하지 않습니다.
- `layout.tres`: 원본의 미터 경계·문/창·계단 측정, 노드 경로·재질 역할·동적 부품 표시입니다. 메시나 콜라이더를 포함하지 않습니다.
- `asset.json`: 표면 원화 계약과 모델·씬·배치 기록의 경로를 함께 지정합니다.

GLB의 `Material_<역할>`은 중립 PBR 슬롯입니다. Godot 전용 전체 면 투영·예배당 원화 보정·성벽 셰이더는 glTF 표준에 포함되지 않으므로 **게임 외형은 GLB와 씬을 함께 열어 확인**합니다. GLB 하나에 셰이더를 베이크했다고 주장하지 않습니다. 엔진 전용 표면을 유지하고 같은 이미지를 GLB에도 중복 저장하지 않기 위한 구성입니다.

`NativeArchitectureVisual`은 `@tool`로 Godot 에디터에서도 씬의 원래 재질을 연결합니다. `ArchitectureSceneLibrary`는 PackedScene을 캐시하고 `NativeArchitectureVisual`은 기록된 재질 슬롯과 노드를 연결합니다. 각 인스턴스의 노드는 분리하며 정적 메시와 재질은 공유합니다. 주택의 구조 재질은 기존 표시기의 공유 재질을 주입합니다. 오브젝트 가림 처리는 기존 루트 단위를 유지하고, 움직이는 문짝에는 `occlusion_dynamic`/`exclude_static_batch` 표시를 복원합니다.

`HouseRenderer3D`, `ChapelRenderer3D`, `BridgeRenderer3D`는 배치 어댑터입니다. `FortificationRenderer3D`은 기존 `TownGateRuntime`의 닫힘/진행도와 동작 줄이기 설정을 여덟 문짝에 적용합니다. 새 트윈·독립 타이머·충돌체는 만들지 않습니다. 실제 계단/성문/다리 충돌은 `ChapelPlan3D`·`FortressPlan3D`·`BridgePlan3D`과 `SpatialWorld3D`가 소유합니다.

GLB 임포트는 `meshes/generate_lods=false`, `meshes/force_disable_compression=true`입니다. 기존 기와의 단/열 UV와 얇은 테두리 법선을 원래 정밀도로 보존합니다. 이 설정은 정점 데이터에만 적용하며 텍스처의 S3TC/ETC2 정책을 바꾸지 않습니다. 메시 수와 재질 구분은 유지하며 GLB 전환만으로 FPS가 개선됐다고 보장하지 않습니다.

## 재현과 자산별 작업

원래 제작 모델링 코드는 `tools/assets/architecture/{house,chapel,fortress,bridge}_builder.gd`로 옮겼습니다. `bake.gd`는 운영 Game이나 기존 GLB를 열지 않고 원본 Village 데이터·공유 주택 규격으로 제작합니다. `NativeHousePlan`이 주택의 공통 수치와 재질 선택을 한 곳에 보관합니다.

`tools/assets/architecture/medieval_details.gd`는 마을 전체의 작은 세공을 공유하는 오프라인 도구입니다. 주택은 각 창을 실제로 덮을 수 있는 폭의 판자 덧문, 처마를 받치는 사선 버팀, 끝을 벼린 문 철띠, 직업별 길드 방패와 작은 등기구를 갖습니다. 상점 모서리의 상층 덧문은 경첩 각도를 주어 골조와 겹치지 않게 접어 엽니다. 예배당의 입구 등기구와 성문 탑의 숲 문장이 같은 세공 패밀리로 마을을 연결합니다. 벽돌·슬레이트·골조의 실제 UV는 유지하고, 참나무는 공통 풍화색을 사용합니다. 성곽의 목재는 같은 바탕에서 노출에 따른 차가운 풍화색만 더합니다.

세공 부품은 기존 불투명 재질 표면에 합칩니다. 부품마다 런타임 노드·투명 그림·동적 광원·새 텍스처를 추가하지 않습니다. 문장과 등기구는 기존 건물/탑에 붙는 장식이며 지상 통로나 충돌을 바꾸지 않습니다. 외부 제작자는 이 helper를 런타임에 연결하지 않고 개별 GLB를 편집해도 됩니다.

```sh
# 저장소 루트에서 실행. --only를 생략하면 일곱 자산을 모두 재생성합니다.
sjrpg_3d/tools/godot.sh --headless res://tools/assets/architecture/bake.tscn -- --only=shop
sjrpg_3d/tools/import_project.sh
python3 sjrpg_3d/tools/check_architecture_assets.py
sjrpg_3d/tools/check.sh --only=native_architecture_assets,native_house_family,medieval_craft_family,ortho_3d_chapel,ortho_3d_fortification,wild_vegetation_bridge,village_structures,player_occlusion
```

실제 입력·도구·GLB/씬/재질/배치 해시는 `assets/source/architecture/<id>/model-provenance.json`에 있습니다. 기존 생성 원화와 원문 출처는 그대로 보존합니다. 원본 이미지를 편집하거나, 중립 슬롯을 완성된 PBR 재질로 표시하지 않습니다.

외부 제작자나 다른 AI는 **자기 자산 폴더와 대응 소스 기록**을 수정합니다. 기존 노드 이름·재질 역할·성문 피벗과 미터 단위를 보존하면 공용 게임 코드를 수정할 필요가 없습니다. 노드 구조를 바꿀 때는 같은 폴더의 `layout.tres` 경로와 측정도 갱신합니다. 새 GLB를 채택할 때 기존 생성기를 다시 실행해 외부 모델을 덮어쓰지 말고 새 제작 원본·도구·실측과 출력 해시를 기록합니다.

닫힌 문, 작업 홈, 계단 높이, 통로 폭, 성문 경첩 위치와 회전 방향은 기존 실제 충돌과 맞아야 합니다. 배율로 임의 보정하거나 충돌을 삭제하지 않습니다. 구조 변경은 공유 Plan과 실제 동선 검수를 함께 진행합니다. 같은 GLB를 두 작업자가 동시에 편집하지 않고 자산 단위로 담당을 나눕니다.

## 검수

`native_architecture_assets`는 실제 가져온 씬의 출처·독립 노드·공유 메시/재질·삼각형·시각/물리 분리를 확인합니다. 기존 주택 검사, 예배당, 성문 개폐, 다리와 가림 검사는 임포트된 실제 메시를 계속 측정합니다. `tools/check.sh`가 몬스터와 건물의 자산 해시/구조 검사도 실행합니다.

`medieval_craft_family`는 GLB에 가져온 덧문 각 판자의 실제 표면을 광선으로 확인하며 폭·경첩 좌표·기존 메시 수를 함께 검사합니다. 성문 탑의 문장도 실제 석조와 함께 광선을 쏴 탑 뒤에 묻히지 않는지 확인합니다. 기록된 장식 개수만으로 시각 검수를 대신하지 않습니다.

네 방향 건물 렌더는 `tools/review/models/render_facades.tscn`을 사용합니다. 실제 모바일 가로/세로에서 마을·성문·다리를 확인하고 기존 화면과 같은 카메라·광원으로 비교합니다. 일회성 비교와 진단 출력은 `build/`에 둡니다. 실제 Android 기기 실행과 로컬 브라우저 검수는 구분합니다.

성곽은 2D 기준 원화(`assets/source/style/{wall-base-design,gate-wall-design}.png`)의 열린 원형 망루·양쪽 흉벽·목재 통로·외측 아치 음각을 따른다. 정적 재질은 5개에서4개로 줄이고, 열린 난간과 안쪽 흉벽을 추가한 기하 예산은38,000삼각형 미만이다. 그림과 충돌의 상부는 `FortressPlan3D.crown_parts`를 공유한다. 실제 중앙 수직 광선이 지붕 없이 목재 바닥에 도달하며, 화살창·문짝·지상 통로 검사를 유지한다.

## 전용 시설과 광장

`market_shop`·`open_smithy`는 사용자가 선택하고 보강 원화를 승인한 C안의 추가 건물입니다. 기존 `shop`·`smith`의 GLB·씬·재질은 보존합니다. 승인 컨셉과 실제 재생성 입력·프롬프트·해시는 `assets/source/architecture/trade_workshops/`에, 상품/천막/화덕의 생성형4×4 알베도는 `assets/materials/trade_workshops/`에 둡니다. 일반 벽·기와·목재는 기존 마을 패밀리를 재사용하고, 진열 상품과 아궁이/후드/모루는 실제 기하입니다. 알베도의 미세 명암은 회화 표현이며 스캔 PBR이나 법선 맵으로 주장하지 않습니다.

상점은 많은 병·빵·과일·천과 장식 때문에 일반 주택의12,000삼각형 목표를 넘는19,764삼각형 예외입니다. 두 시설은 각7개 공유 재질 역할로 묶이며 상품마다 런타임 노드/광원을 추가하지 않습니다. 화덕은 같은 알베도의 잔불 셀을 발광으로 쓰고 새 동적 광원은 만들지 않습니다. FPS 개선은 이 수치만으로 보장하지 않습니다.

`TownPlazaPlan3D`는 미터 단위 광장(14.4×14.5m), 기존 주택/새 시설의 중심·Y 회전·충돌 부품·기둥·NPC 접근점을 소유합니다. 북서·북동·남서 집의 +90° 포즈는 실제 GLB·SOLID·주민·마당·지도에서 공유하며 로컬 +Z 정면이 월드 +X를 향합니다. 문 접근과 마당 판석도 GLB의 로컬 `door_approach`에서 같은 변환으로 옮깁니다. `Village`는 원본 JSON을 보존하면서 주택 위치·방향을 조정하고, 새 시설은 `WorldRenderer3D`가 개별 씬으로 배치합니다. `SpatialWorld3D`는 같은 부품과16cm 기단을 물리에 사용합니다. 열린 대장간 전체를 닫힌 사각형으로 막지 않습니다. 두 지도도 같은 배치와 실제 정적 루트 변환을 읽습니다. 기존 성벽 안에서 충분한 공간을 확보하므로 성벽 크기는 유지합니다. 마을 안전 경계도 성벽 안쪽으로 맞춰 가장자리로 옮긴 주민들이 필드로 판정되지 않게 합니다.

```sh
# 기존 모델을 덮어쓰지 않고 새 시설 두 채만 재현
sjrpg_3d/tools/godot.sh --headless res://tools/assets/architecture/bake_trade_buildings.tscn
sjrpg_3d/tools/import_project.sh
# 실제 운영 광원/직교 카메라로 두 시설의 네 방향 렌더
sjrpg_3d/tools/godot.sh --audio-driver Dummy res://tools/review/models/render_facades.tscn -- --trade --after --no-layouts
```

`town_plaza`는 주택/광장 분리, 시설 NPC·실제 충돌·접근 공간·GLB·기하 예산·지도 도형을 검증합니다. `npc_clearance`는 실제3D 충돌 광선과 GLB 문 앞 위치를 사용하고, `tree_art`의 주민 검사는 전용 시설을 읽습니다. 숨겨진2D 건물 그림의 옛 배치/정렬을 새 마을에 강제하지 않습니다. 재생성할 때 공유 Plan과 모델을 함께 검수하며 기존7개 모델의 입력 호환 기록은 배치만 바뀌었고 GLB/씬/재질 바이트는 같다는 사실을 명시합니다.
