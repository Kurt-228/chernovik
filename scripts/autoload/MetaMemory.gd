extends Node
## Meta-progress — remembers past playthroughs.
## Characters can reference events from previous runs.
##
## EVENT NAMING CONVENTION (unified):
##   verb_object  —  erased_lera, removed_crime, destroyed_school, etc.
## Never raw key names like "lera_exists_removed".

const SAVE_DIR := "user://meta/"
const RUNS_FILE := "user://meta/runs.json"
const MAX_REMEMBERED_RUNS := 20

var runs: Array[Dictionary] = []
var current_run_events: Array[String] = []
var current_run_endings: Array[String] = []


func _ready() -> void:
	_load_runs()


func _load_runs() -> void:
	if not DirAccess.dir_exists_absolute("user://meta"):
		DirAccess.make_dir_absolute("user://meta")

	if FileAccess.file_exists(RUNS_FILE):
		var file = FileAccess.open(RUNS_FILE, FileAccess.READ)
		if file:
			var json = JSON.parse_string(file.get_as_text())
			if json is Array:
				runs = json
			file.close()
	print("[MetaMemory] Loaded %d previous runs" % runs.size())


func _save_runs() -> void:
	var file = FileAccess.open(RUNS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(runs, "\t"))
		file.close()


## Record event using unified naming: verb_object
func record_event(event_id: String) -> void:
	if event_id not in current_run_events:
		current_run_events.append(event_id)
	print("[MetaMemory] Event: %s" % event_id)


func record_ending(ending_id: String) -> void:
	if ending_id not in current_run_endings:
		current_run_endings.append(ending_id)


## Save run to meta-history
func save_run() -> void:
	if current_run_events.is_empty() and current_run_endings.is_empty():
		return

	var summary := {
		"timestamp":       Time.get_unix_time_from_system(),
		"datetime":        Time.get_datetime_string_from_system(),
		"version":         WorldState.current_version,
		"edits_made":      WorldState.edits_made,
		"events":          current_run_events.duplicate(),
		"endings":         current_run_endings.duplicate(),
		"entries_at_end":  WorldState.entries.keys().size()
	}

	runs.append(summary)
	if runs.size() > MAX_REMEMBERED_RUNS:
		runs.pop_front()

	_save_runs()
	print("[MetaMemory] Run saved: %d events, %d endings" % [summary.events.size(), summary.endings.size()])


## Get random past event for NPC dialogue
func get_random_past_event(exclude_current: Array[String] = []) -> String:
	var past_events: Array[String] = []
	for run in runs:
		for event in run.events:
			if event not in exclude_current and event not in current_run_events:
				past_events.append(event)
	if past_events.is_empty():
		return ""
	return past_events.pick_random()


## Generate "past life" dialogue line
func generate_error_dialogue(_context: String = "") -> String:
	var past = get_random_past_event()
	if past.is_empty():
		return ""

	# 🔥 FIX #4: unified keys
	var lines := {
		"erased_lera":       "Ты стёр Леру. А сейчас делаешь вид, что ничего не было.",
		"erased_artyom":     "Ты стёр Артёма. Он был моим другом.",
		"erased_self":       "Ты стёр самого себя. Но я помню.",
		"removed_crime":     "Ты убрал преступность. А вместе с ней — тысячи жизней.",
		"destroyed_school":  "Ты уничтожил школу. Дети не помнят, кем хотели стать.",
		"collapsed_economy": "Экономика рухнула из-за тебя. Я помню очереди за хлебом.",
		"removed_billboard": "Ты стёр рекламный щит. Мелочь, а город уже не тот.",
		"removed_weather":   "Погода исчезла. Ты хоть понимаешь, что натворил?",
		"lost_document":     "Документ утерян. Ты уничтожил единственный способ всё исправить.",
		"became_dictator":   "Ты был диктатором. Все боялись тебя.",
		"perfect_utopia":    "Ты создал утопию. Она была ужасна.",
		"deleted_world":     "Ты удалил всё. Каждую строчку.",
	}

	if past in lines:
		return lines[past]

	return "Я помню другой мир. Тот, что был до тебя."


func has_seen_ending(ending_id: String) -> bool:
	for run in runs:
		if ending_id in run.endings:
			return true
	return false


func get_run_count() -> int:
	return runs.size()


func reset_all() -> void:
	runs.clear()
	current_run_events.clear()
	current_run_endings.clear()
	_save_runs()
