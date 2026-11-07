extends TestCase
## Runtime atlas, class identity and real mobile hit geometry; browser verifies the actual pictures/actions.

func run() -> void:
	check("painted HUD atlas has its actual delivered dimensions", UiToneArt.icons().get_size() == Vector2(1536, 1024))
	check("painted avatars have their actual delivered dimensions", UiToneArt.portraits().get_size() == Vector2(1774, 887))
	var regions := {}
	for key in ["bag", "skills", "quests", "settings", "hp", "mp"]:
		var frame := UiToneArt.frame(key)
		check("each actual HUD region is a full distinct source cell", Rect2(Vector2.ZERO, UiToneArt.icons().get_size()).encloses(frame) and frame.size == Vector2(512, 512) and not regions.has(frame.position))
		regions[frame.position] = true
	var warrior := HudArt.portrait_uv("warrior")
	var mage := HudArt.portrait_uv("mage")
	check("class portraits remain separate and inside actual texture UVs", not warrior.intersects(mage) and Rect2(0, 0, 1, 1).encloses(warrior) and Rect2(0, 0, 1, 1).encloses(mage))
	check("real skill-node input supports a 44px phone target without neighboring overlap", (SkillTreePanel.NODE_SIDE + 16.0) / 2.25 >= 44.0 and (SkillTreePanel.TREE_MIN_WIDTH - SkillTreePanel.TIER_LABEL_WIDTH - 12.0) / 3.0 >= SkillTreePanel.NODE_SIDE + 16.0)
