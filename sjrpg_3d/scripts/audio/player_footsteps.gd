class_name PlayerFootsteps
extends RefCounted
## 별도 이동 타이머 없이 실제 보행 애니메이션의 거리 위상에서만 접지음을 낸다.
const MAGE_CYCLE := 128.0
## 원본 run의 foot_l/foot_r 최저점: 위상0.0625/0.5625 (보존한 gait.json).
const MAGE_CONTACT_OFFSET := 8.0
const WARRIOR_CYCLE := TAU * 23.0
var contacts := 0
var last_surface := ""


func observe(player: Player, moved: float) -> void:
	if (
		moved <= 0.01
		or player.dead
		or player.warp_locked
		or player._roll_time > 0.0
		or player._attack_time > 0.0
	):
		return
	var half_cycle := (MAGE_CYCLE if player.is_mage else WARRIOR_CYCLE) * 0.5
	var offset := MAGE_CONTACT_OFFSET if player.is_mage else 0.0
	var previous := player._run_distance - moved
	if (
		floori((previous - offset) / half_cycle)
		== floori((player._run_distance - offset) / half_cycle)
	):
		return
	# 느린 프레임에 여러 접지를 건너도 한 번만 재생한다. 벽 정지·워프에는 호출되지 않는다.
	contacts += 1
	last_surface = surface_at(player.game, player.position)
	SoundFx.play("step_" + last_surface)


static func surface_at(game: Node, point: Vector2) -> String:
	if game.dungeon.active:
		return "stone"
	if Geometry2D.is_point_in_polygon(point, game.village.bridge.deck_polygon()):
		return "stone"
	for road: PackedVector2Array in game.village.map_roads:
		if Geometry2D.is_point_in_polygon(point, road):
			return "stone"
	var native := (
		CaveTrailPlan3D.frame(game.village).affine_inverse() * WorldRenderer3D.ground_position(point)
	)
	var local := Vector2(native.x, native.z)
	var trail := CaveTrailPlan3D.points(game.village)
	for index: int in trail.size() - 1:
		if (
			local.distance_to(
				Geometry2D.get_closest_point_to_segment(local, trail[index], trail[index + 1])
			)
			<= CaveTrailPlan3D.HALF_WIDTH
		):
			return "earth"
	return "grass"
