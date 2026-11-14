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
	await _responsive_content()


## 120° 기준: 지면에 닿는 모든 원화는 보정 후 변 각도가 ±30°에서 2.5° 이내여야 합니다.


func _comparison_count(node: Node, expected: String) -> int:
	var count := 0
	if node is Label and node.text == expected:
		count += 1
		check("comparison permits row input", node.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	for child in node.get_children():
		count += _comparison_count(child, expected)
	return count


## Item actions, long quest statuses and vendor content must fit the actual body
## at cover-screen, landscape and open Fold aspect ratios.
func _responsive_content() -> void:
	GameState.new_game("warrior")
	GameState.gold = 1234567
	var viewport := SubViewport.new()
	viewport.size = Vector2i(344, 883)
	add_child(viewport)
	var bag := BagPanel.new()
	viewport.add_child(bag)
	bag.tab = 0
	bag.selected = GameState.equipped["weapon"]
	bag.selected.locked = true
	bag._rebuild()
	for dimensions in [Vector2i(344, 883), Vector2i(883, 344), Vector2i(768, 896), Vector2i(896, 768), Vector2i(800, 800), Vector2i(320, 568), Vector2i(568, 320)]:
		viewport.size = dimensions
		await _frames(8)
		check("inventory body fits scroll width %s" % dimensions, bag.body.size.x <= bag.scroll.size.x + 1.0)
		var actions := bag.body.find_child("EquipmentActions", true, false) as BoxContainer
		check("inventory actions remain available %s" % dimensions, actions != null and actions.get_child_count() == 3)
		if actions != null:
			var scale := UiMetrics.units_per_display_pixel(viewport)
			var previous: Button = null
			var bounds := bag.scroll.get_global_rect()
			for action: Button in actions.get_children():
				var rect := action.get_global_rect()
				check("equipment action fits body %s" % dimensions, rect.position.x >= bounds.position.x - 1.0 and rect.end.x <= bounds.end.x + 1.0)
				check("equipment action has a 44dp touch target %s" % dimensions, action.size.x >= 44.0 * scale and action.size.y >= 44.0 * scale)
				check("equipment action preserves full text width %s" % dimensions, action.size.x + 1.0 >= action.get_combined_minimum_size().x)
				if previous != null:
					check("equipment actions do not overlap %s" % dimensions, not rect.intersects(previous.get_global_rect()))
				previous = action
		bag.scroll.scroll_vertical = 100000
		await _frames(2)
		check("expanded equipment last action is reachable %s" % dimensions, bag.body.get_global_rect().end.y <= bag.scroll.get_global_rect().end.y + 1.0)
		bag.scroll.scroll_vertical = 0
	bag.queue_free()
	await _frames(2)
	var journal := JournalPanel.new()
	viewport.add_child(journal)
	journal.clear_body()
	journal.body.add_child(journal._bar("첫 파수꾼 · 숲길 정화", "NPC 의뢰를 해결하고 파수꾼을 쓰러뜨리면 제1장을 완료합니다.", 0.5, "서쪽 숲 공터에서 도전 · 의뢰 3개 완료 후 해금"))
	for dimensions in [Vector2i(344, 883), Vector2i(768, 896), Vector2i(896, 768), Vector2i(800, 800), Vector2i(320, 568)]:
		viewport.size = dimensions
		await _frames(6)
		check("long journal status fits body %s" % dimensions, journal.body.size.x <= journal.scroll.size.x + 1.0)
	viewport.queue_free()
	await _frames(2)
