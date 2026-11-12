class_name AimTargetRenderer3D
extends RefCounted
## 실제 대상 선택을 읽는 정적인 발치 링 하나. 조준·피해·물리를 바꾸지 않는다.
var renderer: WorldRenderer3D
var ring: MeshInstance3D
var target_id := 0


func setup(presenter: WorldRenderer3D) -> AimTargetRenderer3D:
	renderer = presenter
	ring = MeshInstance3D.new()
	ring.name = "CurrentAimTarget"
	ring.mesh = NovaEffects3D._ring()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.albedo_color = Color(0.86, 0.66, 0.37, 0.72)
	ink.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = ink
	ring.hide()
	renderer.stage.add_child(ring)
	return self


func sync() -> void:
	target_id = 0
	ring.hide()
	var game: Node = renderer.game
	if game.get_tree().paused or game.hud.panel_open():
		return
	var target := game.player.display_aim_target() as Enemy
	if (
		not is_instance_valid(target)
		or target.dead
		or target.is_queued_for_deletion()
		or target.get_parent() != game.world
	):
		return
	# 벽·높이 뒤로 막힌 대상에게 명중을 보장하는 듯한 표시를 하지 않는다.
	if not game.can_melee_reach(game.player.position, target.position):
		return
	target_id = target.get_instance_id()
	ring.position = renderer.actor_foot(target) + Vector3.UP * 0.055
	var radius := SpatialWorld3D.radius_metres(target.radius) + 0.12
	ring.scale = Vector3.ONE * radius
	ring.show()
