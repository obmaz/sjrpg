# 고정 소품과 배우의 GLB·씬

몬스터는 [몬스터 계약](native-enemy-models.md), 건물·성곽·다리는 [건축 계약](native-architecture-models.md)을 따른다. 그 외 고정 자산의 진입점도 `assets/models/<family>/<id>/visual.tscn`이다.

| 자산 | 형상·씬 | 게임에서 유지하는 책임 |
| --- | --- | --- |
| 전사 | `heroes/warrior/{model.glb,visual.tscn}` | 성인 스킨·65관절·내장 클립. [전사 계약](native-warrior.md)의 실제 이동/명중 시계로 샘플링 |
| 마법사 | `heroes/mage/visual.tscn` → 보존된 CC0 GLB | 기존 골격·클립 수동 샘플링 |
| 주민8명 | `residents/<id>/visual.tscn` | Villager 발치·방향·대기·피격·의뢰·지역 수명 |
| 상자3종 | `environment/treasure_chest/visual.tscn` | 같은 메시와 목재/철/황금 재질, 내구도·전리품·힌지 열림 |
| 소환 비석 | `environment/encounter_stone/visual.tscn` | 충전·소환·표시 문구 |
| 분수·워프게이트 | `environment/{fountain,warp_gate}/visual.tscn` | 물·포털 셰이더, 원래 시계·입자·상호작용 |
| 웨이포인트 | `environment/waypoint/visual.tscn` | 발견 상태·인장 재질·네 모서리 불빛 |
| 동굴 입구 | `environment/cave_entrance/visual.tscn` | 공유 Plan의 배치·하강로, 동일 GLB 메시로 실제 SOLID 생성 |
| 나무5종·수풀2종 | `vegetation/<id>/visual.tscn` | 씬에서 공유 메시를 한 번 읽어 공간 청크 MultiMesh에 배치 |
| 동굴 표지·벽 횃불 | `environment/{trail_sign,wall_torch}/visual.tscn` | 안내 글자·방향, 실제 벽 접촉 배치·불꽃·광원·배칭 |

분수·워프게이트·마법사·상인·미라·참나무의 기존 GLB와 출처는 원래 경로에 보존한다. 씬이 원본을 직접 인스턴스화하므로 골격·동작·기존 제작기의 출력 경로를 중복하지 않는다. 나머지 고정 형상 제작기는 `tools/assets/props/`에만 있으며 앱에서 제외한다. 전사는 전용 Blender 제작기로 스킨과 클립을 굽고, 런타임은 플레이어 거리·명중 시계로 자세를 샘플링한다.

## 교체와 검증

개별 폴더의 `model.glb`, `visual.tscn`, `layout.tres`, `geometry.json`을 하나의 자산 단위로 관리한다. 미터/Y-up/+Z 전면/바닥 원점/단위 배율을 유지한다. `layout.tres`의 메시 경로·재질 슬롯·동적 배칭 제외 정보를 보존한다. 외부 Blender·AI 모델로 교체할 때는 `geometry.json`의 입력을 실제 원본·제작 도구의 출처로 바꾸고 새 GLB의 바운드·삼각형·해시를 측정한다. 기존 제작기로 만들지 않은 모델에 과거 제작 해시를 복사하지 않는다.

전사와 상자처럼 움직이는 부품은 합치지 않는다. 물리·AI·보상 코드를 자산 씬에 복사하지 않는다.

기존 기하를 재현하려면 저장소 루트에서 실행한다.

```sh
sjrpg_3d/tools/godot.sh --headless res://tools/assets/props/bake.tscn
sjrpg_3d/tools/godot.sh --headless res://tools/assets/props/bake.tscn -- --only=environment/waypoint
sjrpg_3d/tools/check.sh --only=native_prop_assets,native_warrior,native_residents,native_encounter_props
```

모델을 새로 생성한 최초에는 에디터 임포트 후 자동 LOD를 끄고 정점 압축을 해제한다. 기존 자산 재생성에서는 제작기가 이 설정을 보존한다. `check_prop_assets.py`는 실제 파일·제작 입력 해시·GLB 구조·삼각형 수·임포트 설정을 검사하고 `native_prop_assets`는 임포트 후 원본 바운드·서피스·공유 메시·독립 피벗·물리 분리를 검사한다. 기존 플레이 검사는 상자·전사·주민·동굴 충돌·워프 상태를 계속 검사한다. 가로·세로 실제 렌더도 확인한다.

지형 바닥·높이별 동굴 벽·통로 폭에 맞추는 아치와 바위·하천 경계는 월드 Plan에서 생성한다. 작은 풀잎 배칭과 물·불꽃·마법 효과도 코드/셰이더를 유지한다. 고정 모델로 바꾸면 지형 연결과 충돌 규격을 잃거나 변형용 변종이 늘어나는 부분까지 GLB로 강제하지 않는다. GLB 전환 자체가 삼각형·드로 호출·GPU 비용을 줄였다는 뜻은 아니다.
