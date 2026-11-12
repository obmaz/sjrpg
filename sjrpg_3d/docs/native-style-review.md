# Native object and UI review harness

The review runs the exported main scene in fresh, isolated Chromium contexts. It uses the normal title, class choice and explicit Start controls; it does not fabricate a screenshot, teleport through a JavaScript test API or replace gameplay with a mock HUD. Existing debug locations select the actual town, bridge, landmarks, encounter and optional cave.

`?native_style_review=1` attaches `NativeStyleReview`, a read-only observer of the live `Adventure3D.simulation`. It publishes actual HUD and panel rectangles, current class/zoom, retained actor-card ownership and the environment's retained-source inventory. Normal launches do not attach it. The only review action creates/hides the explicitly requested model-inspection overlay; no save files are written by the observer.

```sh
node sjrpg_3d/tools/check_native_style.mjs http://127.0.0.1:8781/ build/native-style-review/after
node sjrpg_3d/tools/compare_native_style.mjs build/native-style-review
```

The browser uses real pointer clicks to open the skill tree, bag, journal and settings. It selects and scrolls real skill nodes, closes panels through their actual buttons, changes the three world-zoom settings, rotates the main window and moves through WASD input. Both roles are inspected at 390×844, 320×640, 568×320 and portrait return; a separate DPR2 case measures CSS touch sizes. The candidate requires 44 CSS-pixel potion/menu/skill targets, separate HUD hitboxes, bounded avatar/gauge frames and no retained resident/enemy image cards. Retained environmental sources remain explicit records, because legitimate ground materials, effect planes and cutout foliage must be distinguished from unconverted solid objects.

After gameplay inspection, the candidate-only gallery renders the actual model builders for all fourteen resident/enemy/warrior archetypes. Its camera turns through four azimuths at the same orthographic elevation; models keep their authored orientation. Captures wait for the requested frame and verify actual mesh triangles, surfaces and nonzero XYZ envelopes. This diagnostic contact sheet supplements the actual game captures and source/physics tests; it is not a claim that all model poses or collisions have been tested through gameplay.

The focused workflow archives the deployed baseline commit `3ec51c4bf4131da4a0e5dafa167a1db63709e714`, adds only the read-only inspection hook, and exports that original game's models and UI. `SJRPG_STYLE_BASELINE=1` records its actual screenshots and geometry while skipping the candidate's new touch/ownership requirements. Its success marker is deliberately `NATIVE_STYLE_BASELINE_CAPTURED`, not a strict candidate pass. Candidate success is `NATIVE_STYLE_PASS`.

Artifacts include independent before/after PNGs and JSON measurements plus paired screenshots that preserve each image's original pixels and aspect ratio. Representative JPEGs use `SJ_NATIVE_STYLE_IMAGE_BEGIN/CHUNK/END` log records. Parse each complete BEGIN-to-END record separately: baseline and candidate may share a capture name. Comparison records have a unique `comparison-` prefix.

A passing harness does not replace independent visual review. Review the paired captures for palette, readability, material density, all visible model surfaces and role distinction, and inspect the explicit remaining-source records before declaring conversion complete.


## 화면 방향과 회전

설정의 자동·가로·세로는 기기 공통 선호값입니다. Android는 DisplayServer 방향을, Web은 지원되는 실제 Screen Orientation/Fullscreen API를 사용합니다. `web/check_orientation.mjs`는 전체화면 진입 순서·지원 거절·재시도·늦은 응답 취소를 검증합니다. 잠금 성공 fixture와 실물 기기의 센서 회전 검증은 구분합니다.

루트 `tools/check_native_web.sh`는 실제 마을·동굴을 세로→가로→세로로 바꾸며 물리 진행·네이티브 뷰포트 방향을 확인합니다. 실패 시 캡처와 `ROTATION_FAILURE`의 문서 포커스·가시성·창/논리/네이티브 크기·일시정지 상태를 함께 확인합니다. `Review cave readability and settings`의 수동 실행에서 `rotation_only`를 켜면 이 진단과 관련 집중 검사를 실행합니다. 정지 여부는 실제 프로브로 판단하고 사진만으로 플레이 상태나 장시간 성능을 추정하지 않습니다.
