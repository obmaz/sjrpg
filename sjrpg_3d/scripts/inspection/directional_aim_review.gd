class_name DirectionalAimReview
extends Node
## aim_preview=1 전용. 네 방향의 실제 적과 실제 조이스틱+공격 입력을 확인한다.
var game: Node
var foes: Array[Enemy] = []
var _serial := 0


func start(source: Node) -> void:
	game = source
	set_process(false)
	await get_tree().create_timer(1.5, false).timeout
	if game.hud.panel_open():
		game.hud.close_panel(false)
	game.set_process(false)
	game.encounters.set_process(false)
	game.quest_runtime.set_process(false)
	game.exploration.set_process(false)
	for foe: Enemy in game.enemies:
		foe.queue_free()
	game.enemies.clear()
	game.spatial_world.teleport_source_actor(
		game.player, game.village.point(Vector2(.5, 1.15)), Player.RADIUS
	)
	game.hud.controls.release_all()
	game.player.set_process(false)
	for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		var foe := Enemy.new()
		foe.setup(game, "wolf", 1)
		foe.position = game.player.position + direction * 80.0
		foe.hp = 100000.0
		foe.max_hp = foe.hp
		game.world.add_child(foe)
		game.enemies.append(foe)
		foe.set_process(false)
		foes.append(foe)
	game.player.facing = PI / 2.0
	game.player._assisted_facing = INF
	game.player.resource = game.player.resource_max
	_serial = game.player._action_serial
	game.inspection.focus_point = game.player.position
	game.camera.position = game._camera_focus()
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	game.hud._update_layout()
	game.hud.controls.refresh_layout()
	_publish(false)
	set_process(true)


func _process(delta: float) -> void:
	game.player._process(minf(delta, 1.0 / 30.0))
	if game.player._action_serial > _serial:
		_publish(true)
		set_process(false)


func _publish(cast: bool) -> void:
	var controls: TouchControls = game.hud.controls
	var button: Vector2 = controls._buttons["slot0"]["center"]
	var view: Vector2 = game.get_viewport_rect().size
	var stick := controls._stick_center
	var target: Enemy = game.player.display_aim_target()
	JavaScriptBridge.eval(
		(
			"window.__sjrpgAimReview = "
			+ JSON.stringify(
				{
					"ready": true,
					"cast": cast,
					"button": [button.x / view.x, button.y / view.y],
					"stick": [stick.x / view.x, stick.y / view.y],
					"drag": 36.0 * controls._unit / view.y,
					"up_target": foes[3].get_instance_id(),
					"target": target.get_instance_id() if target != null else 0,
					"facing": game.player.facing,
					"input": [game.player.move_input.x, game.player.move_input.y]
				}
			)
		)
	)
