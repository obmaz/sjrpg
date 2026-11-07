# Native enemy model family

NativeEnemyModels replaces the five stage-one enemy card archetypes with lit,
closed-volume meshes: goblin ears and shield, skeletal ribs and shoulder armour,
wolf long muzzle/tail, boar tusks and dorsal bristles, and broad stone golem plates.
The warrior variant adds a cuirass, belt and hair silhouette to the biped rig.

The source is reproducible GDScript geometry, not a generated image or imported
skeletal animation. XZ floor/Y-up and +Z front follow the shared 120° camera contract.
Mesh resources are cached by archetype, joint and palette role. Static pieces are
merged by material inside each independently posed joint. No colliders are added.

Height uses the existing source body_height divided by 65*Iso.S, then the authored
reference height (1.72m biped / 1.14m quadruped). Native actor_foot owns elevation;
sprite recoil is a visual offset only. Facing, walk distance, attack state timers,
flash/tint and death alpha are observed from the original actor. No independent
animation or gameplay clock is introduced. Dying actors remain weakly referenced
through their original 0.18s fade even after leaving the live enemy array.

Corpse visuals reuse the corresponding model rotated prone. The full transformed
mesh bounds set its resting height on the actual floor. CorpseArt.opacity with the
actual remaining/lifetime and used flag remains authoritative; no extra lifetime
or timer is added. Forest/cave ownership follows the current source corpse list.

Validation: native_enemy_models checks normals, all-axis volume, material lighting,
joint pose changes, alpha and the 6k-triangle/20-mesh upper bound. Real portrait/
landscape screenshots and source-to-native ownership checks are mandatory before
adoption. These are modular articulated models, not a claim of a sculpted
production character rig or offline-baked skeletal asset.
