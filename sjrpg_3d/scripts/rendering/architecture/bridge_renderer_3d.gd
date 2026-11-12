class_name BridgeRenderer3D
extends RefCounted
## 다리 GLB의 로컬 원점은 기존 NativeBridgePlan의 갑판 시작점이다.


static func build(renderer: Node, parent: Node3D) -> Node3D:
	var bridge: Bridge = renderer.game.village.bridge
	var visual := ArchitectureSceneLibrary.create("bridge")
	var deck := bridge.deck_polygon()
	var a := WorldRenderer3D.ground_position(deck[0])
	var b := WorldRenderer3D.ground_position(deck[1])
	var c := WorldRenderer3D.ground_position(deck[3])
	assert(is_equal_approx(a.distance_to(b), float(visual.report["length_m"])))
	assert(is_equal_approx(a.distance_to(c), float(visual.report["width_m"])))
	visual.name = "NativeDetailedBridge"
	visual.transform = BridgePlan3D.frame(bridge)
	NativePlayerOcclusion.mark_object(visual)
	parent.add_child(visual)
	visual.set_meta("bridge_detail", visual.report)
	return visual
