# Native object and UI review harness

The review runs the exported main scene in fresh, isolated Chromium contexts. It uses the normal title, class choice and explicit Start controls; it does not fabricate a screenshot, teleport through a JavaScript test API or replace gameplay with a mock HUD. Existing debug locations select the actual town, bridge, landmarks, encounter and optional cave.

`?native_style_review=1` attaches `NativeStyleReview`, a read-only observer of the live `NativeAdventure.simulation`. It publishes actual HUD and panel rectangles, current class/zoom, retained actor-card ownership and the environment's retained-source inventory. Normal launches do not attach it. The only review action creates/hides the explicitly requested model-inspection overlay; no save files are written by the observer.

```sh
node sjrpg_3d/tools/check_native_style.mjs http://127.0.0.1:8781/ build/native-style-review/after
node sjrpg_3d/tools/compare_native_style.mjs build/native-style-review
```

The browser uses real pointer clicks to open the skill tree, bag, journal and settings. It selects and scrolls real skill nodes, closes panels through their actual buttons, changes the three world-zoom settings, rotates the main window and moves through WASD input. Both roles are inspected at 390×844, 320×640, 568×320 and portrait return; a separate DPR2 case measures CSS touch sizes. The candidate requires 44 CSS-pixel potion/menu/skill targets, separate HUD hitboxes, bounded avatar/gauge frames and no retained resident/enemy image cards. Retained environmental sources remain explicit records, because legitimate ground materials, effect planes and cutout foliage must be distinguished from unconverted solid objects.

After gameplay inspection, the candidate-only gallery renders the actual model builders for all fourteen resident/enemy/warrior archetypes. Its camera turns through four azimuths at the same orthographic elevation; models keep their authored orientation. Captures wait for the requested frame and verify actual mesh triangles, surfaces and nonzero XYZ envelopes. This diagnostic contact sheet supplements the actual game captures and source/physics tests; it is not a claim that all model poses or collisions have been tested through gameplay.

The focused workflow archives the deployed baseline commit `3ec51c4bf4131da4a0e5dafa167a1db63709e714`, adds only the read-only inspection hook, and exports that original game's models and UI. `SJRPG_STYLE_BASELINE=1` records its actual screenshots and geometry while skipping the candidate's new touch/ownership requirements. Its success marker is deliberately `NATIVE_STYLE_BASELINE_CAPTURED`, not a strict candidate pass. Candidate success is `NATIVE_STYLE_PASS`.

Artifacts include independent before/after PNGs and JSON measurements plus paired screenshots that preserve each image's original pixels and aspect ratio. Representative JPEGs use `SJ_NATIVE_STYLE_IMAGE_BEGIN/CHUNK/END` log records. Parse each complete BEGIN-to-END record separately: baseline and candidate may share a capture name. Comparison records have a unique `comparison-` prefix.

A passing harness does not replace independent visual review. Review the paired captures for palette, readability, material density, all visible model surfaces and role distinction, and inspect the explicit remaining-source records before declaring conversion complete.
