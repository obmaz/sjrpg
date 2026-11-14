extends TestCase
## Three independent heroes, conservative migration and deletion that survives autosaves.

const ROOT := "user://tests/save-slots"


func run() -> void:
	var old_path := GameState.slot_path(1)
	var old_slot := GameState.active_slot
	var defaults := preload("res://scripts/state/game_state.gd").new()
	var default_path: String = ProjectSettings.globalize_path(defaults.slot_path(1))
	check("default slot storage belongs exclusively to the3D namespace", default_path.contains("/sjrpg_3d/") and not default_path.contains("/sjrpg_2d/") and defaults._legacy_path().get_base_dir() == defaults.slot_path(1).get_base_dir())
	defaults.free()
	DirAccess.make_dir_recursive_absolute(ROOT)
	_cleanup()
	GameState.select_slot(1)
	GameState.save_path = ROOT + "/three.json"
	var retired_slot := ROOT + "/three.slot4.json"
	_write(retired_slot, "retired hero bytes")
	check("there are exactly three initially empty slot summaries", GameState.slot_summaries().size() == 3 and _occupied() == 0)
	check("indices outside the three-slot limit cannot mutate storage", not GameState.select_slot(0) and not GameState.create_slot(4, "mage") and not GameState.delete_slot(-1) and GameState.active_slot == 1)
	check("invalid classes do not claim an empty slot", not GameState.create_slot(1, "unknown") and _occupied() == 0)
	check("retired fourth-slot files stay untouched by summaries and rejected mutations",
		not GameState.delete_slot(4) and not GameState.select_slot(4)
		and FileAccess.get_file_as_string(retired_slot) == "retired hero bytes")
	_check_create_failure()
	var classes := ["warrior", "mage", "warrior"]
	for slot in range(1, GameState.MAX_SAVE_SLOTS + 1):
		check("create hero in slot %d" % slot, GameState.create_slot(slot, classes[slot - 1]))
		GameState.gold = slot * 100
		GameState.level = slot + 2
		GameState.xp = slot * 3
		GameState.location_mode = "cave" if slot == 3 else "forest"
		GameState.opened_chests.assign([slot])
		GameState.quests = {"roots": {"phase": "completed" if slot == 2 else "offered"}}
		GameState.inventory[0].weapon_level = slot
		check("save independent progress in slot %d" % slot, GameState.save_game())
	check("three occupied slots refuse a fourth and implicit replacement", _occupied() == 3 and not GameState.create_slot(1, "mage") and not GameState.new_game("warrior") and not GameState.create_slot(4, "warrior"))
	for slot in range(1, GameState.MAX_SAVE_SLOTS + 1):
		var before := FileAccess.get_file_as_string(GameState.slot_path(slot))
		check("selecting a slot does not permit a stale hero autosave %d" % slot, GameState.select_slot(slot) and not GameState.save_game() and FileAccess.get_file_as_string(GameState.slot_path(slot)) == before)
		check("continue restores each slot's class and complete hero progress %d" % slot, GameState.load_game() and GameState.hero_class == classes[slot - 1] and GameState.gold == slot * 100 and GameState.level == slot + 2 and GameState.xp == slot * 3 and GameState.opened_chests == [slot] and GameState.inventory[0].weapon_level == slot)
		check("quest state stays with its own hero %d" % slot, Quests.phase("roots") == ("completed" if slot == 2 else "offered"))
	var summaries := GameState.slot_summaries()
	check("summary exposes saved class, level, location and Unix timestamp", summaries[2]["class"] == "warrior" and summaries[2]["level"] == 5 and summaries[2]["location"] == "cave" and float(summaries[2]["timestamp"]) > 0 and not summaries[2]["backup"])
	check("previewing summaries never changes the live hero", GameState.active_slot == 3 and GameState.gold == 300 and GameState.save_game())
	_check_recovery_and_delete()
	_check_migration()
	_cleanup()
	GameState.select_slot(1)
	GameState.save_path = old_path
	GameState.select_slot(old_slot)


func _occupied() -> int:
	var count := 0
	for summary in GameState.slot_summaries():
		if summary["occupied"]:
			count += 1
	return count


