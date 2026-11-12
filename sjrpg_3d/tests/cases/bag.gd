extends TestCase
## 가방·상점·상자·수련·저장·설정·스킬 패널


func run() -> void:
	for cls in ["warrior", "mage"]:
		GameState.delete_save()
		GameState.new_game(cls)
		var game := preload("res://scripts/gameplay/game.gd").new()
		add_child(game)
		await _frames(2)
		for e in game.enemies:
			e.queue_free()
		game.enemies.clear()
		var player: Player = game.player
		# Starting kit as the original: weapon + 여행자의 옷, 3/2 potions, no gold.
		var ok := GameState.inventory.size() == 2 and GameState.equipped.has("weapon") and GameState.equipped.has("armor") and GameState.potions == 3 and GameState.mana_potions == 2 and GameState.gold == 0
		print("%s starting kit: %s (attack %s, hp %s)" % [cls, "ok" if ok else "FAIL", HudArt.stat(GameState.attack_power()), HudArt.stat(GameState.max_hp())])
		if not ok:
			failures += 1
		# Break every chest and verify rewards and the bag.
		var gold_before := GameState.gold
		for c in game.chests:
			game.break_chests_at(c.position, 5.0, player)
		var gear_count := GameState.inventory.size()
		print("chests broken -> inventory %d, gold %d" % [gear_count, GameState.gold - gold_before])
		if gear_count <= 2 or GameState.gold <= gold_before:
			failures += 1
		# Open the bag, walk through every tab, equip/lock/sell.
		game.hud.open_bag(true)
		await _frames(3)
		var bag: BagPanel = game.hud._panel
		for t in 6:
			bag.tab = t
			bag._rebuild()
			await _frames(1)
		bag.tab = 0
		# Both inventory and vendor comparisons must be readable without tapping.
		var current: Gear = GameState.equipped["weapon"]
		var candidate := GameState.new_gear(current.base["id"], 0, 1, 0, 0)
		var expected := "현재 장비와 비교: 공격 %s → %s" % [HudArt.stat(current.attack()), HudArt.stat(candidate.attack())]
		for offer in [false, true]:
			bag.selected = null
			bag.selected_offer = ""
			var row := bag._gear_row(candidate, offer, 100)
			check("%s collapsed %s comparison visible" % [cls, "shop" if offer else "inventory"], _comparison_count(row, expected) == 1)
			row.free()
			bag.selected = candidate
			bag.selected_offer = "gear-%d" % candidate.base["index"]
			row = bag._gear_row(candidate, offer, 100)
			check("%s expanded comparison not duplicated" % cls, _comparison_count(row, expected) == 1)
			row.free()
		bag.selected = null
		bag.selected_offer = ""
		var usable: Gear = null
		for g in GameState.inventory:
			if GameState.can_equip(g) and not GameState.is_equipped(g):
				usable = g
				break
		if usable != null:
			bag.selected = usable
			bag._rebuild()
			var before := GameState.attack_power()
			GameState.equip(usable)
			print("equip %s -> attack %s -> %s" % [usable.display_name(), HudArt.stat(before), HudArt.stat(GameState.attack_power())])
			usable.locked = true
			print("sell locked refused: %s" % ("ok" if not GameState.sell(usable) else "FAIL"))
			usable.locked = false
		var sellable: Gear = null
		for g in GameState.inventory:
			if not GameState.is_equipped(g) and not g.locked:
				sellable = g
				break
		if sellable != null:
			var gold := GameState.gold
			var good := GameState.sell(sellable)
			print("sell: %s (+%d G)" % ["ok" if good and GameState.gold > gold else "FAIL", GameState.gold - gold])
			if not good:
				failures += 1
		# Shop tabs and a purchase.
		GameState.gold = 500
		for t in 4:
			bag.shop_tab = t
			bag._rebuild()
			await _frames(1)
		var potions := GameState.potions
		bag.shop_tab = 3
		bag.selected_offer = "heal"
		bag._rebuild()
		GameState.gold -= BagPanel.HEAL_PRICE
		GameState.potions += BagPanel.POTION_BUNDLE
		await _frames(1)
		print("shop potion bundle: %s" % ("ok" if GameState.potions == potions + 2 else "FAIL"))
		# 축복 (수련): +5 attack / +20 health per rank, capped by level.
		var atk := GameState.attack_power()
		var hp0 := GameState.max_hp()
		GameState.bonus_attack += 5.0
		GameState.bonus_health += 20.0
		var trained := GameState.attack_power() > atk and absf(GameState.max_hp() - hp0 - 20.0) < 0.01 and GameState.attack_training_rank() == 1 and GameState.max_training_rank() == 1
		print("training: %s (cost %d / %d)" % ["ok" if trained else "FAIL", GameState.attack_training_cost(), GameState.vitality_training_cost()])
		if not trained:
			failures += 1
		bag.shop_tab = 4
		bag._rebuild()
		await _frames(1)
		# Save and reload keep gear and gold.
		GameState.save_game()
		var inv := GameState.inventory.size()
		var g0 := GameState.gold
		GameState.inventory.clear()
		GameState.equipped.clear()
		GameState.gold = 0
		var loaded := GameState.load_game() and GameState.inventory.size() == inv and GameState.gold == g0 and GameState.equipped.has("weapon")
		print("save/load gear: %s" % ("ok" if loaded else "FAIL"))
		if not loaded:
			failures += 1
		game.hud.close_panel()
		# Settings panel.
		game.hud.open_settings()
		await _frames(3)
		var settings: SettingsPanel = game.hud._panel
		Prefs.set_sound(false)
		settings._rebuild()
		Prefs.set_sound(true)
		settings._rebuild()
		await _frames(1)
		game.hud.close_panel()
		# Skill tree opens in the same frame scaffold.
		game.hud.open_skill_tree()
		await _frames(3)
		game.hud.close_panel()
		game.queue_free()
		await _frames(2)


## 120° 기준: 지면에 닿는 모든 원화는 보정 후 변 각도가 ±30°에서 2.5° 이내여야 합니다.


func _comparison_count(node: Node, expected: String) -> int:
	var count := 0
	if node is Label and node.text == expected:
		count += 1
		check("comparison permits row input", node.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	for child in node.get_children():
		count += _comparison_count(child, expected)
	return count
