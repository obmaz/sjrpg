extends AnimationPlayer
## Test-only real animation track counter, retaining the native position postprocess.
var processed_keys := 0


func _post_process_key_value(animation: Animation, track: int, value: Variant, object_id: int, object_sub_idx: int) -> Variant:
	processed_keys += 1
	if animation.track_get_type(track) == Animation.TYPE_POSITION_3D and object_sub_idx >= 0:
		var skeleton := instance_from_id(object_id) as Skeleton3D
		if skeleton != null:
			var position: Vector3 = value
			return position * skeleton.motion_scale
	return value
