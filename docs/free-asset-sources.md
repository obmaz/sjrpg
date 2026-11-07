# 검증 가능한 무료 3D 에셋 재사용

검토일: 2026-11-07. 범위는 독립 3D판의 기존 숲 1장·선택형 동굴입니다. 사용자의 무료 프리 에셋 활용 허용은 품질 검수 없는 일괄 교체 지시가 아닙니다. 현재 승인된 모델·충돌·진행을 유지하고, 실제로 더 나은 후보부터 비교합니다.

## 우선 결정

사람형 NPC/전사의 다음 재사용 출발점은 **현재 마법사와 같은 Quaternius 성인형 가족의 이미 확보·기록된 FREE Standard 파일**입니다. 현재 마법사도 이미 무료 에셋을 쓰고 있습니다. KayKit의 큰 머리·짧은 팔다리나 Kenney의 단순한 건물을 이름값만 보고 기존 회화풍 세계에 섞지 않습니다. 이들의 CC0 허용 여부와 우리 게임의 스타일 적합 여부는 별개의 판단입니다.

새 다운로드 모델은 아직 이 문서로 채택·배포되지 않았습니다. 아래의 바이트/해시 정보는 기존 저장소의 취득 기록이며, 이번 조사에서 새 ZIP을 내려받아 검사했다고 주장하지 않습니다. 후보 상태는 공식 원문·공식 GitHub·기존 취득 증거 확인 단계이며, 신규 ZIP 내부 검사와 실제 모델 검수를 마친 자산부터 채택합니다.

## 현재 마법사의 실제 출처와 확보 증거

저작자: **Quaternius**. 보존된 각 팩 라이선스는 **CC0 1.0 Universal**입니다. 실제 원문과 SHA-256은 [CC0_SOURCES.txt](../sjrpg_3d/tools/hero_art/CC0_SOURCES.txt), 파일별 바이트/해시는 [source-provenance.json](../sjrpg_3d/tools/hero_art/source-provenance.json)에 있습니다.

| 기존 FREE Standard 팩 | 공식 원문/다운로드 진입점 | 기존 취득 upload ID | 라이선스 파일 SHA-256 |
| --- | --- | --- | --- |
| Modular Character Outfits — Fantasy | https://quaternius.com/packs/modularcharacteroutfitsfantasy.html | 16289385 | 2202cc2f608c4210790b112e5f121bc2e7f8dced7b5b1c7f4be6203461bdebbb |
| Universal Base Characters | https://quaternius.com/packs/universalbasecharacters.html | 15861669 | 0f4beaf0fe360a7732e58bbe3dbf60a2422367fbea60cb9ea4add968f383268e |
| Universal Animation Library | https://quaternius.com/packs/universalanimationlibrary.html | 17958403 | 6d01f55c6e4c49a2c9963e147e561945ae2c83958c8ca667d90a6bffdbfac061 |
| Universal Animation Library 2 | https://quaternius.com/packs/universalanimationlibrary2.html | 17958478 | 6d01f55c6e4c49a2c9963e147e561945ae2c83958c8ca667d90a6bffdbfac061 |

