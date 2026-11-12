class_name ChapelGarden3D
extends RefCounted
## 기존 예배당 정원을 공용 판석·식생 배칭으로 표시한다.


static func build(renderer: Node) -> Dictionary:
	return GardenDetailRenderer3D.build(
		renderer,
		ChapelGardenPlan3D.pavers(renderer.game.village),
		ChapelGardenPlan3D.plant_positions(renderer.game.village),
		"ChapelGarden",
		"chapel_garden"
	)
