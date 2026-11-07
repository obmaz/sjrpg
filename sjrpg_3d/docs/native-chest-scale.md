# Native treasure chest scale and placement contract

The existing Stage1 treasure chests use `NativeEncounterMesh3D`; no new asset image, binary model, timer, reward or region is added. The shared timber/iron materials and per-metre UV density remain unchanged. `sjrpg_2d/` is not modified.

The chest is baked uniformly 25% larger inside the reproducible mesh generator, including metal fittings, hollow body, hinge-local lid and consumed splinters. Runtime nodes retain unit scale. Closed bounds change from 0.456×0.4231955×0.300m to 0.570×0.5289944×0.375m. The hinge pivot is scaled with the geometry; its -65° opening and source consumed-state observation remain unchanged. The continuous maximum horizontal sweep changes from 0.3004111m to 0.3755138m.

`Chest.COLLISION_RADIUS` is 30 projected-ground units (previously 24). Both the source village circle and the authoritative native cylinder use that value, 0.3884996m in native space (`65 × sqrt(1.5) × Iso.S`, with `Iso.S = 0.97`; previous 24-unit radius 0.3107997m). The native chest cylinder is 0.530m high and grounded at the actual terrain support instead of inheriting the 2.2m resident/tree cylinder. It still uses the PROP layer, and the existing consumed-state path releases collision. The continuous lid sweep has 0.0129857m of radial clearance inside the new cylinder. The larger footprint is deliberate: enlarging only the visible model would let the open lid exceed its old collider. Chest centres, IDs, attack behavior, save data and one-time reward rules are unchanged. Area, arc and projectile target radii share the new 30-unit constant. Native projectile targeting uses the same finite 0.530m chest cylinder, not the old 1.66534m virtual actor capsule: visible-body shots hit, shots above the closed top plus projectile radius miss, and consumed chests are excluded.

`tests/cases/native_encounter_props.gd` checks every existing chest (town, field/memory and elevated waterfall reward), not only the first:
- mesh bounds, full-face winding, finite UVs, mobile triangle/surface budgets and unit-scale ownership;
- continuous hinge maximum plus 131 sampled poses inside the source/native circle;
- actual physics overlap against existing SOLID/PROP bodies, excluding only that chest's own blocker, for a conservative 0.80m-high cylinder covering all lid poses;
- actual terrain support and native collider radius/height/ground alignment;
- a clear player capsule approach and adjacent motor-driven walking arc around each placement;
- existing real attack, consumed lid state, one-time reward and collision release, cave transitions and source deletion.

The emitted `NATIVE_CHEST_PLACEMENT_METRICS` identifies each source index and obstruction name if any placement fails. Do not remove an obstruction, shrink collision or accept a model overlap merely to make the test pass. Any placement correction needs to preserve the raised reward route and source identity.

Acceptance requires the updated headless case and actual game browser images at native zoom 0.75 (the new displayed default 1), fixed 120° camera and existing light: portrait/landscape, closed/open and opposite-face views. The older capture evidence in `assets/data/native_encounter_props.json` predates the enlargement and is explicitly marked as historical. This source candidate has not yet been executed or visually accepted.

Numerical shot audit with the actual source constants: `PROJECTILE_LIFT = 34/(65×0.97) = 0.5392546m`. For a horizontal native segment from x−1 to x+1 through the chest centre, the 8-unit-radius body shot at y 0.25 hits at fraction 0.2539503, the normal 22-unit shot at y 0.5392546 hits the rounded lid rim at fraction 0.1633756, and an 8-unit shot at y 0.6535999 (closed top + projectile radius +0.02m) misses. Runtime tests derive these heights/radii from source constants rather than copying these audit figures.
