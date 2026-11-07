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

Enemy.NATIVE_HEIGHT_METRES is the single native height policy: goblin 1.30m,
wolf 1.13m, boar 1.22m, skeleton 1.70m and golem 2.85m. The legacy atlas catalogue
heights remain as source provenance. Enemy.setup sets body_height to those metres
times 65*Iso.S, which also moves health bars, hit feedback and corpse size with
the body. Enemy collider height uses this value directly; the former additional
1.25 multiplier remains only on existing non-enemy adapters.

NativeEnemyModels measures every actual resting vertex through all descendant
local transforms once per species, caches that AABB, moves its minimum Y to zero
and stores the measured height as base_height. Live bodies and corpses use the
same body_height/(65*Iso.S)/base_height scalar. The source JUICE contact squash
temporarily modifies live visual scale but does not enlarge the collider or corpse.
The player warrior has its own NativeWarrior3D model family and is not changed.

The species footprint is Enemy.radius, a read-only getter of radius_for(kind):
goblin/skeleton 25px, wolf 36px, boar 38px and golem 44px. At the shared horizontal
projection these are about .324/.466/.492/.570m. Actual low-stance radii measured
from the normalized mesh vertices were .215/.265/.430/.458/.516m respectively;
the selected capsules cover the measured stance plus the .015m native skin.
Enemy.RADIUS remains 25px only as a generic fallback before a species is known.
Long tails, snouts, weapons and shoulder overhang are not treated as solid feet.

Movement, knockback, native body registration/rebuild, teleports, area broad
phase, ordinary projectile targets, wave placement and survivor restore all use
the same instance/kind radius. Explicit custom projectile radii remain respected.
Ambient spawn chooses the kind before its native overlap query. Encounter waves
revalidate a generic candidate after choosing the kind, and pack spacing/separation
use the two actors' actual radii. Monster-boundary collision is never relaxed to
fit a larger model. AI attack reach,
damage, health, speed, experience and save formats are unchanged.

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

## Native size validation

native_enemy_scale creates a real game after native readiness, uses the actual
outside-town spawn search, and builds each species through Enemy.setup and the
normal presenter. It measures transformed mesh vertices in metres; compares
sprite height, physics capsule and visual top/foot; checks walking and hit/death
presentation retain native feet/base scale; tests default versus explicit
projectile radii; and verifies the real death corpse uses the same scale and floor.
PASS NATIVE_SIZE_METRES logs actual mesh bounds and capsule dimensions for CI review.

native_enemy_radius additionally checks real open-gate exclusion for all species,
bridge clearance under existing native rules, the actual boss-clearing spawn,
all real cave spawns and a large boar traversing the native narrow cave branch.
The existing encounters persistence test now preserves the largest pack member
and verifies its restored native body metadata, legal position and pair spacing
against the species radii.