func _check_create_failure() -> void:
	var old_path := GameState.slot_path(1)
	var missing_parent := ROOT.path_join("missing-parent")
	GameState.save_path = missing_parent.path_join("failed.json")
	check("initial creation reports an unwritable destination", not GameState.create_slot(1, "mage") and not GameState.save_error.is_empty() and not GameState.has_save_files())
	DirAccess.make_dir_recursive_absolute(missing_parent)
	check("a failed creation cannot autosave after storage becomes writable", not GameState.save_game() and not GameState.has_save_files())
	check("an explicit retry can create the hero and authorize later saves", GameState.create_slot(1, "mage") and GameState.save_game())
	GameState.delete_save()
	DirAccess.remove_absolute(missing_parent)
	GameState.save_path = old_path
	GameState.select_slot(1)


func _check_recovery_and_delete() -> void:
	GameState.select_slot(2)
	GameState.load_game()
	GameState.gold = 222
	GameState.save_game()
	_write(GameState.save_path, "{corrupt")
	var primary := GameState.save_path
	var summary: Dictionary = GameState.slot_summaries()[1]
	check("slot summary recognizes its own recoverable backup", summary["occupied"] and summary["valid"] and summary["backup"])
	check("corruption recovers only the selected hero's backup", GameState.load_game() and GameState.loaded_backup and GameState.hero_class == "mage" and GameState.gold == 200)
	GameState.gold = 223
	check("recovered hero can save without replacing its good backup with corruption", GameState.save_game() and int(SaveStore._read_one(primary + ".bak")["gold"]) == 200)
	_write(primary + ".tmp", "{interrupted")
	_write(primary + ".bak.tmp", "{interrupted")
	_write(primary + ".keep", "unrelated")
	var other_bytes := FileAccess.get_file_as_bytes(GameState.slot_path(1))
	check("deleting an active hero succeeds", GameState.delete_slot(2))
	check("deleted hero cannot return through a delayed autosave or continue", not GameState.save_game() and not GameState.load_game() and not GameState.has_save_files())
	check("deletion removes only known slot files and leaves other heroes untouched", FileAccess.get_file_as_string(primary + ".keep") == "unrelated" and FileAccess.get_file_as_bytes(GameState.slot_path(1)) == other_bytes and not FileAccess.file_exists(primary + ".bak") and not FileAccess.file_exists(primary + ".tmp") and not FileAccess.file_exists(primary + ".bak.tmp"))
	check("an explicitly deleted slot may hold a new hero", GameState.create_slot(2, "warrior") and GameState.gold == 0 and GameState.opened_chests.is_empty())
	check("deleting another slot preserves the active hero's save session", GameState.delete_slot(3) and GameState.active_slot == 2 and GameState.save_game())
	_write(GameState.slot_path(3) + ".tmp", "{incomplete")
	summary = GameState.slot_summaries()[2]
	check("an interrupted-only slot is occupied and requires deletion", summary["occupied"] and not summary["valid"] and not GameState.create_slot(3, "mage"))
	GameState.select_slot(3)
	check("failed load cannot authorize an overwrite of an unreadable slot", not GameState.load_game() and not GameState.save_game())
	GameState.delete_slot(3)


