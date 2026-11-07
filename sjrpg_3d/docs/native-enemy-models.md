# Native enemy model family

NativeEnemyModels replaces the five stage-one enemy card archetypes with lit,
closed-volume articulated models. Source geometry is reproducible GDScript,
not an imported skeletal asset or a camera-facing picture.

The goblin has an authored brow, cheek, pointed nose and ears, segmented leather
tunic, diagonal strap, belt and boots. The skeleton has an empty ribcage, spine,
pelvis, separate thigh/shin bones, knees/ankles/toes, skull, recessed framed
sockets, mandible and teeth. The golem uses irregular offset faceted slabs and
joint gaps rather than cubes or rounded capsules. Wolves use lean withers,
a long tapered muzzle, segmented legs/hocks, paws and a tapered downward tail.
Boars use the heavier barrel, paired curved tusks, cloven hooves and a low rough
bristle crest. Weapons have a separate grip, guard and tapered blade; shields
have five boards, binding rails and a central boss.

Generated shared flat cloth/leather/iron/skin/fur/rock materials come from
NativeActorMaterials. Textures are cached and triplanar; materials are cloned
per actor so status tint, contact flash and death alpha cannot mutate another
actor or corpse. The skeleton's pale bone uses the neutral skin swatch alias.
Material source/prompt provenance belongs to the shared atlas contract.

XZ floor/Y-up and +Z front follow the shared 120-degree orthographic contract.
Mesh resources are cached by archetype, joint and palette role. Authored pieces
are merged by material inside each independently posed joint. No colliders are
added. Native actor_foot owns elevation; sprite recoil and contact squash are
presentation offsets. Facing, actual walk distance, attack state timers,
flash/tint and death alpha are observed from the original actor. No independent
animation or gameplay clock is introduced. The leg pivots compensate for the
pendulum's vertical lift so walking does not lift both feet off the floor.
Dying actors remain weakly referenced through the original 0.18-second fade.

Height uses source body_height divided by 65*Iso.S, then the authored
1.72m biped or 1.16m quadruped reference. The original spatial collision is
authoritative. The player warrior has its own NativeWarrior3D model family.

Corpse visuals reuse the corresponding model rotated prone. The full transformed
mesh bounds place the resting body on its actual floor. CorpseArt.opacity with
the actual remaining time/lifetime and used flag owns visibility and expiry.
Forest/cave ownership follows the current source corpse list.

Validation includes native_enemy_models normals/all-axis volume/material light,
real joint pose changes, alpha, and the 6k-triangle/20-mesh upper bound. The
ortho_3d_preview integration case checks no duplicate enemy card, real visual
recoil/flash at native feet, dying fade after removal from the live array, and
the native corpse's original opacity/expiry. Four-facing gallery screenshots
and real portrait/landscape gameplay review remain required for adoption.
