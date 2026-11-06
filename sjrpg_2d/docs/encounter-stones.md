# 숲의 재소환 비석

원본 `obmaz/sjrpg`의 `EncounterArea`·`EncounterStone`을 숲 1장에 이식합니다.
기준 소스는 [encounters.dart](https://github.com/obmaz/sjrpg/blob/d8ed1222fc65428b7407e040ef704797dda3c11e/lib/src/models/encounters.dart)와
[adventure.dart](https://github.com/obmaz/sjrpg/blob/d8ed1222fc65428b7407e040ef704797dda3c11e/lib/src/game/adventure.dart)의
`strikeEncounterStoneAtHit`·`spawnPack`입니다.

## 규칙과 이식 범위

- 처음 가까이 접근하면 지역의 첫 무리가 나타납니다. 그 지역 적을 모두 정리하면 비석을 공격해 다시 소환합니다.
- 충전은 최대 3개이며 실제 숲 플레이 시간 300초마다 1개를 회복합니다. 세 번 사용하면 영구 소진되는 규칙이 아닙니다.
- 일시정지·오프라인·다른 맵에서는 충전을 진행하지 않습니다. 남은 충전과 부분 시간은 저장합니다.
- 실제 공격 명중과 지형 시야를 검사합니다. 적의 공격, 0 피해, 빗나감, 이동·방어 주문은 충전을 쓰지 않습니다.
- 같은 지역에 살아 있는 적이 있으면 멀리 가서 휴면 상태가 되어도 다시 소환할 수 없습니다.
- 적을 하나 이상 생성했을 때만 충전을 소비합니다. 마지막 적을 죽인 같은 프레임의 공격으로 새 무리를 즉시 만들지 않습니다.
- 새 무리도 생성 프레임의 같은 공격에 바로 죽지 않습니다. 다음 프레임부터 일반 피해를 받습니다.
- 비석 자체는 파괴되거나 보상을 주지 않습니다. 소환된 적의 경험치·드롭·숲 의뢰 처치는 일반 전투와 같습니다.

원본은 넓은 세계의 3072 단위 지역을 발견할 때 비석을 동적으로 설치합니다.
Godot판은 작은 숲 지도에 맞춰 동서남북과 깊은 숲의 **6곳**을 사용하고 지형을 검사해 위치를 조정합니다.
첫 무리는 마을 근처 4마리·먼 숲 6마리, 재소환은 각각 최대 6마리·8마리입니다.
사용자의 밀도 요청에 맞춘 Godot판 조정이며 원본의 마을 근처 3~4마리보다 많습니다.
일반 필드 생성은 살아 있는 적 30마리를 상한으로 하며 보호 의뢰·보스 진행은 기존 전용 생성을 유지합니다.

일반 배회 몬스터도 3초에서 **2초 간격**, 마을 근처 목표 6→10마리·먼 숲 12→16마리로 조정합니다.
주변 생성 거리는 560~1000에서 440~720 화면 월드 픽셀로 줄입니다. 마을 안전 구역·벽·강에는 생성하지 않습니다.
비석 무리는 배회 적 정리에 의해 삭제하지 않고, 먼 적은 휴면 처리해 남은 무리와 재소환 조건을 보존합니다.

## 저장·충돌·공격

`EncounterRuntime`은 지역 상태와 생존 적을 관리하고 `EncounterStone`은 원화·충돌 기단·근거리 안내를 표시합니다.
`GameState.encounters`는 충전·충전 시간·최초 등장 여부·생존 적 종류/레벨/체력/위치를 저장합니다.
저장 직전의 `encounter_capture`가 실제 생존 목록을 갱신하고 새 게임·불러오기는 이전 콜백을 해제합니다.
기존 저장에 기록이 없으면 처음부터 3충전으로 시작합니다. 저장하지 않은 오프라인 시간은 더하지 않습니다.

비석의 52×32 지면 기단은 실제 마을·지형과 같은 충돌 목록에 들어갑니다.
일반 근접·범위·투사체·광선·연쇄 번개·지속 영역·히드라의 공격을 연결합니다.
투사체는 이동 선분과 비석 기단의 접점을 다른 적과 정렬해 앞의 대상 뒤에서 충전을 쓰지 않게 합니다.
공격할 적이 없을 때 준비된 가까운 비석이나 상자로 조준을 보완합니다.

## 원화와 재생성

원본의 현재 우선 비석 그림 `docs/art/world-monuments/beacons-original.png`에서 숲 셀만 사용합니다.
원본 Git 이력·해시·crop·발치와 실제 선분은 `tools/extract/encounter_art_provenance.json`·`encounter_art_measure.json`에 보관합니다.
다른 장의 그림은 런타임에 가져오지 않습니다.

`assets/source/encounter-stone.png`를 보존하고 `prepare_encounter_art.py`로 투명 WebP를 만듭니다.
전체 원화 높이는 112, 기단 중심이 배치·깊이 기준입니다. 담쟁이와 돌의 자연 실루엣은 직선 축으로 인증하지 않습니다.
실제 상·중·하단 캡과 양쪽 기단·수직선 20개를 측정하고 삼각형 보정으로 ±30°/90°에 맞춥니다.
`art_projection`은 외부 정의 파일도 같은 `IsoSprite` 변환으로 검사하며 원본·렌더 해시와 메시 뒤집힘을 확인합니다.

```sh
python3 tools/prepare_encounter_art.py
python3 tools/extract/art_audit_catalog.py
tools/check.sh --only=art_projection,encounters,encounter_combat,encounter_saving --export
node tools/screenshot.mjs --scene stone_cast --class warrior --device phone
node tools/screenshot.mjs --scene stone_cast --class mage --device phone-landscape
```

`stone`·`stone_active`·`stone_empty`는 상태별 검수 화면입니다. `stone_cast`는 실제 공격 입력으로 충전 1개 소비와 적 출현을 확인합니다.
이 쿼리에서만 검수 상태를 만들며 정상 게임의 저장·배치·보상을 바꾸지 않습니다.