func _check_migration() -> void:
	GameState.select_slot(1)
	GameState.save_path = ROOT + "/guardian_save_slot_1.json"
	var legacy := ROOT + "/guardian_save.json"
	var legacy_primary := JSON.stringify({"class": "mage", "level": 9, "gold": 999})
	var legacy_backup := JSON.stringify({"class": "mage", "level": 8, "gold": 888})
	_write(legacy, legacy_primary)
	_write(legacy + ".bak", legacy_backup)
	var unrelated := ROOT + "/2d-save.json"
	_write(unrelated, "2D sentinel")
	var summaries := GameState.slot_summaries()
	check("legacy primary and backup migrate byte-for-byte into slot one", FileAccess.get_file_as_string(GameState.slot_path(1)) == legacy_primary and FileAccess.get_file_as_string(GameState.slot_path(1) + ".bak") == legacy_backup and summaries[0]["valid"] and summaries[0]["timestamp"] == 0.0)
	check("migration leaves legacy originals and unrelated namespace files unchanged", FileAccess.get_file_as_string(legacy) == legacy_primary and FileAccess.get_file_as_string(legacy + ".bak") == legacy_backup and FileAccess.get_file_as_string(unrelated) == "2D sentinel")
	_write(GameState.slot_path(1), "{damaged")
	check("migrated backup remains recoverable", GameState.load_game() and GameState.loaded_backup and GameState.gold == 888)
	GameState.gold = 777
	GameState.save_game()
	_write(legacy, JSON.stringify({"class": "warrior", "gold": 1}))
	check("repeated migration never overwrites occupied slot progress", GameState.slot_summaries()[0]["class"] == "mage" and GameState.load_game() and GameState.gold == 777)
	check("delete migrated hero leaves a durable receipt", GameState.delete_slot(1) and not GameState.save_game() and not GameState.slot_summaries()[0]["occupied"])
	var reopened := preload("res://scripts/state/game_state.gd").new()
	reopened.save_path = ROOT + "/guardian_save_slot_1.json"
	check("a new process cannot resurrect a deleted hero from legacy originals", not reopened.slot_summaries()[0]["occupied"] and not reopened.load_game() and reopened.create_slot(1, "warrior"))
	reopened.free()
	# A pre-existing destination always wins, including when its data is unreadable.
	GameState.save_path = ROOT + "/occupied_slot_1.json"
	_write(ROOT + "/occupied.json", legacy_primary)
	_write(GameState.save_path, "{belongs to player")
	check("migration never replaces an occupied corrupt destination", not GameState.slot_summaries()[0]["valid"] and FileAccess.get_file_as_string(GameState.save_path) == "{belongs to player" and not GameState.create_slot(1, "mage"))
	# Resume a staged migration with its backup already copied before interruption.
	GameState.save_path = ROOT + "/pending_slot_1.json"
	_write(ROOT + "/pending.json", legacy_primary)
	_write(ROOT + "/pending.json.bak", legacy_backup)
	_write(GameState.save_path + ".bak", legacy_backup)
	_write(GameState.save_path + ".migration", JSON.stringify({"version": 1, "state": "pending"}))
	check("interrupted migration resumes missing files without changing its copied backup", GameState.slot_summaries()[0]["valid"] and FileAccess.get_file_as_string(GameState.save_path) == legacy_primary and FileAccess.get_file_as_string(GameState.save_path + ".bak") == legacy_backup)
	GameState.save_path = ROOT + "/corrupt_slot_1.json"
	_write(ROOT + "/corrupt.json", "{original damage")
	_write(ROOT + "/corrupt.json.bak", legacy_backup)
	check("a corrupted legacy primary migrates with its recoverable backup", GameState.slot_summaries()[0]["backup"] and GameState.load_game() and GameState.gold == 888 and FileAccess.get_file_as_string(ROOT + "/corrupt.json") == "{original damage")
	GameState.save_path = ROOT + "/unreadable_slot_1.json"
	_write(ROOT + "/unreadable.json", "{unreadable original")
	check("an unreadable legacy save still reserves its migrated slot", GameState.slot_summaries()[0]["occupied"] and not GameState.slot_summaries()[0]["valid"] and not GameState.create_slot(1, "warrior"))
	check("explicit deletion frees unreadable migrated saves without reimporting them", GameState.delete_slot(1) and not GameState.slot_summaries()[0]["occupied"] and GameState.create_slot(1, "warrior"))


func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _cleanup() -> void:
	# Only this dedicated fixture directory; never inspect or mutate edition save roots.
	var missing_parent := ROOT.path_join("missing-parent")
	if DirAccess.dir_exists_absolute(missing_parent):
		for name in DirAccess.get_files_at(missing_parent):
			DirAccess.remove_absolute(missing_parent.path_join(name))
		DirAccess.remove_absolute(missing_parent)
	for name in DirAccess.get_files_at(ROOT):
		DirAccess.remove_absolute(ROOT.path_join(name))
