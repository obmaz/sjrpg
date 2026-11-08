class_name NativeEnemySprites3D
extends RefCounted
## Generated 2D appearance over real 3D actors. Simulation owns every clock and lifetime.
const VARIANT := "cave_crawler"
const TEXTURE_PATH := "res://assets/art/monsters/cave_crawler.png"
const CORPSE_TEXTURE_PATH := "res://assets/art/monsters/cave_crawler_corpses.png"
const REFERENCE_BODY_HEIGHT := 1.30 * Ortho3DPreview.GROUND_PER_METER * Iso.S
const CONFIG_PATH := "res://assets/data/cave_crawler_sprite.json"
const FRAME_FACTOR := Ortho3DPreview.GROUND_PER_METER * Ortho3DPreview.PROJECTION_FACTOR
var preview: Node
var entries := {}
var corpses := {}
var _texture: Texture2D
var _corpse_texture: Texture2D
var _config: Dictionary = {}
static var _quad: QuadMesh
static var _shader: Shader


func setup(presenter: Node) -> NativeEnemySprites3D:
	preview = presenter
	return self


static func supports(enemy: Enemy) -> bool:
	return is_instance_valid(enemy) and str(enemy.get_meta("visual_variant", "")) == VARIANT


static func supports_corpse(corpse: Dictionary) -> bool:
	return str(corpse.get("visual_variant", "")) == VARIANT


func _ensure_art(fallen := false) -> bool:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if not parsed is Dictionary:
			push_error("Generated cave creature sprite metadata is missing or invalid")
			return false
		_config = parsed
	if _texture == null:
		_texture = load(TEXTURE_PATH) as Texture2D
	if _texture == null:
		return false
	if fallen and _corpse_texture == null:
		_corpse_texture = load(CORPSE_TEXTURE_PATH) as Texture2D
	if fallen and _corpse_texture == null:
		return false
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	if _shader == null:
		_shader = Shader.new()
		# Real depth testing remains enabled. Generated diffuse art is deliberately
		# a 2D appearance, not a lit volume or a rectangular shadow caster.
		_shader.code = Ortho3DPreview.CARD_CODE
	return true


func _columns(fallen := false) -> int:
	return maxi(1, int(_config.get("corpse_columns" if fallen else "columns", 2 if fallen else 4)))


func _rows(fallen := false) -> int:
	return maxi(1, int(_config.get("corpse_rows" if fallen else "rows", 2 if fallen else 4)))


func _direction(facing: float) -> int:
	# Sheet rows face the four diagonals in clockwise screen order: SE, SW, NW, NE.
	var sector := mini(3, floori(fposmod(facing, TAU) / (PI * 0.5)))
	var rows: Array = _config.get("direction_rows", [0, 1, 2, 3])
	return clampi(int(rows[sector]) if sector < rows.size() else sector, 0, _rows() - 1)


func _source_cell(enemy: Enemy) -> Vector2i:
	var column := 0
	if enemy._state in ["windup", "recover"]:
		column = int(_config.get("attack_column", _columns() - 1))
	elif enemy._state == "chase" or (enemy._state == "idle" and enemy._wander != Vector2.ZERO):
		var walk: Array = _config.get("walk_columns", [0, 1, 2, 3])
		if not walk.is_empty():
			column = int(walk[mini(walk.size() - 1, floori(fposmod(enemy._walk_cycle, 1.0) * walk.size()))])
	return Vector2i(clampi(column, 0, _columns() - 1), _direction(enemy.facing))


func _corpse_cell(corpse: Dictionary) -> Vector2i:
	var row := _direction(float(corpse.get("facing", 0.0)))
	var cells: Array = _config.get("corpse_cells", [])
	if row < cells.size() and cells[row] is Array and cells[row].size() >= 2:
		return Vector2i(clampi(int(cells[row][0]), 0, _columns(true) - 1), clampi(int(cells[row][1]), 0, _rows(true) - 1))
	return Vector2i(row % _columns(true), mini(_rows(true) - 1, floori(float(row) / _columns(true))))


