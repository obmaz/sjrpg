# Woodland HUD family

The in-game avatar, consumables and four bottom actions share painted material planes, charcoal faces, thin bronze bevels and restrained ivory detail. HP and mana keep distinct red/violet silhouettes. Counts, cooldowns, skill points and button state remain live UI.

The actual generated PNG originals and exact unreferenced-input prompts are recorded in assets/source/style/woodland-ui-generation.json. This latest-brief generation used no attached image reference and is not recorded as user approval. The six 512-square cells share one atlas. Its opaque brown gutters are deliberately excluded by a circular 80-vertex UV polygon; the PNG is not falsely described as a transparent cutout. Both portrait cells use the same painted treatment and face scale.

UiToneArt owns atlas regions and shared bronze/ivory/charcoal accents. PotionArt and MobileMenuArt use these painted medallions; HudArt samples the two distinct portraits. SkillTreePanel keeps learned/locked/selected/available semantics with restrained bronze/ivory edges and muted passive labels. Existing generated skill illustrations remain in place.

Potion and bottom menu art retain their visual radii. The input circles grow to at least 44 CSS pixels using actual window scale; their centers are repacked to prevent overlap and keep the last circle inside the safe bottom. Potion targets are raised above the auxiliary fan. Skill nodes use an 84-unit face plus the existing 8-unit hit inset on each side (100-unit hit width), separated columns and 128-unit rows. The browser harness checks this in 320px portrait and short landscape, along with actual inventory/skills/journal/settings actions and unchanged cooldown/potion behavior.
