class_name SaveTimeLabel
extends RefCounted
## Epochs stay UTC in saves; only the entry label receives a device-local offset.

static func with_offset(unix_seconds: float, offset_minutes: int) -> String:
	if not is_finite(unix_seconds) or unix_seconds <= 0.0:
		return "기존 모험"
	var local_seconds := int(unix_seconds) + offset_minutes * 60
	var date := Time.get_datetime_dict_from_unix_time(local_seconds)
	return "%02d-%02d %02d:%02d" % [date["month"], date["day"], date["hour"], date["minute"]]


static func device_offset(unix_seconds: float) -> int:
	if OS.has_feature("web") and is_finite(unix_seconds) and unix_seconds > 0.0:
		# Resolve the saved instant, rather than today's offset across a DST change.
		var offset: Variant = JavaScriptBridge.eval("-new Date(%d).getTimezoneOffset()" % (int(unix_seconds) * 1000), true)
		if (offset is float or offset is int) and is_finite(float(offset)):
			return int(offset)
	return int(Time.get_time_zone_from_system().get("bias", 0))


static func for_device(unix_seconds: float) -> String:
	return with_offset(unix_seconds, device_offset(unix_seconds))