func _pivot(cell: Vector2i, fallen := false) -> Vector2:
	var values: Array = _config.get("corpse_frame_pivots" if fallen else "frame_pivots", [])
	var index := cell.y * _columns(fallen) + cell.x
	if index < values.size() and values[index] is Array and values[index].size() >= 2:
		return Vector2(float(values[index][0]), float(values[index][1]))
	var pivot: Array = _config.get("corpse_pivot" if fallen else "pivot", [0.5, 0.8] if fallen else [0.5, 0.94])
	return Vector2(float(pivot[0]), float(pivot[1]))


func _dimensions(cell: Vector2i, source_height: float, fallen := false) -> Vector2:
	var texture: Texture2D = _corpse_texture if fallen else _texture
	var index := cell.y * _columns(fallen) + cell.x
	var aspect := (float(texture.get_width()) / _columns(fallen)) / (float(texture.get_height()) / _rows(fallen))
	if fallen:
		# The separate artwork already depicts a collapsed isometric body.
		# Keep that picture upright to camera: flattening it again doubles projection.
		var corpse_fractions: Array = _config.get("corpse_frame_width_fractions", [])
		var corpse_fraction: float = float(corpse_fractions[index]) if index < corpse_fractions.size() else float(_config.get("corpse_body_width_fraction", 0.8))
		var visible_width := float(_config.get("corpse_world_width", 1.6)) * maxf(1.0, source_height) / REFERENCE_BODY_HEIGHT
		var width := visible_width / maxf(0.01, corpse_fraction)
		return Vector2(width, width / aspect)
	var fractions: Array = _config.get("frame_body_fractions", [])
	var fraction: float = float(fractions[index]) if index < fractions.size() else float(_config.get("body_fraction", 0.8))
	var height := maxf(1.0, source_height) / (FRAME_FACTOR * maxf(0.01, fraction))
	return Vector2(height * aspect, height)


func _create(label: String, fallen := false) -> Dictionary:
	var card := MeshInstance3D.new()
	card.name = label
	card.mesh = _quad
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("atlas_texture", _corpse_texture if fallen else _texture)
	card.material_override = material
	preview.stage.add_child(card)
	return {"card": card, "material": material, "cell": Vector2i(-1, -1), "uniforms": {},
		"foot": Vector3.ZERO, "pivot": Vector2.ZERO, "fallen": fallen}


func _uniform(entry: Dictionary, key: String, value: Variant) -> void:
	var uniforms: Dictionary = entry["uniforms"]
	if uniforms.has(key) and uniforms[key] == value:
		return
	(entry["material"] as ShaderMaterial).set_shader_parameter(key, value)
	uniforms[key] = value


func _frame(entry: Dictionary, cell: Vector2i) -> void:
	if entry["cell"] == cell:
		return
	entry["cell"] = cell
	# Exact normalized quarters preserve the actual 1254px image's half-pixel cells.
	# Integer atlas-region truncation would accumulate drift on this generated sheet.
	var fallen: bool = entry["fallen"]
	var rect := Vector4(float(cell.x) / _columns(fallen), float(cell.y) / _rows(fallen), 1.0 / _columns(fallen), 1.0 / _rows(fallen))
	_uniform(entry, "atlas_rect", rect)
	_uniform(entry, "next_rect", rect)


func _place(entry: Dictionary, cell: Vector2i, height: float, foot: Vector3, basis: Basis, squash := Vector2.ONE, fallen := false) -> void:
	var dimensions := _dimensions(cell, height, fallen) * squash
	var pivot := _pivot(cell, fallen)
	var card: MeshInstance3D = entry["card"]
	card.global_transform = Transform3D(Basis(basis.x * dimensions.x, basis.y * dimensions.y, basis.z),
		foot + basis.x * ((0.5 - pivot.x) * dimensions.x) + basis.y * ((pivot.y - 0.5) * dimensions.y))
	entry["foot"] = foot
	entry["pivot"] = pivot


