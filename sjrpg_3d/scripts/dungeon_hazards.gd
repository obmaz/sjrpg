class_name DungeonHazards
extends RefCounted
## 입구/귀환문을 비우고 선택 경로와 방의 보상 근처에 읽을 수 있는 주기형 장치를 둔다.
var game: Node
var traps: Array[DungeonTrap] = []
var clock := 0.0


func setup(source: Node) -> DungeonHazards:
	game = source
	var spikes := [
		Vector2(250, 0), Vector2(700, -500), Vector2(2160, 0), Vector2(3250, 500), Vector2(4450, 0)
	]
	for index in spikes.size():
		traps.append(
			DungeonTrap.new().setup(
				"spike_%d" % index, "spike", spikes[index], Vector2.DOWN, (index % 3) * .22
			)
		)
	var vents := [Vector2(520, -300), Vector2(1350, -300), Vector2(3050, -300), Vector2(3920, -300)]
	for index in vents.size():
		# 노즐 뒤의 두꺼운 지지판은 실제 암반 안으로 물려 있다. 입구는 바닥 쪽을 향한다.
		traps.append(
			DungeonTrap.new().setup(
				"flame_%d" % index,
				"flame",
				vents[index] + Vector2(0, 16.9),
				Vector2.DOWN,
				(index % 3) * .25
			)
		)
	return self


func tick(delta: float) -> void:
	if not game.dungeon.active or game.player.dead or game.get_tree().paused:
		return
	clock += delta
	var enemies: Array[Enemy] = []
	var snapshot_ready := false
	for trap in traps:
		var changed := trap.step(delta)
		if changed and trap.phase == DungeonTrap.Phase.WARNING and _near(trap, 8):
			SoundFx.play("prepare")
		if changed and trap.phase == DungeonTrap.Phase.ACTIVE and _near(trap, 8):
			SoundFx.play("fire" if trap.kind == "flame" else "weapon_draw")
		if not trap.dangerous():
			continue
		var player: Player = game.player
		if (
			not player.dead
			and player._invulnerable <= 0
			and not trap.hit_actors.has(player.get_instance_id())
		):
			var foot: Vector3 = game.spatial_world.actor_foot(player)
			if trap.contains_foot(foot, SpatialWorld3D.radius_metres(Player.RADIUS)):
				trap.hit_actors[player.get_instance_id()] = true
				player.take_damage(player.max_hp * .18)
				if not game.dungeon.active or player.dead:
					return
		# 적을 장치 쪽으로 유인하는 전술도 가능하다. 같은 분출에서는 각각 한 번만 맞는다.
		if not snapshot_ready:
			enemies = game.enemies.duplicate()
			snapshot_ready = true
		for enemy: Enemy in enemies:
			if (
				not is_instance_valid(enemy)
				or enemy.dead
				or trap.hit_actors.has(enemy.get_instance_id())
			):
				continue
			if trap.contains_foot(
				game.spatial_world.actor_foot(enemy), SpatialWorld3D.radius_metres(enemy.radius)
			):
				trap.hit_actors[enemy.get_instance_id()] = true
				enemy.take_damage(enemy.max_hp * (.05 if enemy.is_boss else .22), null)


func _near(trap: DungeonTrap, metres: float) -> bool:
	return (Iso.unproject(game.player.position - trap.position) / 65.0).length() < metres


func nearest() -> DungeonTrap:
	var result: DungeonTrap
	var distance := INF
	for trap in traps:
		var next: float = (Iso.unproject(game.player.position - trap.position) / 65.0).length()
		if next < distance and next < 5.0:
			distance = next
			result = trap
	return result
