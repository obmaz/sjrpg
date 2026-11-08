class_name BagPanel
extends PanelFrame
## 모험가의 가방 (원본 EquipmentPanel): 착용 장비 · 보관함(24칸) · 탭 · 장착/잠금/판매,
## 마을 상인 곁에서는 상점(무기 · 방어구 · 부적 · 물약)으로 전환. 축복(수련)은 아직 없음.

const INV_TABS := ["전체", "신규", "무기", "방어구", "부적", "잠금"]
const SHOP_TABS := ["무기", "방어구", "부적", "물약", "축복"]
const SLOTS := ["weapon", "armor", "charm"]
const HEAL_PRICE := 80
const ENERGY_PRICE := 72
const POTION_BUNDLE := 2

var shopping := false
var can_shop := false
var tab := 0
var shop_tab := 0
var selected: Gear
var selected_offer := ""
var message := ""
var game: Node
var _new_items: Array[int] = []


func setup(start_in_shop: bool, g: Node) -> BagPanel:
	shopping = start_in_shop
	can_shop = start_in_shop
	game = g
	return self


func _ready() -> void:
	super._ready()
	if not shopping and not GameState.unseen.is_empty():
		tab = 1
		_new_items = GameState.unseen.duplicate()
	closed.connect(func(): GameState.save_game())
	_rebuild()


func _res() -> String:
	return GameState.class_info()["resource"]


func _rebuild() -> void:
	clear_body()
	for c in trailing.get_children():
		c.queue_free()
	for c in footer.get_children():
		c.queue_free()
	var gold_label := UiKit.label("● %s G" % HudArt.fmt(GameState.gold), 22, UiKit.GOLD, true)
	trailing.add_child(gold_label)
	if shopping:
		set_header("상점", "%s · 보관함 %d/%d" % [GameState.class_info()["name"], GameState.inventory.size(), Gear.CAPACITY])
		set_tabs(SHOP_TABS, shop_tab, func(i):
			shop_tab = i
			selected_offer = ""
			message = ""
			_rebuild()
			scroll.scroll_vertical = 0)
		_build_shop()
	else:
		set_header("장비 가방", "보관함 · %d/%d" % [GameState.inventory.size(), Gear.CAPACITY])
		set_tabs(INV_TABS, tab, func(i):
			tab = i
			selected = null
			if i == 1:
				_new_items = GameState.unseen.duplicate()
			_rebuild()
			scroll.scroll_vertical = 0)
		_build_inventory()
	if can_shop:
		add_footer("가방" if shopping else "상점", func():
			shopping = not shopping
			selected = null
			selected_offer = ""
			message = ""
			_rebuild(), false, 1.0)
	add_footer("모험 계속하기", func(): closed.emit(), true, 2.0)


# ───────────────────────── inventory ─────────────────────────

func _build_inventory() -> void:
	if tab != 1:
		body.add_child(_overview())
	var items := _filtered()
	if items.is_empty():
		var empty := UiKit.label(
			"확인하지 않은 새 장비가 없습니다" if tab == 1 else ("잠근 장비가 없습니다" if tab == 5 else "이 부위에 보관한 장비가 없습니다"),
			19, UiKit.MUTED)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.custom_minimum_size = Vector2(0, 90)
		body.add_child(empty)
	for g in items:
		body.add_child(_gear_row(g, false))
	if message != "":
		body.add_child(PanelFrame.wrap_label(message, 17, Color(0.7, 1, 0.8)))


func _filtered() -> Array[Gear]:
	var out: Array[Gear] = []
	var all := GameState.inventory.duplicate()
	all.reverse()
	for g in all:
		var keep := false
		match tab:
			0:
				keep = true
			1:
				keep = _new_items.has(g.serial) or GameState.unseen.has(g.serial)
			5:
				keep = g.locked or selected == g
			_:
				keep = g.slot() == SLOTS[tab - 2]
		if keep:
			out.append(g)
	return out


