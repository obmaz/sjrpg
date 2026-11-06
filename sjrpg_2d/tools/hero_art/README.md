# 영웅 옷감 검증 도구

이 폴더는 영웅 재질 실험과 직교 3D 비교용 GLB 내보내기 도구입니다. 기존 2D 게임 아틀라스는 바꾸지 않습니다.
Quaternius의 무료 CC0 골격·동작·피부와 이전 프로젝트의 카메라·발 기준을 유지하고,
마법사의 옷감 슬롯은 원래 UV·색·버클 무늬를 유지하면서 생성형 천의 밝기 결을 약하게 곱하고 얕은 요철로 사용합니다.
기존에 과하게 어둡게 만든 옷감 값만 후보에서 조정하며 피부·얼굴·부츠는 유지합니다.
단색 로브 패널 두 장에는 같은 생성형 남색 천을 적용하고 새 UV를 휴지 자세에서 기계적으로 등록합니다.
동작마다 무늬를 다시 그리지 않습니다.

추가 `ranger` 모드는 같은 무료 소스의 긴 소매 몸통·팔만 원래 골격에 연결한 **정지4방향 후보**입니다.
공식 파일의 공통65개 역바인드 행렬이 동일한 것을 확인하고, Blender에서도 휴지 자세 차이를 검사합니다.
얼굴·피부 재질·다리·부츠·지팡이는 유지하며 새 메시를 절차적으로 만들지 않습니다. 몸통 외곽은 바뀌므로
재질만 바꾼 후보의 실루엣 동일성 검사와 구별해야 합니다.

`clean` 모드는 긴 소매 후보에 머리 추출 오류 수정을 합친 12프레임 실험입니다. 기존 높이 절단만으로
머리 메시 안에 남던 어깨·쇄골 조각을 원본 `Head`＋`neck_01` 영향도로 구별합니다.
검증한 원본에서 문제 어깨 정점34개와 쇄골 조각14개의 머리·목 영향은 모두0.10 이하입니다.
이 부분만 제거하고 머리·목이 지배하는 정점과 눈·눈썹 전체를 유지하는 가드를 둡니다.
좌우 위치는 제거 규칙이 아니라 알려진 어깨 조각이 모두 사라졌는지 확인하는 검수용입니다.

`upstream-provenance.json`은 이전 프로젝트 도구·출처 기록의 해시를 보존합니다.
`source-provenance.json`은 실제 무료 원본 파일의 검증 해시이며 `CC0_SOURCES.txt`에 원문 크레딧이 있습니다.
이 CC0 표기는 원본 모델·텍스처·애니메이션의 라이선스이며 도구 코드의 별도 라이선스를 새로 주장하지 않습니다.

## 실행

Python3, Blender4.3 이상이 필요합니다. 공식 소스는 저장소 밖의 지정 폴더로만 받습니다.
다운로드 도구는 필요한 ZIP 항목만 Range 요청으로 읽고, 예상 해시가 다르거나 Range를 지원하지 않으면 실패합니다.
HTTP429가 오면 재시도를 반복하거나 검증하지 않은 다른 모델로 대체하지 않습니다.

```sh
SJRPG_CHARACTER_SOURCE_DIR=/tmp/sjrpg2-character-source \
python3 tools/hero_art/fetch_sources.py

SJRPG_CHARACTER_SOURCE_DIR=/tmp/sjrpg2-character-source \
SJRPG_RENDER_CELL=384 SJRPG_MATERIAL_PILOT_MODE=baseline \
blender --background --factory-startup --disable-autoexec --threads 2 \
  --python tools/hero_art/render_mage_pilot.py

SJRPG_CHARACTER_SOURCE_DIR=/tmp/sjrpg2-character-source \
SJRPG_RENDER_CELL=384 SJRPG_MATERIAL_PILOT_MODE=candidate \
blender --background --factory-startup --disable-autoexec --threads 2 \
  --python tools/hero_art/render_mage_pilot.py
```

