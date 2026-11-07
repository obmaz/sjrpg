# 타격감(Juice) 개선 진행 현황

3D판(`sjrpg_3d`)의 타격감 개선 작업을 이어 하기 위한 기록입니다. 제안 문서의 번호(#1~#15)를 그대로 씁니다.
개선한 코드에는 `JUICE #번호` 주석이 있으므로 `grep -rn "JUICE #" scripts tests`로 찾을 수 있습니다.
수치는 시작값이며 플레이하며 조정합니다. 연출은 표시 전용이며 피해량·쿨다운·충돌을 바꾸지 않습니다. 예외는 #3(넉백)·#7(근접 전진)처럼 위치를 움직이는 항목이며, 이 경우에도 피해량은 그대로입니다.

## 원칙

- `Engine.time_scale`은 쓰지 않습니다. 정지는 `GameTempo.ContactStop`처럼 액터 단위로만 합니다.
- 새 연출은 `Prefs.reduce_motion`에서 끄거나 약화하고 테스트로 확인합니다.
- 첫 갱신을 `minf(delta, 0.012)`로 제한해 느린 프레임에서도 첫 장면이 보이게 합니다.
- 장식 효과는 `cosmetic_effects` 64개 예산 안에서 만듭니다.
- 새 합성 효과음은 원본 `audio_profile.dart`에 없다는 사실을 `sound_fx.gd`의 `PROFILES` 주석에 남깁니다.

## 진행 표

상태: 완료 / 진행 중 / 예정 / 선택

| # | 항목 | 상태 | 코드 표시 위치 | 테스트 |
| --- | --- | --- | --- | --- |
| 1 | 피해 단계화 (`HitTier`) | 완료 | `scripts/hit_tier.gd`, `enemy.gd` `take_damage` | `juice_tier` |
| 2 | 데미지 숫자 크기·색·팝 (22/26/32/36pt, 1.4배 팝 0.08초) | 완료 | `hit_tier.gd` `number_size/number_color`, `effects.gd` `font_size`·`pop`, `enemy.gd`, `game.gd` `float_text` | `juice_tier` |
| 3 | 넉백 스케일 (140/180/240/260, 보스는 160 고정) | 완료 | `hit_tier.gd` `knockback`, `enemy.gd` `take_damage` | `juice_tier` |
| 4 | 스쿼시·스트레치 | 예정 | | |
| 5 | 처치 연출 (공격자 정지 75ms, 흰색 플래시, 파편 링, 반동 14px, 페이드 0.25초) | 완료 | `hit_tier.gd` KILL_*, `enemy.gd` `take_damage`·`_die`, `player.gd` `confirm_melee_contact`, `game_tempo.gd` | `juice_enemy` |
| 6 | 보스 처치 연출 | 선택 | | |
| 7 | 근접 전진 (기본 근접만, 접촉 전 16px, 140px 안에 적이 있고 40px보다 멀 때. 전진한 만큼 접촉 시점 실효 사거리가 최대 16px 늘어남) | 완료, 체감 튜닝 필요 | `player.gd` `_lunge`·`LUNGE_*` | `juice_player` |
| 8 | 큰 피해 피격 비네트 (한 번에 최대 체력 15% 이상, 0.22초, 동작 줄이기 40%) | 완료 | `hud.gd` `_build_heavy_hit_vignette`·`_update_vital_feedback` | `juice_player` |
| 9 | 일반 적 공격 예고 (windup 시작 노란 경고 플래시, 강도 0.55) | 완료 | `enemy.gd` `TELEGRAPH_COLOR`, `actor_sprite.gd` `trigger_flash(strength)` | `juice_enemy` |
| 10 | 보스 슬램 카메라 (착지마다 카메라 충격, 피해 여부와 무관) | 완료 | `enemy.gd` windup 종료 처리 | `juice_enemy` |
| 11 | 타격음 변주·고음 틱·처치음·연속 처치 피치 (보이스 6→8) | 완료, 청취 튜닝 필요 | `sound_fx.gd` `hit_names`·`play_hit`·`streak_pitch`, `enemy.gd` | `juice_tier` |
| 12 | 속성별 적중음 (불·번개·얼음 짧은 악센트) | 완료, 청취 튜닝 필요 | `effects.gd` `contact_element`, `sound_fx.gd` `hit_names` | `juice_tier` |
| 13 | 적 체력바 잔상 (0.35초 유지 후 초당 120% 소모) | 완료 | `enemy.gd` `ghost_hp`·`_update_ghost`·`_draw` | `juice_enemy` |
| 14 | 카메라 줌 펀치 | 선택 | | |
| 15 | 타격감 강도 설정 | 선택 | | |

## 이어서 할 때

1. `git pull --rebase origin main` 후 `tools/check.sh --project=3d`가 통과하는지 확인합니다.
2. 표에서 `예정`인 가장 작은 번호부터 진행합니다. 완료하면 이 표의 상태·위치·테스트를 갱신합니다.
3. 최종 완료 후에는 이 문서를 확정본(수치 표, 튜닝 방법, 알려진 한계)으로 정리합니다.
