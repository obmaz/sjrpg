class_name BlacksmithPanel
extends PanelFrame
## 대장간 (원본 blacksmith_panel + Progress.smithQuote/enhanceWeapon): 무기 레벨 강화.
## 비용 25 + 12×레벨 + 15×등급, 성공 확률은 무기 레벨과 내 레벨의 차이로 결정,
## 실패하면 선택한 무기가 사라집니다. 잠금 무기는 강화할 수 없습니다.

var game: Node
var selected: Gear
var message := ""


func setup(g: Node) -> BlacksmithPanel:
	game = g
	return self


static func chance(weapon_level: int, hero_level: int) -> float:
	var d := weapon_level - hero_level
	if d < 0:
		return 0.9
	match d:
		0:
			return 0.7
		1:
			return 0.6
		2:
			return 0.5
		3:
			return 0.4
	return 0.3


static func price(g: Gear) -> int:
	return ceili(25.0 + g.weapon_level * 12.0 + g.rarity * 15.0)


func _ready() -> void:
	super._ready()
	_rebuild()


func _weapons() -> Array[Gear]:
	var out: Array[Gear] = []
	for g in GameState.inventory:
		if g.slot() == "weapon" and GameState.can_equip(g):
			out.append(g)
	return out


func _rebuild() -> void:
	clear_body()
	for c in trailing.get_children():
		c.queue_free()
	for c in footer.get_children():
		c.queue_free()
	trailing.add_child(UiKit.label("● %s G" % HudArt.fmt(GameState.gold), 22, UiKit.GOLD, true))
	set_header("대장간", "무기 강화 · 제한 없는 도전")
	var weapons := _weapons()
	if weapons.is_empty():
		var l := UiKit.label("강화할 무기가 없습니다", 20, Color(0.7, 0.8, 0.76))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(0, 120)
		body.add_child(l)
	if selected != null and not GameState.inventory.has(selected):
		selected = null
	for g in weapons:
		body.add_child(_row(g))
	if message != "":
		body.add_child(PanelFrame.wrap_label(message, 19, Color(1, 0.88, 0.55)))
	add_footer("돌아가기", func(): closed.emit(), true)


func _row(g: Gear) -> Control:
	var expanded := selected == g
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.1, 0.2, 0.18, 0.95) if expanded else Color(0.07, 0.15, 0.14, 0.95), UiKit.GOLD if expanded else Color(0.24, 0.38, 0.34), 12))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	col.add_child(holder)
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.pressed.connect(func():
		selected = null if expanded else g
		message = ""
		_rebuild())
	holder.add_child(hit)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(top)
	var cell := BagPanel.GearCell.new()
	cell.setup(g, "")
	cell.custom_minimum_size = Vector2(100, 100)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(cell)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 0)
	top.add_child(text)
	var n := UiKit.label(g.display_name(), 21, g.color(), true)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(n)
	var tags: Array[String] = ["무기 Lv.%d" % g.weapon_level]
	if GameState.is_equipped(g):
		tags.append("장착 중")
	if g.locked:
		tags.append("잠금")
	var t := UiKit.label(" · ".join(tags), 18, Color(0.55, 0.95, 0.78))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(t)
	if expanded:
		if g.locked:
			col.add_child(PanelFrame.wrap_label("잠금 무기 · 가방에서 잠금을 해제하세요", 19, Color(1, 0.8, 0.5)))
			return card
		var ch := chance(g.weapon_level, GameState.level)
		var cost := price(g)
		col.add_child(PanelFrame.wrap_label("무기 레벨 %d → %d" % [g.weapon_level, g.weapon_level + 1], 21, Color(0.95, 0.92, 0.8)))
		col.add_child(PanelFrame.wrap_label("공격력 %s → %s" % [HudArt.stat(g.attack()), HudArt.stat(g.attack() + Gear.WEAPON_ATTACK_PER_LEVEL)], 20, Color(0.78, 0.92, 0.85)))
		col.add_child(PanelFrame.wrap_label("성공 %d%% · 비용 %d G · 내 레벨 %d" % [roundi(ch * 100.0), cost, GameState.level], 20, Color(1, 0.9, 0.6)))
		col.add_child(PanelFrame.wrap_label("무기 레벨이 내 레벨보다 높을수록 성공 확률이 낮아집니다. 실패 시 선택한 무기가 소멸합니다.", 17, Color(0.9, 0.62, 0.55)))
		var poor := GameState.gold < cost
		var go := UiKit.button("골드 부족 · %d G" % cost if poor else "강화 · %d G" % cost, 22)
		go.custom_minimum_size = Vector2(0, 76)
		go.disabled = poor
		go.pressed.connect(func(): _enhance(g, ch, cost))
		col.add_child(go)
	return card


func _enhance(g: Gear, ch: float, cost: int) -> void:
	if GameState.gold < cost or g.locked or not GameState.inventory.has(g):
		return
	GameState.gold -= cost
	GameState.unseen.erase(g.serial)
	if randf() < ch:
		g.weapon_level += 1
		message = "강화 성공 · 무기 Lv.%d" % g.weapon_level
		SoundFx.play("loot")
		Prefs.pulse("loot")
	else:
		var name := g.display_name()
		var was_equipped := GameState.is_equipped(g)
		GameState.inventory.erase(g)
		if was_equipped:
			GameState.equipped.erase("weapon")
			var best: Gear = null
			for w in GameState.inventory:
				if w.slot() == "weapon" and GameState.can_equip(w) and (best == null or w.attack() > best.attack()):
					best = w
			if best != null:
				GameState.equipped["weapon"] = best
		selected = null
		message = "%s 소멸 · 다른 무기를 선택하세요" % name
		SoundFx.play("hurt")
	game.player.refresh_stats()
	GameState.save_game()
	_rebuild()