func _overview() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for slot in SLOTS:
		var cell := GearCell.new()
		cell.setup(GameState.equipped.get(slot), slot)
		cell.custom_minimum_size = Vector2(100, 100)
		var s: String = slot
		cell.pressed.connect(func():
			var g: Gear = GameState.equipped.get(s)
			if g != null:
				tab = 0
				selected = g
				_rebuild())
		row.add_child(cell)
		var pad := Button.new()
		pad.name = "Equipped_" + s
		pad.tooltip_text = str(Gear.SLOT_NAMES.get(s, s))
		pad.set_meta("gamepad_key", "equipped:" + s)
		pad.set_meta("gamepad_target", true)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.flat = true
		pad.disabled = GameState.equipped.get(s) == null
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			pad.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pad.pressed.connect(func(): cell.pressed.emit())
		cell.add_child(pad)
	var stats := VBoxContainer.new()
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_theme_constant_override("separation", PanelFrame.CARD_TEXT_GAP)
	box.add_child(stats)
	stats.add_child(UiKit.label("공격력 %s    방어 %s" % [HudArt.stat(GameState.attack_power()), HudArt.stat(GameState.defense())], 19))
	stats.add_child(UiKit.label("생명 %s    %s %s" % [HudArt.stat(GameState.max_hp()), _res(), HudArt.res(GameState.max_resource())], 19))
	var hint := UiKit.label("착용한 칸을 누르면 상세를 봅니다", 14, UiKit.MUTED)
	stats.add_child(hint)
	return box


# ───────────────────────── rows ─────────────────────────

