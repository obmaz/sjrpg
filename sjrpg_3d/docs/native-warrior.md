# 전사 모델

`assets/models/heroes/warrior/visual.tscn`은 스킨과 애니메이션이 있는 `model.glb`를 인스턴스화합니다. Quaternius FREE Standard의 성인 Ranger 의상·남성 얼굴·65관절 골격에 전용 철갑·손목 보호대·정강이 갑옷·짙은 녹색 망토·머리카락·검을 추가합니다. 상용 일러스트를 복제하지 않으며, 현재 전사 선택 일러스트의 재료와 색 계열을 참고합니다. 얼굴·눈·손가락의 원본 형상은 보존하고 의상만 오프라인 축약합니다.

## 운영 계약

- Y-up 미터, 정면+Z, 발 중앙 기준, 루트 배율1입니다. 몸체와 검은 각각 하나의 스킨 메시이며 재질별로 합쳐 작은 갑옷 부품마다 draw를 만들지 않습니다.
- 무기 조립은 실제 제작한 검 부품 목록을 추적하며 이름 접두사로 선택하지 않습니다. 허리띠는 몸체에 남고, 검의 모든 정점은 `hand_r`에 결합합니다. 사망 시 검을 숨겨도 갑옷과 허리띠는 유지합니다.
- `WarriorRenderer3D`는 마법사와 같은 `HeroAnimation3D`로 `idle`·`run`·`cast`를 수동 샘플링합니다. 실제 이동 거리128 지면 단위가 보행 한 주기이며 공격 진행도와 확인된 명중 시점이 검 모션을 결정합니다. 별도의 자동 애니메이션 시계나 루트 전진을 더하지 않습니다.
- 공격의 접촉 정지·일시정지와 실제 자세를 함께 멈춥니다. 피격 색은 모든 표면에 전달하고, 구르기는 표시 루트를 기울입니다. 사망은 실제 `death` 클립을 끝에서 유지하며 검을 숨깁니다.
- 체력·피해·충돌·발 높이·회전 방향은 기존 Player/SpatialWorld3D가 소유합니다. 모델에 AI나 충돌을 복제하지 않습니다.

현재 상한은24,000삼각형·2메시·12서피스입니다. 정확한 값과 각 클립의 CPU 변형 바운드/발 접지는 `asset.json`에 기록합니다. 이전의7,000삼각형 단순 피벗 모델 상한과 구별하며, 새 모델이 실제 기기의 성능을 보장한다고 간주하지 않습니다. 재질의 BaseColor는 최대1024px, 새 철·천·가죽·머리 재질은512px입니다. 새 법선·거칠기 맵을 만들었다고 주장하지 않습니다.

원본 의상의 밝은 녹색은 전사 전용 `T_Ranger_BaseColor`에만 실제 색으로 구워 낮춥니다. 얼굴·손·눈의 원본 색은 보존합니다. 공유 재질과 이미지는 각각 한 번만 변환하며 원본 파일명을 유지합니다. `source_source_`처럼 재처리 이름을 쌓거나 이전 추출 PNG를 함께 배포하지 않습니다.

현재 손·얼굴·눈썹/머리·눈의 색 텍스처4개는 상인 자산과 같은 픽셀이지만 별도 경로로 보존합니다. RGBA8과 전체 밉맵으로 환산하면 약16.3MiB의 중복 가능량이며 실기 GPU 메모리 측정값은 아닙니다. 공용 자산으로의 추출과 두 모델의 임포트 경로 정리는 후속 최적화 과제입니다.

두피 캡과 좌우 어깨·손목 갑옷은 제작할 때 실제 면 법선이 외측을 향하는지 검사합니다. 좌우 축을 뒤집을 때 winding도 반전하며, 양면 재질로 뒤집힌 면을 숨기지 않습니다. 검사한 면 수와 가장 작은 외측 법선 내적은 `asset.json`의 `authoredNormalAudit`에 남깁니다.

## 제작과 검수

```sh
SJRPG_CHARACTER_SOURCE_DIR=<로컬 캐시> python3 sjrpg_3d/tools/assets/heroes/fetch_sources.py
SJRPG_CHARACTER_SOURCE_DIR=<로컬 캐시> blender --background --factory-startup \
  --disable-autoexec --threads 2 --python sjrpg_3d/tools/assets/heroes/export_warrior.py
sjrpg_3d/tools/check.sh --only=native_warrior,native_hit_feel,hero_animation_3d
```

제작기는 기본적으로 루트 `build/warrior-redesign/candidate/`에 후보를 출력합니다. `assets/source/heroes/warrior/warrior.blend`에는 실제 메시·가중치·패킹한 색 텍스처·클립을 보존합니다. 원본 출처와 해시는 `tools/assets/heroes/source-provenance.json`, 패키지별 CC0 라이선스는 같은 전사 원본 폴더에 있습니다. 기존 생성형 표면 아틀라스는 [배우 재질](../assets/source/materials/actors/provenance.json), 디자인 참고는 `assets/source/entry-redesign/warrior.png`입니다.

편집 원본을 열면 프레임1의 `idle`만 표시합니다. 다른 세 NLA 트랙은 삭제하지 않고 음소거해 보존합니다. Blender에서 동작을 검토할 때에는 해당 트랙만 켜고, 납품 GLB의 네 독립 클립을 모두 다시 생성할 때에는 위 제작기를 사용합니다. 여러 트랙을 동시에 켜 혼합된 자세를 형상 기준으로 사용하지 않습니다.

`check_warrior_asset.py`는 실제 GLB의 스킨·클립·기하 예산·내장 이미지·제작 입력 지문과 오프라인 CPU 접지를 확인합니다. 내장 이미지9개와 실제 추출 PNG의 이름·해상도·색 픽셀도 대조합니다. `native_warrior`와 `native_hit_feel`은 실제 게임에서 이동 거리·공격·명중 정지·피격·사망·같은 배우의 복귀·일시정지의 뼈 자세를 확인합니다. 자동 검사로 외형 합격을 대신하지 않으며 실제 기본 시야의 가로·세로 게임 화면과 앞뒤·양옆을 별도로 검수합니다.
