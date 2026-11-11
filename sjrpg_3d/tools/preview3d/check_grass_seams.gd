extends Node
## 실제 Compatibility 셰이더에 이음새가 큰 진단 데이터를 넣어 교차점까지 GPU 검증한다.
## --headless 더미 렌더러 대신 DISPLAY가 있는 tools/godot.sh로 이 씬을 실행한다.
const SIZE := 1024


func _ready() -> void:
	if RenderingServer.get_rendering_device() != null or DisplayServer.get_name() == "headless":
		push_error("Compatibility 실제 렌더러로 실행해야 합니다.")
		get_tree().quit(1)
		return
	var images: Array[Image] = []
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			image.set_pixel(x, y, Color(float(x) / 127, float(y) / 127, 0.3))
	image.generate_mipmaps()
	for layer in 10:
		images.append(image)
	var texture := Texture2DArray.new()
	texture.create_from_images(images)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var shader := Shader.new()
	shader.code = (
		"shader_type canvas_item;\n"
		+ '#include "res://scripts/grass_variety.gdshaderinc"\n'
		+ "uniform bool habitat = false;\n"
		+ "void fragment() { vec2 p=UV*4.0-1.0; COLOR=vec4(habitat?"
		+ "grass_surface(p*2.56,0.0):grass_seamless(p,0.0,dFdx(p),dFdy(p)),1.0); }"
	)
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("grass_layers", texture)
	var rect := ColorRect.new()
	rect.size = Vector2(SIZE, SIZE)
	rect.material = material
	viewport.add_child(rect)
	var failed := false
	for habitat in [false, true]:
		material.set_shader_parameter("habitat", habitat)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var frame := viewport.get_texture().get_image()
		var maximum := 0.0
		var worst := Vector2i.ZERO
		for y in SIZE - 1:
			for x in SIZE - 1:
				var at := frame.get_pixel(x, y)
				for next in [frame.get_pixel(x + 1, y), frame.get_pixel(x, y + 1)]:
					var jump := maxf(absf(at.r - next.r), absf(at.g - next.g))
					if jump > maximum:
						maximum = jump
						worst = Vector2i(x, y)
		var okay := maximum < 0.065 and frame.get_pixel(200, 200).r > 0.01
		print(
			"GRASS_SEAM_GPU ",
			JSON.stringify(
				{
					"habitat": habitat,
					"maximum_jump": maximum,
					"worst": [worst.x, worst.y],
					"limit": 0.065,
					"pass": okay,
					"renderer": RenderingServer.get_video_adapter_name()
				}
			)
		)
		failed = failed or not okay
	get_tree().quit(1 if failed else 0)
