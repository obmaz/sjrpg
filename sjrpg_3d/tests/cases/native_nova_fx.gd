extends TestCase
## 장식 링은 실제 소스 수명·일시정지를 읽고 최대24개 표시 노드만 보관한다.


func run() -> void:
	var game := await make_game()
	game.set_process(false)
	game.player.set_process(false)
	var renderer: WorldRenderer3D = game.world_renderer
	renderer.set_process(false)
	var fx: NovaEffects3D = renderer._nova_fx
	var reduced := Prefs.reduce_motion
	Prefs.set_reduce_motion(false)
	for index in NovaEffects3D.MAX_PULSES + 4:
		game.spawn_nova(game.player.position + Vector2(index, 0), 46, Color.WHITE, true)
	var sources := Effect.in_world(game.world).filter(func(source): return source.kind == "nova")
	fx.sync()
	check(
		"overlapping cues retain all sources but cap native pictures",
		sources.size() == 28 and fx.entries.size() == 24 and fx.builds == 24
	)
	var id: int = fx.entries.keys()[0]
	var node: MeshInstance3D = fx.entries[id]
	var transform := node.transform
	var color := (node.material_override as StandardMaterial3D).albedo_color
	get_tree().paused = true
	await _frames(3)
	fx.sync()
	check(
		"pause freezes real source age and ring appearance",
		(
			node.transform.is_equal_approx(transform)
			and (node.material_override as StandardMaterial3D).albedo_color == color
		)
	)
	get_tree().paused = false
	for source: Effect in sources:
		# 첫 표시 보호 프레임 뒤 정상 수명을 끝낸다.
		source._process(.01)
		source._process(source.life + .01)
	fx.sync()
	check(
		"expiry hides and pools every picture without retaining source nodes",
		fx.entries.is_empty() and fx._pool.size() == 24 and fx.builds == 24
	)
	game.spawn_nova(game.player.position, 46, Color.WHITE, true)
	fx.sync()
	check(
		"the next pulse reuses a bounded node and the common mesh",
		(
			fx.entries.size() == 1
			and fx.builds == 24
			and (fx.entries.values()[0] as MeshInstance3D).mesh == node.mesh
		)
	)
	Prefs.set_reduce_motion(reduced)
	game.queue_free()
	await _frames(2)
