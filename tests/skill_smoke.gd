extends Node
## Headless smoke test: casts every skill of both classes and opens every tree tab.
## Run: godot --headless res://tests/skill_smoke.tscn

var failures := 0


func _ready() -> void:
	await _run()
	print("SMOKE DONE failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _walk(player: Player, target: Vector2, frames: int) -> void:
	for i in frames:
		var d := target - player.position
		if d.length() < 6.0:
			break
		player.move_input = d.normalized()
		await get_tree().process_frame
	player.move_input = Vector2.ZERO


func _bag_test() -> void:
	for cls in ["warrior", "mage"]:
		GameState.new_game(cls)
		var game := preload("res://scripts/game.gd").new()
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
func _axis_audit() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.open("res://assets/data/village.json", FileAccess.READ).get_as_text())
	for key in data["frames"]:
		var s: Dictionary = data["sprites"][key]
		var poly: Array = data["frames"][key]["ground"]
		var bad := []
		for i in poly.size():
			var a: Array = poly[i]
			var b: Array = poly[(i + 1) % poly.size()]
			var pa := Vector2(a[0], a[1] * s["gvs"] + a[0] * s["gvk"])
			var pb := Vector2(b[0], b[1] * s["gvs"] + b[0] * s["gvk"])
			if pa.distance_to(pb) < 150.0:
				continue  # short porch steps are not ground-axis edges
			var t := rad_to_deg((pb - pa).angle())
			if t > 90.0:
				t -= 180.0
			if t < -90.0:
				t += 180.0
			if absf(absf(t) - 30.0) > 2.5:
				bad.append(snappedf(t, 0.1))
		print("axis audit %-6s %s" % [key, "ok" if bad.is_empty() else "FAIL %s" % str(bad)])
		if not bad.is_empty():
			failures += 1
	# Bridge deck edges are exactly +-30 by construction of the original measurement.
	var deck: Array = Bridge.DECK
	for i in 4:
		var d: Vector2 = deck[(i + 1) % 4] - deck[i]
		var t := absf(rad_to_deg(d.angle()))
		t = t if t <= 90.0 else 180.0 - t
		if absf(t - 30.0) > 2.5:
			print("axis audit bridge FAIL %.1f" % t)
			failures += 1
	if data["sprites"].has("chapel"):
		print("axis audit: off-plane chapel art must not ship")
		failures += 1


func _terrace_test() -> void:
	GameState.new_game("warrior")
	var game := preload("res://scripts/game.gd").new()
	add_child(game)
	await _frames(2)
	for e in game.enemies:
		e.queue_free()
	game.enemies.clear()
	var player: Player = game.player
	for lm in game.village.landmarks:
		var d: Dictionary = Landmark.data()[lm.index]
		var outline: Array = d["outline"]
		var center := Vector2.ZERO
		for p in lm.top:
			center += p
		center /= lm.top.size()
		var e: int = int(d["entrance"])
		var a: Vector2 = lm._pt(outline[e])
		var b: Vector2 = lm._pt(outline[(e + 1) % outline.size()])
		var mid := (a + b) / 2.0
		var start := mid + (mid - center).normalized() * 70.0
		player.position = start
		await _walk(player, mid, 120)
		await _walk(player, center, 360)
		var up := lm.contains_top(player.position)
		# From the opposite side, straight at a cliff edge: must stay off the top.
		var worst_ok := true
		for k in outline.size():
			if k == e:
				continue
			var p0: Vector2 = lm._pt(outline[k])
			var p1: Vector2 = lm._pt(outline[(k + 1) % outline.size()])
			var m := (p0 + p1) / 2.0
			if m.distance_to(mid) < 120.0 or (p1 - p0).length() < 60.0:
				continue
			var out_dir := (m - center).normalized()
			if not lm.contains_top(m - out_dir * 30.0):
				continue
			# Start on open ground in front of the edge (never inside a cliff face).
			var probe := Vector2.ZERO
			var found := false
			for dist in [60.0, 120.0, 200.0, 300.0]:
				var cand: Vector2 = m + out_dir * dist
				var clear := not lm.contains_top(cand)
				for q in game.village.solids:
					if Geometry2D.is_point_in_polygon(cand, q):
						clear = false
						break
				if clear:
					probe = cand
					found = true
					break
			if not found:
				continue
			player.position = probe
			await _walk(player, m - out_dir * 40.0, 300)
			if lm.contains_top(player.position):
				worst_ok = false
				print("   leak via edge %d (len %.0f) started %s ended %s" % [k, (p1 - p0).length(), player.position, "inside"])
		print("terrace %s: stairs %s, cliffs %s" % [Landmark.NAMES[lm.index], "ok" if up else "FAIL", "ok" if worst_ok else "LEAK"])
		if not up:
			failures += 1
	game.queue_free()
	await _frames(2)