func sync() -> void:
	var current := {}
	var candidates: Array = preview.game.enemies.duplicate()
	for entry: Dictionary in entries.values():
		var fading: Node = (entry["owner"] as WeakRef).get_ref()
		if is_instance_valid(fading) and not candidates.has(fading):
			candidates.append(fading)
	for candidate in candidates:
		var enemy := candidate as Enemy
		if not supports(enemy) or enemy.is_queued_for_deletion() or enemy.get_parent() != preview.game.world:
			continue
		if not _ensure_art():
			continue
		var id := enemy.get_instance_id()
		current[id] = true
		if not entries.has(id):
			var fresh := _create("NativeCaveCrawler")
			fresh["owner"] = weakref(enemy)
			entries[id] = fresh
		var entry: Dictionary = entries[id]
		var held := preview.get_tree().paused or enemy.sprite.contact_hold > 0.0 or enemy._hitstop.remaining > 0.0
		var previous_cell: Vector2i = entry["cell"]
		var cell: Vector2i = previous_cell if held and previous_cell.x >= 0 else _source_cell(enemy)
		_frame(entry, cell)
		var foot: Vector3 = preview.actor_foot(enemy) + Ortho3DPreview.ground_position(enemy.sprite.position)
		_place(entry, cell, enemy.sprite.body_height, foot, preview.camera.global_transform.basis, enemy.sprite.squash_scale())
		var card: MeshInstance3D = entry["card"]
		card.visible = enemy.visible and enemy.sprite.visible
		var tint: Color = enemy.sprite.tint
		tint.a *= enemy.sprite.modulate.a * enemy.sprite.self_modulate.a
		_uniform(entry, "tint", tint)
		_uniform(entry, "flash_color", enemy.sprite.flash_tint)
		_uniform(entry, "flash_strength", enemy.sprite.flash)
	for id in entries.keys():
		if not current.has(id):
			(entries[id]["card"] as MeshInstance3D).hide()
			(entries[id]["card"] as MeshInstance3D).queue_free()
			entries.erase(id)
	_sync_corpses()


func _sync_corpses() -> void:
	var current := {}
	for corpse: Dictionary in preview.game.corpses:
		if not supports_corpse(corpse) or not _ensure_art(true):
			continue
		var source: Node = corpse.get("visual")
		if not is_instance_valid(source) or source.get_parent() != preview.game.world or source.is_queued_for_deletion():
			continue
		var id := source.get_instance_id()
		current[id] = true
		if not corpses.has(id):
			corpses[id] = _create("NativeCaveCrawlerCorpse", true)
		var entry: Dictionary = corpses[id]
		var cell := _corpse_cell(corpse)
		_frame(entry, cell)
		var at: Vector2 = corpse.get("pos", Vector2.ZERO)
		var foot := Ortho3DPreview.ground_position(at, preview.surface_height(at) + 0.014)
		_place(entry, cell, float(corpse.get("height", 62.0)), foot, preview.camera.global_transform.basis, Vector2.ONE, true)
		var alpha := CorpseArt.opacity(float(corpse.get("time", 0.0)), float(corpse.get("lifetime", 30.0)))
		_uniform(entry, "tint", Color(0.72, 0.72, 0.72, alpha))
		_uniform(entry, "flash_strength", 0.0)
		(entry["card"] as MeshInstance3D).visible = not bool(corpse.get("used", false)) and alpha > 0.0
	for id in corpses.keys():
		if not current.has(id):
			(corpses[id]["card"] as MeshInstance3D).hide()
			(corpses[id]["card"] as MeshInstance3D).queue_free()
			corpses.erase(id)


func snapshot() -> Dictionary:
	var sources := []
	for id in entries:
		var entry: Dictionary = entries[id]
		var card: MeshInstance3D = entry["card"]
		var foot: Vector3 = entry["foot"]
		var cell: Vector2i = entry["cell"]
		var pivot: Vector2 = entry["pivot"]
		var actual_pivot := card.global_transform * Vector3(pivot.x - 0.5, 0.5 - pivot.y, 0.0)
		sources.append({"id": id, "visible": card.visible, "cell": [cell.x, cell.y],
			"foot": [foot.x, foot.y, foot.z], "pivot_error": actual_pivot.distance_to(foot)})
	return {"count": entries.size(), "corpses": corpses.size(), "appearance": "2d", "physics": "3d",
		"texture_loaded": _texture != null, "corpse_texture_loaded": _corpse_texture != null, "texture_size": [_texture.get_width(), _texture.get_height()] if _texture != null else [],
		"shared_mesh": true, "sources": sources}
