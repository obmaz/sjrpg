# 캐릭터 동작 그림

전사와 마법사는 각각 16방향의 별도 대기 자세와 방향당 실제 달리기 8자세를 사용합니다. 전사의 세 검 콤보와 마법사의 준비·발사·회복도 각각 16방향·실제 8자세이며, 두 직업의 구르기도 같은 남성 몸체와 카메라로 렌더링했습니다. 클라이언트는 기존 Flutter·Bonfire의 2D 그림만 읽으며 3D 모델을 내려받거나 실행하지 않습니다.

그림은 Quaternius의 무료 CC0 Standard 모델·애니메이션으로 오프라인 생성합니다. 출처·원본 SHA256·카메라·자세 표·최종 파일 SHA256은 [provenance](character-motion-provenance.json), 원문 라이선스는 [credits](../licenses/quaternius-characters.txt)에 있습니다. 전사는 투구·어두운 판금 갑옷, 마법사는 남색 천 로브·짧은 지팡이를 사용합니다. 얼굴은 같은 성인 남성 베이스이며 HUD·직업 선택 그림은 변경하지 않습니다.

달리기는 기존의 실제 이동 84단위 주기를 유지하고 8자세를 선택합니다. 이동하지 않으면 별도 대기 자세를 사용하며 탑승 중에도 달리기 접촉 자세를 재사용하지 않습니다. 달리기·공격·구르기의 원근과 몸체 배율은 일정합니다. 주인공은 투영 원점을 중심으로 가로 1.36배·세로 1.00배를 대기·달리기·공격·시전·구르기·탑승 그림에 공통 적용해 체형을 묵직하게 보이게 합니다. 충돌 몸체나 발 위치는 바꾸지 않습니다. 각 그림을 알파 경계로 자를 때에도 발 아래를 다시 정렬하지 않고 카메라가 투영한 월드 원점을 보존합니다. `feet = packedOrigin + projectedOrigin - cropOrigin`이며 투명 여백은 6px입니다. 새 기록의 `anchorMode: projected-origin`은 모든 발 기준·기준 높이가 유한하고 반전이 없는지 검사합니다.

이동·공격·시전 아틀라스 여섯 장은 각각 2048×1024 RGBA 8MiB, 공유 구르기는 1024² 4MiB로 전체 52MiB입니다. 실제 256px 렌더를 기존 128px로 축소하지 않고 그대로 사용해 픽셀 밀도를 가로·세로 2배로 높였습니다. 크기·앵커도 같은 배율로 기록하므로 게임 안의 캐릭터 크기와 발 위치는 유지됩니다. 모든 그림은 무손실 압축을 사용하며 전송량은 전체 약 5.86MiB입니다. 프레임 수와 그리기 횟수는 유지하고 단계별 로딩으로 필요한 직업의 공격 그림만 디코딩합니다. 새 파일·원본 렌더 시퀀스 해시는 [고해상도 provenance](character-high-resolution-provenance.json)에 기록합니다.

## 다시 생성

오프라인 도구만 Python3·Pillow·Blender4.3 이상이 필요합니다. 아래 도구는 공식 무료 ZIP에서 필요한 파일만 HTTP Range로 가져오고 원본 해시를 검사합니다. 큰 소스 ZIP·GLB·작업 PNG는 저장소 밖에 둡니다.

```sh
export SJRPG_CHARACTER_SOURCE_DIR=/tmp/sjrpg-character-source
python3 tools/character-art/fetch-sources.py
blender --background --factory-startup --disable-autoexec --threads 2 --python tools/character-art/render-warrior.py
blender --background --factory-startup --disable-autoexec --threads 1 --python tools/character-art/render-mage.py
python3 tools/character-art/export.py
```

`action` 기록은 16방향·8자세를 별도 선언하고 실제 시뮬레이션의 정규화된 진행도를 선택에 사용합니다. 진행도가 없는 구 호출과 `action` 기록이 없는 구 그림은 기존 두 자세 선택을 유지합니다.

출력은 지정한 폴더의 `runtime-final/manifest.json`이며 일반 게임 빌드에서는 이 도구를 실행하지 않습니다. 원본 주기 시간과 게임의 이동 주기는 별개이며, 자세만 정규화해 기존 게임 동작에 맞춥니다. 검토용 320ms GIF도 화면 프레임 성능을 측정한 결과는 아닙니다.

최신 원본 렌더를 고해상도로 내보내려면 다음 명령을 사용합니다. 구형 렌더 캐시에 시전 동작이 별도로 있다면 `--mage-casts`에 해당 `render-metadata.json`의 폴더를 지정할 수 있습니다.

```sh
python3 tools/character-art/export-high-resolution.py --warrior "$SJRPG_CHARACTER_SOURCE_DIR/helmet-warrior" --mage "$SJRPG_CHARACTER_SOURCE_DIR/mage-full" --output "$SJRPG_CHARACTER_SOURCE_DIR/high-resolution" --install
```