보존 원문의 라이선스 표기는 “CC0 1.0 Universal (CC0 1.0) / Public Domain Dedication”입니다. [CC0 법률 원문](https://creativecommons.org/publicdomain/zero/1.0/legalcode.en)의 포기·대체 허락에 따라 수정·게임 이용이 가능하며, 저작자/취득/수정 기록은 프로젝트에 계속 보존합니다.

현재 마법사는 Male_Peasant의 발·다리, Male_Ranger의 옷/팔/후드, Universal Base의 머리·눈과 UAL 동작을 조합하고 원래의 지팡이·로브를 추가했습니다. 배포물의 실제 65관절·idle/run/cast·포함 메시/재질 기록은 [mage-manifest.json](../sjrpg_3d/assets/art/preview3d/mage-manifest.json)에 있습니다. 기존 바인딩·root transform을 새 모델에 추측으로 복사하지 않습니다.

## 라이선스가 바뀐 신규 팩을 CC0로 잘못 분류하지 않기

[현재 Quaternius Asset License(QAL) 원문](https://quaternius.com/license.html)은 2026-08-28 갱신본입니다. 완성 게임의 이용·수정·상업적 배포는 허용하지만, §3은 원본/수정 에셋 자체를 에셋·팩·템플릿 등으로 재배포하는 것을 제한합니다. §7은 이미 취득한 이전 버전 라이선스에 소급하지 않는다고 명시합니다.

따라서 일부 오래된 소개 페이지에 CC0 배지가 남아 있어도 새 ZIP의 실제 License 파일을 읽어야 합니다. 기존의 해시 고정 CC0 파일을 새 QAL 파일로 자동 갱신하지 않습니다. 공개 저장소의 원본/수정 GLB 보존까지 적합한지 확인하지 않은 QAL 팩은 이 저장소에 추가하지 않습니다. 이 조건은 무료 다운로드 가능 여부와 다릅니다.

특히 [Bestiary — Dungeon Monsters Kit](https://quaternius.itch.io/bestiary-dungeon-monsters-kit)는 현재 공식 페이지에서 **QAL**을 명시하고, 7종·색상 변형 3개·Humanoid rig/UAL 호환을 설명하지만 **애니메이션은 포함하지 않습니다**. 무료 Standard ZIP 45MB와 유료 Source ZIP이 구분됩니다. 성숙한 몬스터 형태 후보로는 유용하지만, 현재 CC0 취득 증거가 없으므로 채택 보류입니다.

## 후보별 실제 확인 내용

| 후보/저작자 | 확인한 라이선스·다운로드 | 형식·동작과 현재 판정 |
| --- | --- | --- |
| Quaternius Modular Outfits + Universal Base + UAL | 위의 기존 CC0 원문·해시 고정 파일, 기존 검증 다운로더 | 성인 비례·Humanoid 가족. Base 공식 평균 약13k triangles는 팩 소개 평균이며 선택 모델의 실측 예산이 아님. Standard의 glTF/FBX와 UAL GLB가 출발점. **사람형 파일럿 1순위** |
| KayKit Adventurers 1.0 / Kay Lousberg | 공식 저장소 LICENSE.txt를 직접 확인: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/blob/672074b73ba276876a19e8816ecdc5241817ab47/LICENSE.txt . 고정 ZIP: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/archive/672074b73ba276876a19e8816ecdc5241817ab47.zip | 해당 **1.0**은 4캐릭터·75동작·25개 이상 액세서리. 캐릭터 GLB, 소품 glTF가 공식 tree에 존재. 단일1024 atlas/모바일 지향. 큰 머리 비례이므로 우리 사람형에 즉시 채택하지 않음 |
| KayKit Skeletons 1.0 / Kay Lousberg | 공식 저장소 LICENSE.txt 직접 확인: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0/blob/15b62b9bad122f72926c10fb14d622c73819fa54/LICENSE.txt . 고정 ZIP: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0/archive/15b62b9bad122f72926c10fb14d622c73819fa54.zip | 4종·90개 이상 동작, 실제 Characters/gltf/Skeleton_Mage.glb 등 확인. 공식 라이선스는 CC0. 기존 해골 전사 한 종의 비교 후보로 제한하며 비례·재질·움직임 retarget 검수 전에는 대체하지 않음 |
| Kenney Castle Kit / Kenney | https://kenney.nl/assets/castle-kit 및 https://kenney-assets.itch.io/castle-kit . 공식 CC0 표기, 무료 kenney_castle-kit.zip | 공식 목록75개, 3D kit v2.0. 공식 itch는 OBJ/FBX/glTF와 무료 ZIP 2.1MB를 명시합니다. ZIP 내부 파일 목록·폴리곤·기단 규격은 미검사입니다. 단순 castle silhouette를 현재 석재/문/벽에 그대로 혼합하지 않음. 연결 모듈 구조/경량 소품 후보 |
| Quaternius Medieval Village MegaKit Standard | https://quaternius.com/packs/medievalvillagemegakit.html 및 https://quaternius.itch.io/medieval-village-megakit | 공식 페이지는 CC0/glTF·FBX·OBJ·grid/interior+exterior 모듈 설명. Standard는 전체의 일부이며 Source 전용 Godot 프로젝트·custom collision을 무료 구성으로 착각하지 않음. **새 ZIP 내부 License 확인 후** 한 소품 또는 비주요 건물 후보 |
| Quaternius Ultimate Monsters | https://quaternius.com/packs/ultimatemonsters.html | 공식 소개50종 animated/CC0 배지·glTF 등 형식. 새 archive License·clip·triangle 미검사, 구형 동물/괴물은 UAL humanoid와 자동 호환 아님. 기존5종의 종/실루엣/행동에 실제 대응하는 모델만 추후 선별 |

KayKit 1.0 기록을 현재 itch의 Adventurers **2.0** 무료5종 설명과 섞지 않습니다. FREE/EXTRA/SOURCE의 파일 범위와 저작권 문구도 별도로 보존해야 합니다. 위 KayKit 원문은 상업 이용을 허용하고 저자 표기를 의무화하지 않지만, 프로젝트 크레딧에는 Kay Lousberg와 원본 팩을 남깁니다.

## 다음 파일럿을 실행할 수 있는 구체 경로

먼저 이미 확보 증거가 있는 **상인 한 명의 Male_Peasant 원본**만 별도 검수 장면에서 비교합니다. 기존 NPC 8종·전사·마법사를 일괄 바꾸지 않습니다. Male_Ranger는 다음 파일럿의 외투/후드/팔 구조 참고이며 기존 마법사와 같은 가족의 rig/재질 동작을 확인하는 기준입니다.

기존 [fetch_sources.py](../sjrpg_3d/tools/hero_art/fetch_sources.py)는 공식 itch endpoint에 POST해 일회성 파일 URL을 받고 ZIP range로 승인 항목만 읽습니다. 다운로드 전체 ZIP fallback을 거부하며, 아래 정확한 파일과 라이선스 SHA-256이 다르면 중단합니다.

| 로컬 source cache 상대 경로 | 바이트 | 기존 SHA-256 |
| --- | ---: | --- |
| adult-source/mage/Male_Peasant.gltf | 32681 | 8f5a6cf6c1cf96e0a0f8e1a861b4245d42b7f88d44e5076da3d48f3fc52f4e76 |
| adult-source/mage/Male_Peasant.bin | 674764 | e46bde795f7b69b351d322d7a5628e07131cfb48ed0afe366293f1b3f530433c |
| adult-source/Male_Ranger.gltf | 41447 | e1033a212332d84d98c19bc4927c621635478d0aa15d13c79da68d3ba9e0196f |
| adult-source/Male_Ranger.bin | 1746884 | 5bbb0d42cb324c6c27ce00417e68a876d92978f07d161f83590f0d7c0570eff6 |

준비 명령은 `python3 sjrpg_3d/tools/hero_art/fetch_sources.py`입니다. `SJRPG_CHARACTER_SOURCE_DIR`로 검수 캐시만 지정하며 런타임 경로를 바꾸지 않습니다. 새 모델 GLB를 배포하기 전에 다음 조건을 만족해야 합니다.

1. 기존 라이선스와 실제 획득 파일 해시를 확인하고, 새 승인 원본·변환 도구·선택 메시·clip 명·수정분·GLB 해시를 기록합니다.
2. glTF의 실제 index accessor로 삼각형을 계산하고 서피스·재질·텍스처·관절 수를 측정합니다. 소개 페이지의 low-poly 문구를 예산 검사로 대신하지 않습니다.
3. 몸과 옷의 중복/숨은 source body를 제거합니다. 기존 mage의65관절·bone 이름·부모·inverse bind·정지/이동/공격/피격/사망 대응을 검사하고, 단순히 같은 제작자라는 이유로 rig가 동일하다고 단정하지 않습니다.
4. +Y 위/+Z 앞/발 중앙/미터 단위/단일 unit scale로 오프라인 제작합니다. 이미 검증된 mage root를 임의로 줄이지 않습니다. 120° 직교 카메라의 네 방향과 실제 발 높이/벽 차폐를 확인합니다.
5. 원본 custom shader를 GL Compatibility에 그대로 강제하지 않습니다. 기존 무광 회화형 base-color/roughness 가족으로 맞추고 512–1024 텍스처와 서피스 예산을 확인합니다.
6. 실제 마을의 동일 위치·줌·빛에서 기존 NPC/주인공과 세로/가로 비교합니다. 기존 Actor clock·hitstop·pause·death/corpse lifecycle·퀘스트 표시·저장 API는 유지합니다.
7. 시각/동작/모바일 비용이 나아진 후보만 반영합니다. 최종 credits에는 Quaternius 또는 Kay Lousberg/Kenney의 실제 채택분, License 원문, source URL/취득일/해시와 프로젝트 수정 내역을 연결합니다.

건축 파일럿은 무료 Standard의 작은 소품 하나로 시작합니다. 성벽·성문은 현재 공통0.32m 석재 단 높이·띠장·흉벽·문 여닫힘·실제 충돌을 가진 한 가족이므로, 한 조각만 외부 팩으로 교체해 연결부를 다시 어긋나게 하지 않습니다.

## 벽·건물의 우선 비교 후보

다음은 **아직 게임에 도입하지 않은** 건축 후보 두 팩과 최소 검수 조합입니다. 아래 조합은 선정할 기능 범위이며, 다운로드하지 않은 파일의 정확한 모델명을 만들어 적은 것이 아닙니다.

| 우선순위/용도 | 정확한 공식 취득·라이선스 근거 | 먼저 비교할 최소 조합과 채택 조건 |
| --- | --- | --- |
| 1 · 마을 비주요 건물의 벽/지붕 구조 | **Quaternius — Medieval Village MegaKit Standard**: [공식 소개](https://quaternius.com/packs/medievalvillagemegakit.html), [공식 다운로드](https://quaternius.itch.io/medieval-village-megakit). 현재 두 공식 페이지가 CC0를 명시하며 itch는 무료 `Medieval Village MegaKit[Standard].zip` 153MB와 유료 Pro/Source를 구분합니다. CC0 원문: https://creativecommons.org/publicdomain/zero/1.0/legalcode.en | Standard 파일 목록에서 **창 없는 벽 한 개 + 같은 계열의 직각 연결부 + 지붕/처마 한 쌍**이 실제로 무료인지 먼저 확인합니다. 내부/외부 면과 grid 모듈이 있어 건물 뒤·옆면 검수에 유리합니다. 기존 석회암/슬레이트 재질로 표면 밀도를 맞출 수 있는 UV·재질 슬롯인지 확인한 뒤 별도 작은 외양간/창고 조합으로만 비교합니다. Source 전용 shader나 collision은 가져온 것으로 간주하지 않습니다. |
| 2 · 성벽의 연결/기단/흉벽 모듈 구조 | **Kenney — Castle Kit**: [공식 소개](https://kenney.nl/assets/castle-kit), [제작자 공식 itch](https://kenney-assets.itch.io/castle-kit). 공식 itch가 CC0 1.0 Universal, OBJ/FBX/glTF, 무료 `kenney_castle-kit.zip` 2.1MB를 명시합니다. 라이선스 원문: https://creativecommons.org/publicdomain/zero/1.0/legalcode.en | 실제 ZIP에서 **직선 벽 + 90° 코너 + 문 접속부**의 일관된 구성 여부를 확인합니다. 간결한 형상이 현재 성숙한 회화풍보다 가벼워 보일 수 있으므로 우선 연결 구조의 참고/경량 검수용으로 둡니다. 실제 도입은 현재 문·두 방향 벽·코너를 한 가족으로 구성하고 재질·비례를 함께 검수할 수 있을 때만 합니다. |

두 팩 모두 glTF는 Godot4.7.2의 출발 형식일 뿐, 가져오기·충돌·프레임 예산 검증을 통과했다는 뜻은 아닙니다. 실제 검수 시 선택 조각을 **오프라인에서 균일한 미터 배율**로 맞추고, 현재 석재 단 높이0.32m·문 순폭/순높이·기단·배우 캡슐 통과·성문 힌지/바깥 열림 규칙과 비교합니다. 축마다 다르게 늘여 줄눈과 문틀을 맞추지 않습니다.

카메라는 기존45°/35.264° 직교와120° 투영 축을 유지합니다. 네 방향에서 앞·뒤·옆면, 벽 상단/하단의 평행선, 지붕 양 경사와 코너 접점을 확인하고 같은 배우·빛·줌의 세로/가로 비교를 남깁니다. 파일럿 조합이 유료 부분에만 있거나 실제 ZIP의 License가 공식 소개와 다르면 그 후보를 도입하지 않고 취득 기록부터 다시 확인합니다.
