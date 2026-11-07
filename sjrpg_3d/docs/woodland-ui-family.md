# Woodland HUD family

The in-game avatar, consumables and four bottom actions share mature painted material planes, charcoal faces, thin bronze bevels and restrained ivory detail. HP and mana keep distinct red/violet silhouettes. Avoid photographic glass, glossy skin, flat generic pictograms and excessive filigree. Counts, cooldowns, skill points and button state remain live UI.

The actual generated PNG originals, exact prompts and input provenance are recorded in `assets/source/style/woodland-ui-generation.json`. This latest-brief generation used no attached image reference and is not recorded as user approval. The six 512-square cells share one atlas. Its opaque brown gutters are deliberately excluded by a circular 80-vertex UV polygon; the PNG is not falsely described as a transparent cutout. Both portrait cells use the same painted treatment and face scale.

`UiToneArt` owns atlas regions and shared bronze/ivory/charcoal accents. `PotionArt` and `MobileMenuArt` use these painted medallions; `HudArt` samples the two distinct portraits. Both generated atlases import with mipmaps. Their `CanvasTexture` wrappers use `LINEAR_WITH_MIPMAPS` sampling locally, preserving the filters of unrelated skill textures. The painted atlas owns the bevel: do not add duplicate etched menu rings or the previous flask socket frames. Idle icons use white modulation so the source silhouette retains its contrast.

## Mobile size and input

Potion and bottom menu illustrations have a minimum **40 CSS px diameter**, retaining a larger existing proportional size where applicable. Their existing input circles remain at least **44 CSS px**; increasing the illustration does not enlarge those circles or move their groups. Input positions use the actual CSS window width, including high-DPR screens, to keep neighboring targets separate and inside the safe area. Potion targets remain above the auxiliary fan.

Skill nodes use an 84-unit face plus an 8-unit input margin on each side: 100 logical units of hit width, at least 44 CSS px on the supported 320px portrait layout. Columns remain separate and rows are 128 logical units apart. Learned, locked, available and selected states use distinct bronze/ivory edges and muted passive labels, while the existing generated skill illustrations remain in place.

Skill learning/equipment buttons and settings zoom choices have minimum 44 CSS px input dimensions. Equipment buttons wrap through their existing flow container; the detail column retains its own scroll viewport.

## Live text and quantities

Canvas tier, rank, passive and equipped-slot text uses at least **12 CSS px**. Rank labels have measured opaque charcoal backings; prerequisite links route beside them rather than through the text. Long tier labels can stack the level prefix and number without moving the skill nodes.

Description, cost, effects, slot labels, guidance and detail button text also keep a 12 CSS px minimum after creation and rotation. Wrapped labels expand inside the existing detail scroll container. A disabled learning button retains its action label; its full unmet condition appears once beneath the button instead of repeating on the button with another dimming layer.

Potion quantities use compact lower-right contrast ribbons. Unspent skill points use matching upper-right ribbons. Both use measured text at least 12 CSS px high and keep all ribbon corners inside the existing input circle. A quantity greater than 999 displays `999+`; the underlying potion or skill-point quantity is unchanged. The skill-point badge remains hidden when there are no available points.

## Verification

`tests/cases/ui_tone.gd` checks delivered atlas dimensions, distinct class UVs, family-local mipmap sampling, actual detail/zoom button geometry and text size, and quantity ribbon bounds for small and large values. Browser verification additionally uses actual inventory/skills/journal/settings actions, portrait/landscape rotation, narrow 320px layouts, high-DPR input, and unchanged cooldown/potion behavior. Review the actual mobile captures for painted silhouette contrast and duplicate rim noise; passing geometry checks does not replace that visual review.
