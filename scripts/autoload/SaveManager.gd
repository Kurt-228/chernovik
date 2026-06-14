extends Node
## Save/Load manager for normal game progress.
## Saves: WorldState entries, GameProgress flags, current scene, etc.
## Separate from MetaMemory (which stores completed-run summaries).

const SAVE_DIR := "user://saves/"
const SAVE_FILE := "user://saves/save_%d.json"
const QUICK_SAVE := "user://saves/quicksave.json"
const MAX_SAVES := 10

var current_save_slot: int = 0


func _ready() -> void:
	_ensure_save_dir()


func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)


## ── SAVE ───────────────────────────────────────────────────────────

func save_game(slot: int = 0) -> bool:
	_ensure_save_dir()

	var data := {
		"version":          WorldState.current_version,
		"edits_made":       WorldState.edits_made,
		"entries":          _serialize_entries(),
		"entry_order":      WorldState.entry_order.duplicate(),
		"edit_history":     WorldState.edit_history.duplicate(),
		"current_day":      GameProgress.current_day,
		"current_chapter":  GameProgress.current_chapter,
		"dialogue_seen":    GameProgress.dialogue_seen.duplicate(),
		"nina_met":         GameProgress.nina_met,
		"errors_appeared":  GameProgress.errors_appeared,
		"truth_revealed":   GameProgress.truth_revealed,
		"timestamp":        Time.get_unix_time_from_system(),
		"datetime":         Time.get_datetime_string_from_system(),
	}

	var path = SAVE_FILE % slot if slot > 0 else QUICK_SAVE
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] Cannot write to %s" % path)
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	current_save_slot = slot
	print("[SaveManager] Saved to slot %d (%s)" % [slot, path])
	return true


func quick_save() -> bool:
	return save_game(0)


## ── LOAD ───────────────────────────────────────────────────────────

func load_game(slot: int = 0) -> bool:
	var path = SAVE_FILE % slot if slot > 0 else QUICK_SAVE
	if not FileAccess.file_exists(path):
		print("[SaveManager] No save in slot %d" % slot)
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false

	var json = JSON.parse_string(file.get_as_text())
	file.close()

	if not json is Dictionary:
		push_error("[SaveManager] Corrupted save file: %s" % path)
		return false

	_deserialize_and_apply(json)
	current_save_slot = slot
	print("[SaveManager] Loaded slot %d" % slot)
	return true


func quick_load() -> bool:
	return load_game(0)


## ── HELPERS ────────────────────────────────────────────────────────

func _serialize_entries() -> Dictionary:
	var out := {}
	for key in WorldState.entries:
		var e = WorldState.entries[key]
		out[key] = {
			"text":   e.text,
			"active": e.active,
			"hidden": e.hidden,
			"locked": e.locked,
			"meta":   e.meta
		}
	return out


func _deserialize_and_apply(data: Dictionary) -> void:
	WorldState.current_version  = data.get("version", WorldState.STARTING_VERSION)
	WorldState.edits_made       = data.get("edits_made", 0)
	WorldState.entry_order       = data.get("entry_order", [])
	WorldState.edit_history      = data.get("edit_history", [])

	# Rebuild entries
	WorldState.entries.clear()
	var saved_entries = data.get("entries", {})
	for key in saved_entries:
		var e = saved_entries[key]
		WorldState.entries[key] = {
			"text":   e.get("text", ""),
			"active": e.get("active", true),
			"hidden": e.get("hidden", false),
			"locked": e.get("locked", false),
			"meta":   e.get("meta", {})
		}

	# Restore GameProgress
	GameProgress.current_day      = data.get("current_day", 1)
	GameProgress.current_chapter  = data.get("current_chapter", GameProgress.Chapter.PROLOGUE)
	GameProgress.dialogue_seen    = data.get("dialogue_seen", {})
	GameProgress.nina_met         = data.get("nina_met", false)
	GameProgress.errors_appeared  = data.get("errors_appeared", false)
	GameProgress.truth_revealed   = data.get("truth_revealed", false)
	GameProgress.first_edit_done  = WorldState.edits_made > 0


## Does a save exist?
func has_save(slot: int = 0) -> bool:
	var path = SAVE_FILE % slot if slot > 0 else QUICK_SAVE
	return FileAccess.file_exists(path)


## List save slots with metadata
func list_saves() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(MAX_SAVES + 1):
		var path = SAVE_FILE % i if i > 0 else QUICK_SAVE
		if FileAccess.file_exists(path):
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var json = JSON.parse_string(file.get_as_text())
				file.close()
				if json is Dictionary:
					result.append({
						"slot": i,
						"datetime": json.get("datetime", "?"),
						"edits": json.get("edits_made", 0),
						"version": json.get("version", 0)
					})
	return result


func delete_save(slot: int) -> void:
	var path = SAVE_FILE % slot if slot > 0 else QUICK_SAVE
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
