class_name ActorWarpFade
extends RefCounted


## 워프 빛과 별도로 배우 재질을 임시 소유한다. 준비/전환마다 실제 표면을 다시 읽는다.
class SurfaceSlot:
	extends RefCounted
	var mesh: MeshInstance3D
	var index: int
	var original: Material
	var fade: BaseMaterial3D
	var color: Color


class MeshState:
	extends RefCounted
	var mesh: MeshInstance3D
	var shadow: int
	var overlay: Material


var slots: Array[SurfaceSlot] = []
var smooth_fade := true
var _meshes: Array[MeshState] = []
var _actor: Node3D
var _visible := true
var _active := false


func prepare(actor: Node3D) -> void:
	_actor = actor
	_visible = actor.visible
	slots.clear()
	_meshes.clear()
	smooth_fade = true
	var retained := {}
	for child in actor.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var state := MeshState.new()
		state.mesh = mesh
		state.shadow = mesh.cast_shadow
		state.overlay = mesh.material_overlay
		_meshes.append(state)
		if mesh.mesh == null:
			continue
		if mesh.material_override != null:
			_add_slot(mesh, -1, mesh.material_override, mesh.material_override, retained)
		else:
			for surface in mesh.mesh.get_surface_count():
				_add_slot(
					mesh,
					surface,
					mesh.get_active_material(surface),
					mesh.get_surface_override_material(surface),
					retained
				)


func _add_slot(
	mesh: MeshInstance3D, index: int, source: Material, original: Material, retained: Dictionary
) -> void:
	# 임의 셰이더/다중 패스는 알파 계약을 추측하지 않고 배우 전체 숨김으로 전환한다.
	if not source is BaseMaterial3D or source.next_pass != null:
		smooth_fade = false
		return
	var key := source.get_instance_id()
	var fade: BaseMaterial3D = retained.get(key)
	if fade == null:
		fade = source.duplicate() as BaseMaterial3D
		fade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	retained[key] = fade
	var slot := SurfaceSlot.new()
	slot.mesh = mesh
	slot.index = index
	slot.original = original
	slot.fade = fade
	slot.color = (source as BaseMaterial3D).albedo_color
	slots.append(slot)


func sync(actor: Node3D, active: bool, opacity: float) -> void:
	if _active and (not active or actor != _actor):
		_restore()
		_active = false
	if not active:
		return
	if not _active:
		prepare(actor)
		if smooth_fade:
			for slot in slots:
				_set_material(slot, slot.fade)
		_active = true
	# 한 표면이라도 페이드 계약이 없으면 전체 배우가 동시에 사라진다.
	_actor.visible = _visible and (smooth_fade or opacity >= .5)
	for state in _meshes:
		if is_instance_valid(state.mesh):
			state.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			state.mesh.material_overlay = null
	if smooth_fade:
		for slot in slots:
			var ink := slot.color
			ink.a *= opacity
			slot.fade.albedo_color = ink


func _set_material(slot: SurfaceSlot, material: Material) -> void:
	if not is_instance_valid(slot.mesh):
		return
	if slot.index < 0:
		slot.mesh.material_override = material
	else:
		slot.mesh.set_surface_override_material(slot.index, material)


func _restore() -> void:
	if is_instance_valid(_actor):
		_actor.visible = _visible
	if smooth_fade:
		for slot in slots:
			_set_material(slot, slot.original)
	for state in _meshes:
		if is_instance_valid(state.mesh):
			state.mesh.cast_shadow = state.shadow
			state.mesh.material_overlay = state.overlay


func warmup_samples() -> Array:
	var samples: Array = []
	if smooth_fade:
		for slot in slots:
			samples.append({"mesh": slot.mesh.mesh, "ink": slot.fade})
	return samples