func _gear_row(g: Gear, offer: bool, price := 0) -> Control:
	var expanded := (selected_offer == "gear-%d" % g.base["index"]) if offer else selected == g
	var card := PanelContainer.new()
	var style := UiKit.panel_style(UiKit.SURFACE_RAISED if expanded else UiKit.SURFACE, UiKit.GOLD if expanded else UiKit.EDGE, 12)
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	col.add_child(holder)
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_ALL
	holder.add_child(hit)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(top)
	var cell := GearCell.new()
	cell.setup(g, "")
	cell.custom_minimum_size = Vector2(100, 100)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(cell)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", PanelFrame.CARD_TEXT_GAP)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(text)
	var name_label := UiKit.label(g.display_name(), 21, g.color(), true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(name_label)
	var stat_label := UiKit.label(g.stats_text(_res()), 18, UiKit.TEXT)
	stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(stat_label)
	# Keep comparisons visible before expanding the equip/buy actions.
	var comparison := _compare_line(g)
	if comparison != "":
		var compare_label := UiKit.label(comparison, 16, Color(0.78, 0.92, 0.85))
		compare_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		compare_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(compare_label)
	var tags: Array[String] = []
	if offer:
		tags.append("%s G" % HudArt.fmt(price))
	else:
		if GameState.is_equipped(g):
			tags.append("장착 중")
		if g.locked:
			tags.append("잠금")
		if GameState.unseen.has(g.serial):
			tags.append("신규")
	if not GameState.can_equip(g):
		tags.append("%s 전용" % ("전사" if g.base["cls"] == "warrior" else "마법사"))
	if not tags.is_empty():
		var tag_label := UiKit.label(" · ".join(tags), 18, Color(1, 0.88, 0.5) if offer else Color(0.55, 0.95, 0.78))
		tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(tag_label)
	# The whole top row is the tap target (the action buttons below stay separate).
	hit.set_meta("gamepad_key", "offer-%d" % g.base["index"] if offer else "gear-%d" % g.serial)
	hit.tooltip_text = g.display_name()
	hit.pressed.connect(func():
		if offer:
			selected_offer = "" if expanded else "gear-%d" % g.base["index"]
		else:
			GameState.unseen.erase(g.serial)
			selected = null if expanded else g
		message = ""
		_rebuild())
	if expanded:
		col.add_child(_detail(g, offer, price))
	return card


func _compare_line(g: Gear) -> String:
	var cur: Gear = GameState.equipped.get(g.slot())
	if cur == null or cur == g:
		return ""
	var parts: Array[String] = []
	if g.slot() == "weapon":
		parts.append("공격 %s → %s" % [HudArt.stat(cur.attack()), HudArt.stat(g.attack())])
	else:
		parts.append("방어 %s → %s" % [HudArt.stat(cur.armor()), HudArt.stat(g.armor())])
		parts.append("생명 %s → %s" % [HudArt.stat(cur.health()), HudArt.stat(g.health())])
		if g.mana() > 0 or cur.mana() > 0:
			parts.append("%s %s → %s" % [_res(), HudArt.res(cur.mana()), HudArt.res(g.mana())])
	return "현재 장비와 비교: " + " · ".join(parts)


func _detail(g: Gear, offer: bool, price: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	if g.slot() == "weapon":
		var profile := g.melee_profile()
		box.add_child(PanelFrame.wrap_label("무기 근접 공격 · 사거리 %.1f걸음 · 타격 폭 %.0f° · 공격 간격 %.2f초 (일시 강화 제외)" % [profile["range"] / 40.0, rad_to_deg(profile["arc"]) * 2.0, profile["tempo"]], 15, UiKit.MUTED))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	if offer:
		var poor := GameState.gold < price
		var full := GameState.inventory.size() >= Gear.CAPACITY
		var buy := UiKit.button("구매 · %s G" % HudArt.fmt(price) if not (poor or full) else ("골드가 부족합니다" if poor else "보관함이 가득 찼습니다"), 20)
		buy.custom_minimum_size = Vector2(0, 70)
		buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buy.disabled = poor or full or not GameState.can_equip(g)
		buy.pressed.connect(func():
			GameState.gold -= price
			var bought := GameState.new_gear(g.base["id"], g.rarity, g.power, g.vitality, g.focus)
			GameState.add_gear(bought)
			message = "구매했습니다: %s" % bought.display_name()
			selected_offer = ""
			GameState.save_game()
			game.player.refresh_stats()
			_rebuild())
		actions.add_child(buy)
		return box
	var equipped := GameState.is_equipped(g)
	var equip := UiKit.button("착용 중" if equipped else ("착용" if GameState.can_equip(g) else "착용 불가"), 20)
	equip.custom_minimum_size = Vector2(0, 70)
	equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip.disabled = equipped or not GameState.can_equip(g)
	equip.pressed.connect(func():
		GameState.equip(g)
		message = "%s 착용" % g.display_name()
		game.player.refresh_stats()
		_rebuild())
	actions.add_child(equip)
	var lock := UiKit.button("잠금 해제" if g.locked else "잠금", 20)
	lock.custom_minimum_size = Vector2(0, 70)
	lock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lock.pressed.connect(func():
		g.locked = not g.locked
		_rebuild())
	actions.add_child(lock)
	var can_sell := not (g.locked or equipped)
	var sell := UiKit.button("판매 · %d G" % g.sale_value(), 20)
	sell.custom_minimum_size = Vector2(0, 70)
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell.disabled = not can_sell
	sell.pressed.connect(func():
		var value := g.sale_value()
		if GameState.sell(g):
			message = "%d G에 판매했습니다" % value
			selected = null
			game.player.refresh_stats()
			_rebuild())
	actions.add_child(sell)
	return box


# ───────────────────────── shop ─────────────────────────

func _shop_gear_ids() -> Array:
	var lv := GameState.level
	if GameState.hero_class == "warrior":
		var ids := ["longsword", "axe", "spear", "mace", "dualblades", "rapier", "throwingaxes"]
		if lv >= 3:
			ids.append_array(["katana", "flail", "javelin"])
		if lv >= 5:
			ids.append_array(["greatsword", "twinaxes", "runeblade", "halberd", "warhammer", "glaive", "falchion"])
		ids.append_array(["leather", "chainmail"])
		if lv >= 5:
			ids.append("plate")
		ids.append("amber")
		if lv >= 5:
			ids.append("fang")
		return ids
	var m := ["oakstaff", "frostwand", "stormrod"]
	if lv >= 5:
		m.append_array(["emberstaff", "crystalorb"])
	m.append_array(["silkrobe", "leather"])
	if lv >= 5:
		m.append("frostrobe")
	m.append("sapphire")
	if lv >= 5:
		m.append_array(["amber", "fang"])
	return m


func _build_shop() -> void:
	if shop_tab == 4:
		var gain := 5.0 * GameState.PLAYER_DAMAGE_SCALE
		body.add_child(_potion_offer("power", "무기 강화", "공격력 +%s · 수련 %d/%d" % [HudArt.stat(gain), GameState.attack_training_rank(), GameState.max_training_rank()], GameState.attack_training_cost(), GameState.attack_training_rank() >= GameState.max_training_rank()))
		body.add_child(_potion_offer("vitality", "생명 축복", "최대 생명 +%s · 수련 %d/%d" % [HudArt.stat(20.0), GameState.vitality_training_rank(), GameState.max_training_rank()], GameState.vitality_training_cost(), GameState.vitality_training_rank() >= GameState.max_training_rank()))
	elif shop_tab == 3:
		body.add_child(_potion_offer("heal", "치유 물약 ×%d" % POTION_BUNDLE, "생명 %s 회복 · 보유 %d개" % [HudArt.stat(55.0), GameState.potions], HEAL_PRICE))
		body.add_child(_potion_offer("energy", "%s 물약 ×%d" % [_res(), POTION_BUNDLE], "%s %s 회복 · 보유 %d개" % [_res(), HudArt.res(60.0), GameState.mana_potions], ENERGY_PRICE))
	else:
		for id in _shop_gear_ids():
			var b := Gear.def(id)
			if b["slot"] != SLOTS[shop_tab] or not Gear.usable(b, GameState.hero_class):
				continue
			var preview := Gear.make(0, id, 0, 0, 0, 0, GameState.level)
			body.add_child(_gear_row(preview, true, b["value"]))
	if message != "":
		body.add_child(PanelFrame.wrap_label(message, 17, Color(0.7, 1, 0.8)))


func _potion_offer(id: String, title: String, sub: String, price: int, maxed := false) -> Control:
	var expanded := selected_offer == id
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.SURFACE_RAISED if expanded else UiKit.SURFACE, UiKit.GOLD if expanded else UiKit.EDGE, 12))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	col.add_child(holder)
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	holder.add_child(hit)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(top)
	var icon := PotionCell.new()
	icon.energy = id == "energy"
	icon.kind = id
	icon.custom_minimum_size = Vector2(100, 100)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", PanelFrame.CARD_TEXT_GAP)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(text)
	var t := UiKit.label(title, 21, Color(0.95, 0.92, 0.8), true)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(t)
	var s := UiKit.label(sub, 18, UiKit.TEXT)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(s)
	var p := UiKit.label("%d G" % price, 17, Color(1, 0.88, 0.5))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(p)
	hit.set_meta("gamepad_key", "shop:" + id)
	hit.tooltip_text = title
	hit.pressed.connect(func():
		selected_offer = "" if expanded else id
		message = ""
		_rebuild())
	if expanded:
		var poor := GameState.gold < price
		var buy := UiKit.button(("구매 · %d G" % price) if not (poor or maxed) else ("수련 한계입니다 (레벨 3마다 +1)" if maxed else "골드가 부족합니다"), 20)
		buy.custom_minimum_size = Vector2(0, 70)
		buy.disabled = poor or maxed
		buy.pressed.connect(func():
			GameState.gold -= price
			match id:
				"heal":
					GameState.potions += POTION_BUNDLE
				"energy":
					GameState.mana_potions += POTION_BUNDLE
				"power":
					GameState.bonus_attack += 5.0
				"vitality":
					GameState.bonus_health += 20.0
					game.player.refresh_stats(true)
			message = "%s 구매 완료" % title
			GameState.save_game()
			_rebuild())
		col.add_child(buy)
	return card


