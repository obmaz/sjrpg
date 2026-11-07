# 타격감(Juice) 정리

3D판(`sjrpg_3d`)의 타격감 구조와 현재 수치, 튜닝 위치, 남은 일을 정리한 문서입니다.
항목 번호(#1~#15)는 최초 제안 문서의 번호이며, 개선한 코드에는 `JUICE #번호` 주석이 있습니다.

```sh
grep -rn "JUICE #" scripts tests          # 개선한 지점 전부
tools/check.sh --project=3d --only=juice_tier,juice_enemy,juice_player,juice
```

## 원칙

- `Engine.time_scale`은 쓰지 않습니다. 정지는 `GameTempo.ContactStop`처럼 맞은 액터(또는 때린 플레이어) 단위로만 합니다.
- 연출은 표시 전용이며 피해량·쿨다운을 바꾸지 않습니다. 위치를 움직이는 #3(넉백)·#7(근접 전진)은 예외이고, 이 경우에도 피해량은 그대로입니다.
- 새 연출은 모두 `Prefs.reduce_motion`에서 끄거나 약화하고 테스트로 확인합니다.
- 첫 갱신을 `minf(delta, 0.012)`로 제한해 느린 브라우저 프레임에서도 첫 장면이 한 번은 보이게 합니다.
- 장식 효과는 `cosmetic_effects` 64개 예산 안에서 만듭니다.
- 원본 `audio_profile.dart`에 없는 합성 효과음은 `sound_fx.gd` `PROFILES` 주석에 그 사실을 남깁니다.

## 구조: 피해 단계(`HitTier`)

`Enemy.take_damage`가 `HitTier.of(피해, 최대 체력, 처치 여부)`로 단계를 **한 번** 계산하고, 아래 연출이 모두 이 값을 읽습니다.
HEAVY는 원래의 "강타" 규칙(피해 ≥ 최대 체력 30% 또는 처치)과 같아 기존 임팩트·카메라·정지 동작은 그대로입니다.

| 단계 | 기준(피해/최대 체력) | 숫자 | 넉백(px/s) | 눌림 | 타격음 |
| --- | --- | --- | --- | --- | --- |
| LIGHT | 10% 미만 | 22pt 연노랑, 팝 없음 | 140 | 5% | `impact`·`impact_b` 번갈아 |
| MEDIUM | 10% 이상 | 26pt 노랑, 팝 | 180 | 7% | `impact_c` + `tick` |
| HEAVY | 30% 이상 | 32pt 주황, 팝 | 240 | 10% | `impact_heavy` + `tick` |
| KILL | 처치 | 36pt 적주황, 팝 | 260 | 12% | `impact_heavy` + `kill` |

보스는 넉백이 모든 단계에서 160으로 고정입니다(슬램 박자 보존). 속성(불·번개·얼음) 공격은 `hit_fire`·`hit_lightning`·`hit_ice` 악센트가 위에 더해집니다.

## 구현 항목

| # | 항목 | 상태 | 코드 | 테스트 |
| --- | --- | --- | --- | --- |
| 1 | 피해 단계화 | 완료 | `hit_tier.gd`, `enemy.gd` `take_damage` | `juice_tier` |
| 2 | 데미지 숫자 크기·색·팝(1.4배→1.0, 0.08초) | 완료 | `hit_tier.gd`, `effects.gd` `font_size`·`pop`, `game.gd` `float_text` | `juice_tier` |
| 3 | 넉백 스케일 | 완료 | `hit_tier.gd` `knockback`, `enemy.gd` | `juice_tier` |
| 4 | 스쿼시(0.12초, 적만) | 완료 | `actor_sprite.gd` `trigger_squash`, `native_enemy_models.gd` `sync` | `juice_enemy` |
| 5 | 처치 연출: 공격자 정지 75ms(상한 80ms), 흰색 플래시, 파편 링, 반동 14px, 페이드 0.25초 | 완료 | `hit_tier.gd` KILL_*, `enemy.gd`, `player.gd` `confirm_melee_contact`, `game_tempo.gd` | `juice_enemy` |
| 6 | 보스 처치 연출 | 보류 | | |
| 7 | 근접 전진: 기본 근접만, 접촉 전 16px | 완료 | `player.gd` `_lunge` | `juice_player` |
| 8 | 큰 피해 피격 비네트: 한 번에 최대 체력 15% 이상, 0.22초, 최대 50% | 완료 | `hud.gd` `_build_heavy_hit_vignette` | `juice_player` |
| 9 | 일반 적 공격 예고: 윈드업 시작 노란 플래시(강도 0.55) | 완료 | `enemy.gd` `TELEGRAPH_COLOR`, `actor_sprite.gd` | `juice_enemy` |
| 10 | 보스 슬램 착지 카메라 충격(피해 무관) | 완료 | `enemy.gd` | `juice_enemy` |
| 11 | 타격음 변주·`tick`·`kill`·연속 처치 피치(+1반음/회, 최대 +5, 2.5초 창), 보이스 6→8 | 완료 | `sound_fx.gd` | `juice_tier` |
| 12 | 속성별 적중음 | 완료 | `effects.gd` `contact_element`, `sound_fx.gd` | `juice_tier` |
| 13 | 적 체력바 잔상(0.35초 유지, 초당 최대 체력 120% 소모) | 완료 | `enemy.gd` `ghost_hp` | `juice_enemy` |
| 14 | 카메라 줌 펀치 | 보류 | | |
| 15 | 타격감 강도 설정 | 보류 | | |

## 튜닝 위치

| 바꾸고 싶은 것 | 위치 |
| --- | --- |
| 단계 경계(10%·30%) | `hit_tier.gd` `MEDIUM_RATIO`·`HEAVY_RATIO` |
| 숫자 크기·색, 넉백, 눌림 | `hit_tier.gd` `number_size`·`number_color`·`knockback`·`squash` |
| 처치 정지·반동·페이드 | `hit_tier.gd` `KILL_*` |
| 숫자 팝 | `effects.gd` `POP_SECONDS`·`POP_START` |
| 효과음 모양 | `sound_fx.gd` `PROFILES`(피치·길이·노이즈·게인), 연속 처치 `STREAK_*` |
| 근접 전진 | `player.gd` `LUNGE_*` |
| 비네트 | `hud.gd` `HEAVY_HIT_*` |
| 공격 예고 색 | `enemy.gd` `TELEGRAPH_COLOR` |
| 체력바 잔상 | `enemy.gd` `GHOST_*` |
| 일반 접촉 정지(35~55ms)·반동·카메라 7px | 기존 값: `game_tempo.gd`, `enemy.gd`, `player.gd`, `game.gd` `combat_feedback` |

## 알려진 한계와 이어서 할 일

- **소리는 귀로 조정하지 않았습니다.** `impact_b`·`impact_c`·`tick`·`kill`·`hit_*`의 값은 첫 추정치이고 합성 파형만 테스트했습니다. 실제 기기에서 듣고 `PROFILES`를 조정해야 합니다.
- **체감 수치 검증은 일부만 했습니다.** 브라우저에서 데미지 숫자와 맞은 적의 눌림·HUD 정상 표시는 확인했지만, 정지·넉백·근접 전진의 손맛과 진동은 직접 플레이로 확인해야 합니다.
- **히어로는 눌림이 없습니다.** 히어로 3D 루트 스케일은 1로 유지하는 규칙(`native_warrior` 테스트)이라 제외했습니다. 필요하면 몸통 노드 단위로 별도 설계합니다.
- **근접 전진은 실효 사거리를 최대 16px 늘립니다.** 밸런스에 문제가 있으면 `LUNGE_DISTANCE`를 줄입니다.
- **보류 항목**(#6 보스 처치 연출, #14 줌 펀치, #15 강도 설정)은 위 항목을 직접 플레이해 본 뒤 부족할 때만 진행합니다. 줌 펀치는 멀미 위험이 있고 `camera.zoom`이 리사이즈 때만 설정되므로 곱 계수를 분리해야 합니다.
- 플레이어 피격(체력 감소)에는 단계별 숫자·소리를 아직 나누지 않았습니다. 필요하면 `Player.take_damage`에서 같은 `HitTier`를 쓰면 됩니다.