func _quest_test() -> void:
	GameState.new_game("warrior")
	var game := preload("res://scripts/game.gd").new()
	add_child(game)
	await _frames(2)
	for e in game.enemies:
		e.queue_free()
	game.enemies.clear()
	var qr: QuestRuntime = game.quest_runtime
	var player: Player = game.player
	var level0 := GameState.level
	var gold0 := GameState.gold
	# 1) 제단 정화: accept, kill 18 near the altar, cleanse, report.
	qr.accept("roots")
	for i in Quests.ALTAR_KILL_GOAL:
		var e := Enemy.new()
		e.setup(game, "goblin", 1)
		e.position = qr.site("roots") + Vector2(80 + i, 0)
		game.world.add_child(e)
		game.enemies.append(e)
		e.take_damage(9999.0, null)
	await _frames(2)
	var blocked := qr.cleanse_blocked_reason()
	if blocked == "":
		qr.cleanse()
		qr.report("roots")
	print("quest roots: %s (%s)" % ["ok" if Quests.phase("roots") == "completed" else "FAIL", blocked])
	if Quests.phase("roots") != "completed":
		failures += 1
	# 2) 약초 배달.
	qr.accept("moon")
	qr.receive_parcel()
	qr.deliver()
	qr.report("moon")
	print("quest moon: %s" % ("ok" if Quests.phase("moon") == "completed" else "FAIL"))
	if Quests.phase("moon") != "completed":
		failures += 1
	# 3) 조사관 보호: lose once, retry, then win.
	qr.accept("sun")
	qr.start_protection()
	await _frames(6)
	Quests.state("sun")["defender_hp"] = 0.0
	await _frames(3)
	var failed := Quests.phase("sun") == "failed"
	qr.retry("sun")
	qr.start_protection()
	for i in 900:
		qr._wave_pause = 0.0
		for e in game.enemies:
			if e.is_threat and not e.dead:
				e.take_damage(99999.0, null)
		if Quests.state("sun")["defeated"] >= Quests.THREAT_COUNT:
			Quests.state("sun")["protected_for"] = Quests.PROTECT_SECONDS + 1.0
		await get_tree().process_frame
		if Quests.phase("sun") == "ready":
			break
	var won := Quests.phase("sun") == "ready"
	if won:
		qr.report("sun")
	print("quest sun: fail path %s, win path %s (defeated %d)" % ["ok" if failed else "FAIL", "ok" if won else "FAIL", Quests.state("sun")["defeated"]])
	if not failed or not won:
		failures += 1
	var paid := GameState.gold - gold0 == 120 + 80 + 300 and GameState.level > level0
	print("quest rewards: %s (gold +%d, level %d -> %d)" % ["ok" if paid else "FAIL", GameState.gold - gold0, level0, GameState.level])
	if not paid:
		failures += 1
	# 4) 파수꾼.
	GameState.stage_kills = Quests.STAGE_KILL_GOAL
	qr._boss_timer = 0.0
	await _frames(4)
	var boss: Enemy = null
	for e in game.enemies:
		if e.is_boss:
			boss = e
	print("boss summoned: %s" % ("ok" if boss != null else "FAIL"))
	if boss == null:
		failures += 1
	else:
		boss.take_damage(9999999.0, null)
		await _frames(100)
		var has_heart := false
		for g in GameState.inventory:
			if g.base["id"] == "sentinel":
				has_heart = true
		var cleared := GameState.boss_defeated and has_heart
		print("boss defeated: %s, victory panel %s" % ["ok" if cleared else "FAIL", "open" if game.hud.panel_open() else "NOT OPEN"])
		if not cleared:
			failures += 1
	# 5) Dialogue / journal panels build for every NPC.
	if game.hud.panel_open():
		game.hud.close_panel()
	for npc in ["수녀 엘린", "보급원 미라", "약초사 노아", "조사관 로웬", "촌장"]:
		game.hud.interact(npc)
		await _frames(2)
		game.hud.close_panel()
	game.hud.open_journal()
	await _frames(2)
	game.hud.close_panel()
	game.queue_free()
	await _frames(2)


