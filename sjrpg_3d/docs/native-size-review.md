# Native scale and zoom review — 2026-11-07

Scope: independent 3D edition, existing forest chapter and optional cave. The 2D subtree remains `d2e4264d9c2807e9d898d1cf1a4b4436c2a7f52c`.

Candidate: `00ea188ce661a93615ffeb1234b498e047067720`. Baseline: `11c261e0d60bea7fa0719e43923a5f013164708f`.

## Resulting behavior

Settings retain relative 0.5 / 1 / 1.5 options and existing relative preferences. A fresh default is 1, representing the former 0.75 world zoom. Effective world multipliers are 0.375 / 0.75 / 1.125. Only Game applies the 0.75 base; the native camera derives that result once. HUD, minimap and touch geometry do not scale with world zoom.

All nine native chests have baked 1.25 geometry and 30px movement/attack radius. Closed bounds are approximately 0.570 × 0.529 × 0.375m; the blocker is a finite 0.530m cylinder rather than the former 2.2m prop column. Overhead projectile paths clear the actual chest. The eastern memory chest retains its ID and rewards but moves from ground (1450,260) to (1480,260), clearing the existing angled wall and its opened lid sweep.

Actual standing mesh heights, measured at the same orthographic camera size 16.81339645:

| Species | Before metres | After metres | Increase | New footprint px |
| --- | ---: | ---: | ---: | ---: |
| Goblin | 0.954761 | 1.30 | 36.2% | 25 |
| Wolf | 0.855671 | 1.13 | 32.1% | 36 |
| Boar | 0.863805 | 1.22 | 41.2% | 38 |
| Skeleton | 1.020423 | 1.70 | 66.6% | 25 |
| Golem | 2.356909 | 2.85 | 20.9% | 44 |

Actual rest mesh vertices determine normalization and feet. Living actors and corpses share scale. Footprints are simplified upright movement/combat capsules covering measured stance plus native skin; they do not exactly encompass long snouts, tails or equipment.

## Executed evidence

- [Focused strict CI](https://github.com/obmaz/sjrpg/actions/runs/42353384113): 25 cases passed, zero failures or engine errors. Includes all nine chest bodies/lid sweeps, outer-wall corridor both ways, finite chest projectile height, all five stance/capsule dimensions, real encounter save restoration, real open-gate exclusion and legal bridge traversal for all five species, boss placement, every actual cave spawn and large boar corridor traversal.
- [Actual before/after harness](https://github.com/obmaz/sjrpg/actions/runs/42353384051): each edition passed 14 checks with 14 captures and zero browser/engine errors. The comparison passed 15 numerical checks and produced 14 paired screenshots.
- Correctly labelled pairs are rebuilt by [native-scale-compose.yml](../../.github/workflows/native-scale-compose.yml) from the completed originals, without rerunning the game. The initial comparison tool used an older caption; use the verified-comparison artifact for labelled presentation.
- [Original comparison artifact](https://github.com/obmaz/sjrpg/actions/runs/42353384051/artifacts/13566677781) contains before/after originals, proof JSON, scale-comparison.json and paired screenshots. CI artifacts have a seven-day retention period.
- Fresh default wide view is reviewed separately from equal-camera comparisons. Three real settings options and DPR2 preserve HUD/minimap geometry and touch targets.
- Real right-click approach and left-click opening/reward were exercised on chest 0; chest 7 has a separate wall seam photograph. These are not claims of nine individual input opening runs.
- All five real deaths were observed through native corpse synchronization. One golem corpse extends past the photograph edge; this is not complete visual coverage of every corpse from every face.
- Independent reviewer approved the source, strict physical tests and before/after sizing evidence before release.

The normal release workflow must separately pass all project checks, export, save selection browser review, Pages deployment and fresh published-browser smoke. These deployment outcomes are recorded by the release run, not inferred from this candidate review.

See [native-chest-scale.md](native-chest-scale.md), [native-enemy-models.md](native-enemy-models.md) and [free asset candidates](../../docs/free-asset-sources.md). New free packs were researched, not silently adopted.