## One equipment cell: rarity-tinted well + the item icon; tap to inspect.
class GearCell:
	extends Control
	signal pressed
	var gear: Gear
	var slot := ""

	func setup(g: Gear, s: String) -> void:
		gear = g
		slot = s
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
			pressed.emit()

	func _draw() -> void:
		var col := UiKit.EDGE if gear == null else gear.color()
		var rect := Rect2(Vector2.ZERO, size)
		draw_style_box(UiKit.panel_style(Color("151511"), Color(col, 0.8), 5), rect)
		if gear == null:
			var name: String = Gear.SLOT_NAMES.get(slot, "")
			draw_string(UiKit.BOLD_FONT, Vector2(0, size.y * 0.58), name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, UiKit.MUTED)
			return
		var inner := rect.grow(-6.0)
		GearArt.draw(self, gear.base, inner, Color.WHITE if GameState.can_equip(gear) else Color(0.5, 0.5, 0.5))
		if gear.weapon_level > 0:
			draw_rect(Rect2(3, 3, 52, 24), Color(0.08, 0.07, 0.05, 0.92), true)
			draw_string(UiKit.BOLD_FONT, Vector2(6, 23), "Lv.%d" % gear.weapon_level, HORIZONTAL_ALIGNMENT_LEFT, 48, 18, Color(0.93, 0.89, 0.8))
		if GameState.is_equipped(gear):
			draw_circle(Vector2(size.x - 12, 12), 8.0, Color(0.55, 0.9, 0.77))
		elif gear.locked:
			draw_circle(Vector2(size.x - 12, 12), 8.0, UiKit.GOLD)
		elif GameState.unseen.has(gear.serial):
			draw_circle(Vector2(size.x - 11, 11), 5.0, Color(0.9, 0.72, 0.35))


class PotionCell:
	extends Control
	var energy := false
	var kind := "heal"

	func _draw() -> void:
		var r := minf(size.x, size.y) / 2.0 - 2.0
		if kind == "power":
			HudArt.plaque(self, "swords", size / 2.0, r)
		elif kind == "vitality":
			HudArt.plaque(self, "potion", size / 2.0, r, Color(1.0, 0.8, 0.8))
		else:
			PotionArt.draw(self, size / 2.0, r, energy, -1)


func gamepad_back() -> bool:
	if selected != null or selected_offer != "":
		selected = null
		selected_offer = ""
		_rebuild()
		return true
	return false
