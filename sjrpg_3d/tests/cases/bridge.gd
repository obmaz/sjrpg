extends TestCase
## 동문 밖 다리: 건널 수 있고 강은 막힘


func run() -> void:
	# 실제 공간 준비와 초기 적 배치가 끝난 뒤 걷기 검사를 시작한다.
	var game := await make_game("warrior")
	# 통행만 검사하는 동안 새로 생성되는 적의 공격이 걷기를 방해하지 않게 한다.
	game._spawn_timer = 1000000000.0
	game.encounters.set_process(false)
	var player: Player = game.player
	var v: Village = game.village
	# Walk from the forecourt over the deck to the far bank.
	player.position = Iso.project(v.forecourt_g)
	for t in [0.0, 0.25, 0.5, 0.75, 1.0]:
		await _walk(player, v.bridge.axis_point(t), 240)
		print("ART_AUDIT BRIDGE_WALK ", JSON.stringify({"t": t, "actual": str(player.position), "target": str(v.bridge.axis_point(t)), "hp": player.hp}))
	var far := player.position.distance_to(v.bridge.axis_point(1.0)) < 40.0
	print("bridge crossing: %s" % ("ok" if far else "FAIL at %s" % player.position))
	if not far:
		var spatial: SpatialWorld3D = game.spatial_world
		var body := spatial.register_actor(player, Player.RADIUS)
		for margin: float in [0.0, body.safe_margin]:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = (body.get_child(0) as CollisionShape3D).shape
			query.transform = body.global_transform
			query.transform.origin += SpatialWorld3D.native_point((v.bridge.axis_point(1.0) - player.position).normalized() * 4.0)
			query.collision_mask = body.collision_mask
			query.exclude = [body.get_rid()]
			query.margin = margin
			var contacts := []
			for hit: Dictionary in spatial.get_world_3d().direct_space_state.intersect_shape(query, 16):
				var collider: Node = hit["collider"]
				contacts.append({"name": str(collider.name), "bounds": str(Iso.poly_bounds(collider.get_meta("source_polygon", PackedVector2Array()))), "global_position": str(collider.global_position)})
			print("ART_AUDIT BRIDGE_CONTACTS ", JSON.stringify({"margin": margin, "contacts": contacts, "body": str(body.position)}))
	check("native bridge crossing reaches the far bank", far, "actual=%s target=%s hp=%s enemies=%s" % [player.position, v.bridge.axis_point(1.0), player.hp, game.enemies.size()])
	# From the near bank, walking straight into the river must be stopped.
	var start := v.forecourt_g + Vector2(350, -60)
	player.position = Iso.project(start)
	await _walk(player, Iso.project(start + Vector2(0, -460)), 300)
	var g := Iso.unproject(player.position)
	var moved := g.y < start.y - 40.0
	var wet := v.river_band.grow(-20.0).has_point(g)
	print("river blocks: %s (moved %.0f, v=%.0f, band top %.0f)" % ["FAIL in water" if wet or not moved else "ok", start.y - g.y, g.y, v.river_band.end.y])
	check("native river approach moves before meeting the bank", moved, "start=%s actual=%s" % [start, g])
	check("native river blocks entry into water", not wet, "actual=%s band=%s" % [g, v.river_band])
	game.queue_free()
	await _frames(2)
