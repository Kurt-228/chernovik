extends Node
## Story progress state machine.
## Listens to EventBus (not WorldState directly) for story triggers.
## Centralized flow: edit → Consequences → GameProgress → UI

enum Chapter {
	PROLOGUE,
	FIRST_ANOMALY,
	FINDING_NOTEBOOK,
	FIRST_EDIT,
	EXPLORING,
	NINA_APPEARS,
	ERRORS_EMERGE,
	TRUTH_REVEALED,
	FINAL_CHOICE,
	ENDING
}

enum Ending {
	NONE,
	AUTHOR,
	FREEDOM,
	EMPTINESS,
	SACRIFICE,
	DICTATOR,
	UTOPIA_COLLAPSE,
	NOTEBOOK_DESTROYED
}

var current_chapter: Chapter = Chapter.PROLOGUE
var current_day: int = 1
var edits_before_nina: int = 3
var edits_before_errors: int = 8
var edits_before_truth: int = 15
var ending_achieved: Ending = Ending.NONE

# Flags
var first_anomaly_seen: bool = false
var notebook_found: bool = false
var first_edit_done: bool = false
var nina_met: bool = false
var errors_appeared: bool = false
var truth_revealed: bool = false
var maxim_entry_seen: bool = false

var dialogue_seen: Dictionary = {}


func _ready() -> void:
	# 🔥 FIX #3: listen to EventBus, not WorldState directly
	EventBus.world_entry_removed.connect(_on_edit_made)
	EventBus.world_entry_added.connect(_on_edit_made)
	EventBus.world_entry_modified.connect(func(_k,_o,_n): _on_edit_made(""))


## Called for every edit — checks story progression
func _on_edit_made(_key: String) -> void:
	if not first_edit_done:
		first_edit_done = true
		current_chapter = Chapter.FIRST_EDIT
		print("[GameProgress] First edit made!")

	if not nina_met and WorldState.edits_made >= edits_before_nina:
		_trigger_nina()

	if not errors_appeared and WorldState.edits_made >= edits_before_errors:
		_trigger_errors()

	if not truth_revealed and WorldState.edits_made >= edits_before_truth:
		_trigger_truth()


func _trigger_nina() -> void:
	nina_met = true
	current_chapter = Chapter.NINA_APPEARS
	WorldState.reveal_entry("nina_exists")
	WorldState.reveal_entry("nina_mysterious")
	WorldState.reveal_entry("nina_past_error")
	print("[GameProgress] Nina appears!")


func _trigger_errors() -> void:
	errors_appeared = true
	current_chapter = Chapter.ERRORS_EMERGE
	print("[GameProgress] Error Persons begin appearing!")


func _trigger_truth() -> void:
	truth_revealed = true
	current_chapter = Chapter.TRUTH_REVEALED
	WorldState.reveal_entry("maxim_program")
	WorldState.reveal_entry("maxim_previous_author")
	maxim_entry_seen = true
	print("[GameProgress] Truth revealed — Maxim is a program!")


func advance_day() -> void:
	current_day += 1
	EventBus.day_passed.emit(current_day)


func mark_dialogue_seen(id: String) -> void:
	dialogue_seen[id] = true


func has_seen_dialogue(id: String) -> bool:
	return dialogue_seen.get(id, false)


func trigger_ending(ending: Ending) -> void:
	ending_achieved = ending
	current_chapter = Chapter.ENDING
	var ending_str = _ending_to_string(ending)
	MetaMemory.record_ending(ending_str)
	print("[GameProgress] Ending: %s" % ending_str)


func _ending_to_string(e: Ending) -> String:
	match e:
		Ending.AUTHOR:              return "author"
		Ending.FREEDOM:             return "freedom"
		Ending.EMPTINESS:           return "emptiness"
		Ending.SACRIFICE:           return "sacrifice"
		Ending.DICTATOR:            return "dictator"
		Ending.UTOPIA_COLLAPSE:     return "utopia_collapse"
		Ending.NOTEBOOK_DESTROYED:  return "notebook_destroyed"
	return "none"


func reset_progress() -> void:
	current_chapter = Chapter.PROLOGUE
	current_day = 1
	ending_achieved = Ending.NONE
	first_anomaly_seen = false
	notebook_found = false
	first_edit_done = false
	nina_met = false
	errors_appeared = false
	truth_revealed = false
	maxim_entry_seen = false
	dialogue_seen.clear()