두 렌더는 동시에 실행하지 않습니다. 각 실행은 CPU2스레드로 정지4방향과 아래 방향 달리기8프레임만 만듭니다.
출력은 소스 폴더 아래 `mage-material-pilot/{baseline,candidate}`입니다. 재질 이미지 해시·실행 모드·도구·원본 해시가
캐시 키에 들어가며, 원래 골격의 각 프레임·투영 원점·뼈 좌표는 메타데이터에 남습니다.

긴 소매 후보는 같은 명령의 `SJRPG_MATERIAL_PILOT_MODE=ranger`로 네 정지 포즈만 생성합니다.
추출까지 수정한 후보는 `SJRPG_MATERIAL_PILOT_MODE=clean`으로 정지4방향과 달리기8프레임만 생성합니다.
`compare_pilot.py --baseline <baseline폴더> --candidate <후보폴더> --out <검수폴더>`는
카메라·투영 원점·포즈·알파 외곽을 비교하고 원본 프레임을 그대로 나란히 놓습니다.

## 채택 전 비교

출시 아틀라스에 패킹하거나 저장소의 이전 Flutter 프로젝트에 설치하는 기능은 없습니다.
먼저 두 출력의 동일 포즈·뼈 좌표·발 기준·실제 알파 실루엣 크기를 비교하고, 얼굴·피부가 바뀌지 않았는지
앞뒤와 양쪽에서 봅니다. 원화 확대와 실제 모바일 크기에서 옷감이 읽히면서 모아레나 번쩍임이 없는지 확인합니다.
재질만으로 낮은 메시 밀도·얼굴 구조까지 사용자 레퍼런스 수준이 된다고 판정하지 않습니다.

이후 실제 게임에서 기존 16방향·8프레임 전체를 유지하는 별도 아틀라스를 검증해야 합니다.
원본 도구의 `--install`은 이전 프로젝트를 수정하므로 사용하지 않습니다.

## 명시적인 전체 마법사 시험 출력

`production`을 명시한 경우에만 마법사 정지16＋달리기128＋시전128의 총272장을 만듭니다.
구르기·탑승·전사 역할은 포함하지 않습니다. 기본 실행은 여전히 작은 파일럿입니다.

```sh
SJRPG_CHARACTER_SOURCE_DIR=/tmp/sjrpg2-character-source \
SJRPG_RENDER_CELL=384 SJRPG_MATERIAL_PILOT_MODE=production \
blender --background --factory-startup --disable-autoexec --threads 2 \
  --python tools/hero_art/render_mage_pilot.py

python3 tools/hero_art/pack_mage_trial.py \
  --source /tmp/sjrpg2-character-source/mage-material-pilot/production \
  --out /tmp/sjrpg2-mage-trial
```

시험 패커는 `/tmp` 외부 출력을 거부하며 현재 런타임 메타데이터는 읽기만 합니다.
원본384px 픽셀을 확대·축소하지 않고 새 알파 외곽에6px 여백만 더해 패킹합니다.
기존 기준 높이·16방향 phase-major 클립과 고정 투영 원점을 유지하며,
모든 새 ROI와 발 좌표가 원래 투영 원점으로 되돌아가는지 검사합니다.
출력 `mage.png`, `mage-cast.webp`, 두 JSON, `manifest.json`과 검수 시트는 채택 전 시험 자료입니다.
실제 게임 원화로 설치하거나 기존 아틀라스를 덮어쓰는 기능은 없습니다.

## 별도3D 프로젝트의 GLB

네이티브 GLB 내보내기는 [3D 프로젝트의 영웅 제작 도구](../../../sjrpg_3d/tools/hero_art/README.md)로 옮겼습니다.2D판에는 GLB 런타임/비교 기능이 없으며, 위2D 아틀라스·재질 검수 파이프라인과 원본 CC0 출처는 그대로 유지합니다.
