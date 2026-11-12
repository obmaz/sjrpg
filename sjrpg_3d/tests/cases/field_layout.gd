extends TestCase
## 확장 필드의 실제 위치·충돌·지도·워프 진입점이 같은 탐험 동선을 사용한다.


func run() -> void:
	var game := await make_game()
	game.set_process(false)
	game.player.set_process(false)
	game.encounters.set_process(false)
	var village: Village = game.village
	var props: NativeTownProps3D = game.ortho_preview._town_props
	props.sync()
	var portal: IsoSprite = village.portal_sprites["town"]
	var visual: Node3D = props._entries[portal.get_instance_id()]["root"]
	var shown := SpatialWorld3D.projected(visual.position)
	print(
		"FIELD_GATE ",
		JSON.stringify(
			{
				"source": str(portal.position),
				"visual": str(shown),
				"interaction": str(game.exploration.gate_point("town")),
				"error": shown.distance_to(game.exploration.gate_point("town"))
			}
		)
	)
	check(
		"the only upright field-world gate belongs inside town",
		game.in_town(shown) and game.world.get_node_or_null("GuardianPortal") == null
	)
	check(
		"the shown town gate and interaction share a real base point",
		shown.distance_to(game.exploration.gate_point("town")) < 2
	)
	var bounds := Iso.poly_bounds(village.river.polygon)
	check(
		"river crosses both field boundaries outside the village",
		(
			bounds.position.x < ForestRegion.FIELD.position.x
			and bounds.end.x > ForestRegion.FIELD.end.x
		)
	)
	for corner: Vector2 in village.safe_zone:
		check(
			"town has a broad dry field before the river",
			(
				NativeGroundRelief.river_distance(
					Iso.unproject(corner) / 65, NativeGroundRelief.river_outline(village)
				)
				> 15
			)
		)
	for id: String in village.quest_sites:
		var ground := Iso.unproject(village.quest_sites[id])
		print("FIELD_QUEST ", id, " ", ground)
		check(
			"quest uses the expanded field rather than the village ring: " + id,
			ground.length() > 3500 and ForestRegion.FIELD.grow(-300).has_point(ground)
		)
	check(
		"early and middle objectives occupy distinct northern districts",
		(
			village.quest_sites["roots"].distance_to(village.quest_sites["moon"]) > 2000
			and Iso.unproject(village.quest_sites["roots"]).y < bounds.position.y
			and Iso.unproject(village.quest_sites["moon"]).y < bounds.position.y
		)
	)
	check(
		"late cave and guardian stand beyond the crossing",
		(
			Iso.unproject(village.quest_sites["sun"]).y > bounds.end.y
			and Iso.unproject(village.boss_point).y > bounds.end.y
		)
	)
	check(
		"the immediate village perimeter has its own truthful label",
		ForestRegion.area_name(Iso.project(Vector2(1500, 0))) == "마을 외곽"
	)
	check(
		"difficulty uses isotropic ground distance",
		(
			(
				ForestBalance.zone_at(Iso.project(Vector2(3500, 0)))
				== ForestBalance.zone_at(Iso.project(Vector2(0, 3500)))
			)
			and ForestBalance.zone_at(Iso.project(Vector2(8000, 1000))) == 3
		)
	)
	game.refresh_map()
	var markers := MapGeometry.markers(game)
	for marker: Dictionary in markers:
		if marker["id"] == "boss":
			check(
				"map guardian location follows the actual clearing",
				marker["pos"] == village.boss_point
			)
	var legacy := {
		"charges": 1,
		"recharge": 42.5,
		"initial_spawned": true,
		"members": [{"kind": "wolf", "level": 3, "hp": 12.0, "position": [10.0, 20.0]}]
	}
	EncounterRuntime._relocate_members(legacy, Vector2(5000, 6000))
	check(
		"old encounter members move with their site without losing health or charges",
		(
			legacy["members"][0]["position"] == [5000.0, 6000.0]
			and legacy["members"][0]["hp"] == 12
			and legacy["charges"] == 1
			and legacy["recharge"] == 42.5
		)
	)
	var saved: Array = legacy["members"].duplicate(true)
	EncounterRuntime._relocate_members(legacy, Vector2(5000, 6000))
	check("a second load cannot translate the same survivors again", legacy["members"] == saved)
	var edge := Iso.project(Vector2(10600, -3400))
	legacy["anchor"] = [edge.x, edge.y]
	legacy["members"][0]["position"] = [edge.x, edge.y]
	check(
		"a legitimate expanded-field survivor beyond the old coordinate cap can save",
		(
			edge.x > 10000
			and GameState._valid_save({"class": "warrior", "encounters": {"west": legacy}})
		)
	)
	legacy["anchor"] = "invalid"
	check(
		"optional relocation anchors are validated before loading",
		not GameState._valid_save({"class": "warrior", "encounters": {"west": legacy}})
	)
	game.queue_free()
	await _frames(2)
