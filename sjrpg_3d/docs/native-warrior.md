# Authored native warrior

`assets/models/heroes/warrior/visual.tscn` instances the baked GLB. WarriorRenderer3D controls its named pivots and uses the same adult jaw/cheek/eye/brow/hair anatomy as the resident family and shared ActorSurfaceMaterials painterly atlas. It replaces the warrior card; the imported mage rig remains separate.

The warrior has tapered trouser/thigh/knee volumes and curved toe/ankle boots. Convex forged breastplate and backplate shells follow chest/waist contours; pauldrons are two overlapping shaped plate tiers instead of round shoulder balls. Forearm guards and wrist rims follow the arm taper. A split tunic exposes separate legs. The back cloak is a curved open-front shell with finite thickness, folded hem and shoulder attachment brooches. Face features are outside the skull surface and the collar connects the neck. The sword has a tapered flattened-diamond blade, aligned grip, guard and pommel.

Before use, static mesh pieces are batched per actual moving joint and atlas surface category. This preserves distinct hip/shoulder/sword transforms while reducing the former one-draw-per-detail structure. There are no arbitrary added animation clocks: walking observes Player._run_distance; attacks observe _attack_time/_attack_duration; rolling, contact stop, pause, reduce-motion and death use their source states. The original body flash controls the overlay. Spatial foot, recoil and native physics remain unchanged.

The mesh uses native Y-up metres, +Z front, baked dimensions, grounded soles and identity root scale. Geometry bounds, normals, triangles, parts and actual pose transitions are checked by native_warrior. It targets fewer than7000 triangles and40 mesh nodes, but actual counts must be read from the CI report. Four-angle gallery and real portrait/landscape comparisons are required before visual approval; the previous prototype gallery was explicitly rejected.

Geometry is authored offline in `tools/assets/props/warrior_builder.gd`; runtime only loads the scene. See [GLB/scene contract](native-prop-models.md) for rebuilding and replacement.
