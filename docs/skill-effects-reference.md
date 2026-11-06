# 전사·마법사 이펙트 제작 기준

사용자가 2026-11-06 첨부한 여섯 기술 화면을 전투 효과의 후속 기준으로 사용합니다. 전사는 금빛 초승달 궤적·회전 베기·지면 강타, 마법사는 푸른 탄환·서리 파편·화염 낙하를 구분합니다. 월드의 재질·분위기는 기존 [사용자 게임 원본](../assets/source/style/approved-game-reference.jpg)을 유지합니다. 생성된 패밀리 컨셉은 제작 참조이며 사용자 승인이나 실제 게임 검수를 대신하지 않습니다.

## 제작과 재사용

원본은 `assets/source/reference-fx/family-concept.png`와 `skill-sheet.png`입니다. 실제 생성 프롬프트·참조 방식·출력 해시는 `tools/extract/reference_fx_generation.json`, 각 프레임 영역·접점·투영 보정은 `reference_fx_measure.json`에 보존합니다. 첫 생성은 대화의 첨부 원본을 실제 이미지 참조로 사용하며 원본 파일이 별도로 제공되지 않았으므로 파일 해시를 꾸며 기록하지 않습니다. 후속 분리 원화는 같은 컨셉·사용자 게임 원본·기존 타격 패밀리를 함께 참조합니다.

`tools/prepare_reference_fx.py`는 새 그림을 그리지 않고 영역 추출·공통 접점 등록·측정한 지면 보정·여백 패킹만 합니다. 결과는 384px 셀, 가로 네 단계·세로 여섯 종류의 `reference-skills.webp`입니다. `assets/data/reference_fx.json`이 원본·생성 기록·측정·런타임 이미지의 해시를 고정합니다. `ReferenceFxArt.rect()`의 너비는 여백을 제외한 최고조 원화의 폭이며, 접점은 모든 프레임에서 고정됩니다.

효과는 순수 검정 바탕의 ADD 발광 전용입니다. 일반 알파 재질로 그리지 않습니다. 지면의 원은 정통 120° 투영의 세로/가로 비율 약0.57735를 사용하고, 기둥·파편은 위로 서 있습니다. 이미 투영된 원화를 런타임에서 다시 납작하게 만들지 않습니다. 자연형 에너지·파편의 외곽선을 건물 직선의 각도 인증으로 취급하지 않습니다.

## 실제 기술 연결

| 그림 | 기존 기술과 발생 순간 |
| --- | --- |
| 금빛 초승달 | 기본·근접 베기의 실제 접촉 콜백. 착용 무기의 사거리·타격 호를 사용 |
| 회전 궤적 | `whirlwind`의 세 번 타격을 한 번의 연속 효과로 표시. 구르기 등 행동 취소 시 남은 타격과 궤적 종료 |
| 지면 강타 | `leapAttack`의 실제 착지. 피해가 없는 일반 `leap`은 기존 착지 표시 유지 |
| 푸른 탄환 | `iceBolt`·`iceBlast`·`glacialSpike`·`chargedBolt`의 실제 투사체. 화염과 투척 무기의 속성·재질은 유지 |
| 서리 파편 | `frostNova`의 실제 피해·감속 순간에 한 번 표시 |
| 화염 충돌 | `meteor`의 기존 1초 예고가 끝나 실제 충돌 피해가 발생하는 전환에서 한 번 표시. 이후 지속 피해는 낮은 잔불로 구별 |

그림은 두 인접 프레임을 교차 페이드합니다. 피해·사거리·쿨타임·1.5배 행동 템포는 원화와 독립이며 새로운 시각적 판정을 만들지 않습니다. 기존 반동·짧은 접촉 정지·적 색 변화·접촉 소리·작은 카메라 반응을 실제 명중에 연결합니다. 장식은 기존 64개 한도를 공유하고, 느린 첫 프레임에서도 한 번 표시한 뒤 수명이 끝나게 합니다. 메뉴에서는 멈추고 동작 줄이기에서는 한 포즈를 낮은 밝기로 유지합니다. 지면 원은 투영된 장식이며 기존 화면 평면의 원형 반경 판정을 새 타원 판정으로 바꾸지 않습니다.

첫 서리 원화는 지면 투영 보정이 기둥까지 늘려 실제 폰 화면에서 캐릭터를 가렸습니다. 낮고 넓은 `frost-low.png`를 다시 생성해 독립 네 프레임 아틀라스로 채택했습니다. 최고조 높이/너비는 약0.697이며 `effects.frost.override`가 실제 사용하는 픽셀·접점을 가리킵니다. 기존 주 아틀라스의 미사용 서리 행은 나머지 다섯 효과를 그대로 재현하기 위해 제작 이력으로 남습니다. `ReferenceFxArt.texture(key)`와 `frame()`은 실제 채택 텍스처를 함께 선택합니다.

## 검증 화면

```sh
python3 tools/prepare_reference_fx.py
tools/check.sh --only=reference_fx,juice,presentation_art --export
node tools/screenshot.mjs --scene fx_slash --class warrior --device phone --out /tmp/fx-slash.png
node tools/screenshot.mjs --scene fx_frost --class mage --device phone-landscape --out /tmp/fx-frost.png
```

`fx_slash`·`fx_spin`·`fx_slam`은 전사, `fx_bolt`·`fx_frost`·`fx_meteor`는 마법사 검수 장면입니다. `fx_preview`는 명시적인 개발용 쿼리로, 해당 기존 기술을 장착해 실제 시전하고 효과가 나타난 뒤 시뮬레이션을 일시정지합니다. 이 화면은 기본 진행의 기술 해금 상태를 뜻하지 않으며 정상 플레이에는 적용하지 않습니다. 움직임과 타격감은 일시정지하지 않는 `juice` 장면과 전체 전투 회귀 검사로 별도 확인합니다. 가로·세로에서 빛 번짐·검은 사각 매트·HUD 가림·캐릭터 실루엣과 지면 접점을 함께 확인합니다.