func _bridge_test() -> void:
	GameState.new_game("warrior")
	var game := preload("res://scripts/game.gd").new()
	add_child(game)
	await _frames(2)
	for e in game.enemies:
		e.queue_free()
	game.enemies.clear()
	var player: Player = game.player
	var v: Village = game.village
	# Walk from the forecourt over the deck to the far bank.
	player.position = Iso.project(v.forecourt_g)
	for t in [0.0, 0.25, 0.5, 0.75, 1.0]:
		await _walk(player, v.bridge.axis_point(t), 240)
	var far := player.position.distance_to(v.bridge.axis_point(1.0)) < 40.0
	print("bridge crossing: %s" % ("ok" if far else "FAIL at %s" % player.position))
	if not far:
		failures += 1
	# From the near bank, walking straight into the river must be stopped.
	var start := v.forecourt_g + Vector2(350, -60)
	player.position = Iso.project(start)
	await _walk(player, Iso.project(start + Vector2(0, -460)), 300)
	var g := Iso.unproject(player.position)
	var moved := g.y < start.y - 40.0
	var wet := v.river_band.grow(-20.0).has_point(g)
	print("river blocks: %s (moved %.0f, v=%.0f, band top %.0f)" % ["FAIL in water" if wet or not moved else "ok", start.y - g.y, g.y, v.river_band.end.y])
	if not moved:
		failures += 1
	if wet:
		failures += 1
	game.queue_free()
	await _frames(2)


func _run() -> void:
	_axis_audit()
	await _terrace_test()
	await _quest_test()
	await _bridge_test()
	await _bag_test()
	for cls in ["warrior", "mage"]:
		GameState.new_game(cls)
		GameState.level = 60
		GameState.skill_points = 2000
		# Learn everything through the real rules (prerequisites first).
		var progress := true
		while progress:
			progress = false
			for s in GameState.skills():
				while GameState.learn(s["id"]):
					progress = true
		for s in GameState.skills():
			if GameState.rank(s["id"]) != int(s["limit"]):
				print("FAIL %s not maxed: %s" % [s["id"], GameState.learn_block_reason(s)])
				failures += 1
			if SkillDefs.get_def(s["id"]).is_empty():
				print("FAIL %s has no behaviour" % s["id"])
				failures += 1
			if SkillDefs.describe(s["id"], 1) == "":
				print("FAIL %s has no description" % s["id"])
				failures += 1
		var game := preload("res://scripts/game.gd").new()
		add_child(game)
		await _frames(2)
		var player: Player = game.player
		for s in GameState.skills():
			if not GameState.is_assignable(s):
				continue
			# Fresh enemies around the hero for every cast.
			for i in 4:
				var e := Enemy.new()
				e.setup(game, "goblin", 3)
				e.position = player.position + Vector2.from_angle(i * TAU / 4.0) * 90.0
				game.world.add_child(e)
				game.enemies.append(e)
			game.corpses.append({"pos": player.position + Vector2(40, 0), "time": 30.0, "used": false})
			GameState.assign_slot(1, s["id"])
			player.cooldowns.clear()
			player._attack_time = 0.0
			player.resource = player.resource_max
			player.hp = player.max_hp
			var ok := player.cast_slot(1)
			await _frames(40)
			print("cast %-18s %s" % [s["id"], "ok" if ok else "NOT CAST"])
			if not ok:
				failures += 1
		player.take_damage(5.0, game.enemies[0] if game.enemies.size() > 0 else null)
		player.try_roll()
		await _frames(30)
		game.hud.open_skill_tree()
		await _frames(2)
		var panel: SkillTreePanel = game.hud._panel
		for t in panel._tab_labels().size():
			panel._tab = t
			panel._refresh()
			for id in panel._tab_slots(t):
				panel._selected = id[0]
				panel._build_detail()
			await _frames(2)
		game.hud.close_panel()
		game.queue_free()
		await _frames(2)
		print("class %s done" % cls)
