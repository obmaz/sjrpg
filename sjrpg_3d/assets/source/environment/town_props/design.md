# Native fountain and warp-gate family

Models are reproducibly exported with Blender 4.3.2 and imported/tested with Godot 4.7.2 in an isolated worktree. Actual portrait/landscape browser review remains pending.

The root `docs/3d-asset-guide.md` and the old reference/look/art/prompt guides were read. The authoritative user reference and the current fountain/portal family artwork were inspected. References, source-data and shared-material hashes are in `provenance.json`. No new image was generated or raster-painted.

## Assets and fit

- `native-fountain.glb`: 2.60×1.94×2.60m, centred ground pivot. The actual source footprint is 2.615×2.646m, whose centre is (-1.308,-1.323)m from the source's front-foot pivot. Four chamfered foundation slabs, sixteen separate real-thickness basin stones, submerged floor, actual inner wall and lip, recessed central pier, upper feed cup/stone finial, two bronze spouts and two curved water streams. Lower water Y=.345m, upper feed water Y=1.505m. No new collider.
- `native-warp-gate.glb`: 3.098×3.065×1.28m, centred ground pivot; actual source footprint 3.137×1.327m with centre offset(-1.569,-.663)m. Real pilasters, .32m courses, eleven arched voussoirs, cap/keystone depth, a narrow recessed oak lining and restrained matte bronze anchors. Clear magical opening1.62×2.35m. +Z front. Existing portal interaction and full-base blocking policy remain authoritative.
- Both meshes have baked metre dimensions, Y-up/+Z, unit scale. Helper places them at the actual warped footprint centroid and derives yaw from its long edge. It never nonuniformly rescales the asset or adds collision.
- A too-small footprint retains its source-art fallback. All realm source portals use the same model: town, tree, cave approach, guardian beacon and cave return. Source positions, checkpoint discovery, destinations and interaction distances are unchanged.

## Budgets and materials

Actual GLB measurements match `geometry-plan.json`: fountain 3,612 triangles/3 surfaces/270,920 bytes; gate 1,883 triangles/4 surfaces/145,760 bytes. Neither GLB embeds any images or textures. Fountain uses three material surfaces; portal four plus one shared12-mote MultiMesh draw. The geometry plans are below8k/6k triangles. Runtime meshes/stone/timber/bronze/mote material resources are shared. Each fluid instance has one small ShaderMaterial so it can observe that source's own clock.

Shared limestone uses the existing2.56m/8-course world tile. Timber reuses the existing generated oak. Bronze is muted, metallic.45/roughness.72. No fake normal/roughness image is claimed. Water is a small lit translucent surface/jet shimmer; the magical opening has a restrained animated filament shader. Both shaders use explicit source `phase`, never `TIME`. Small portal motes are actual instanced3D effect points.

## API and integration

`TownPropRenderer3D.new().setup(presenter, {"stone":shared_stone,"wood":shared_wood})`, then `sync()`. `owns(source)` / `source_ids()` identify only successfully mounted native replacements. Native setup must precede source-art fallback batching.

1. Export the models with `blender -b -t 2 --python tools/assets/environment/build_native_town_props.py -- --export` from the 3D project.
2. Construct/sync the helper before environment/affordance batches. The old technical fountain builder is removed.
3. Affordance portal loops and environment forest/cave sprite batching must skip `owns(source)`. This includes the guardian source and cave return source, not just the three destination registry entries.
4. Call helper `sync()` before environment realm rebuild/sync. It observes the currently active source world, removes previous-realm instances, and uses each source `PlazaWater.phase`; there is no new timer.
5. The original source clock freezes on pause and resets with reduced motion; native fluid/motes follow it. Material motion becomes zero and portal brightness is restrained in reduced motion.
6. Keep fluid/mote nodes excluded from static mesh batching. Static stone/wood/bronze surfaces can use the shared scene materials and normal static batching. Do not bake dynamic surfaces away or keep duplicate source cards.

## Validation and remaining review

Run the pure geometry plan tests, then actual Blender export/group/bounds/triangle validation. Check actual mobile portrait/landscape fountain and all gate roles next to the same hero/stone family. Verify rim/inner-wall thickness, real arch depth, footprint centring, metre scale/UV density, pause/reduced motion, source clock parity, cave transition cleanup, no doubled cards, no added colliders and unchanged warp approach/destination UI. Source/material hashes and eventual output hashes must be preserved in the project; `/tmp` is not the final provenance location.
