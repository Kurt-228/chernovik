extends Node
## Tracks player progress through the story.
## Acts as a state machine for narrative beats.

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
	AUTHOR,            # Максим становится новым Автором
	FREEDOM,           # Удаляет документ, мир живёт сам
	EMPTINESS,         # Удаляет всё
	SACRIFICE,         # Удаляет себя
	DICTATOR,          # Становится диктатором
	UTOPIA_COLLAPSE,   # Утопия разрушается
	NOTEBOOK_DESTROYED # Уничтожает ноутбук
}

var current_chapter: Chapter = Chapter.PROLOGUE
var current_day: int = 1
var edits_before_nina: int = 3  # After this many edits, Nina appears
var edits_before_errors: int = 8  # After this many, Error Persons appear
var edits_before_truth: int = 15  # After this many, truth starts revealing
var ending_achieved: Ending = Ending.NONE

# Flags
var first_anomaly_seen: bool = false
var notebook_found: bool = false
var first_edit_done: bool = false
var nina_met: bool = false
var errors_appeared: bool = false
var truth_revealed: bool = false
var maxim_entry_seen: bool = false

# Dialogue state — tracks what conversations have happened
var dialogue_seen: Dictionary = {}


func _ready() -> void:
	EventBus.world_entry_removed.connect(_on_entry_removed)
	EventBus.world_entry_added.connect(_on_entry_added)


func _on_entry_removed(key: String) -> void:
	if not first_edit_done:
		first_edit_done = true
		current_chapter = Chapter.FIRST_EDIT
		print("[GameProgress] First edit made!")

	MetaMemory.record_event(key + "_removed")

	# Check for progression triggers
	if not nina_met and WorldState.edits_made >= edits_before_nina:
		_trigger_nina_appearance()

	if not errors_appeared and WorldState.edits_made >= edits_before_errors:
		_trigger_errors()

	if not truth_revealed and WorldState.edits_made >= edits_before_truth:
		_trigger_truth()

	Consequences.process_delayed()


func _on_entry_added(key: String) -> void:
	MetaMemory.record_event(key + "_added")
	Consequences.process_delayed()


func _trigger_nina_appearance() -> void:
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


## Advance to next day
func advance_day() -> void:
	current_day += 1
	EventBus.day_passed.emit(current_day)
	print("[GameProgress] Day %d" % current_day)


## Mark dialogue as seen
func mark_dialogue_seen(dialogue_id: String) -> void:
	dialogue_seen[dialogue_id] = true


## Check if dialogue has been seen
func has_seen_dialogue(dialogue_id: String) -> bool:
	return dialogue_seen.get(dialogue_id, false)


## Trigger ending
func trigger_ending(ending: Ending) -> void:
	ending_achieved = ending
	current_chapter = Chapter.ENDING
	MetaMemory.record_ending(_ending_to_string(ending))
	MetaMemory.save_run()
	print("[GameProgress] Ending triggered: %s" % _ending_to_string(ending))


func _ending_to_string(e: Ending) -> String:
	match e:
		Ending.AUTHOR: return "author"
		Ending.FREEDOM: return "freedom"
		Ending.EMPTINESS: return "emptiness"
		Ending.SACRIFICE: return "sacrifice"
		Ending.DICTATOR: return "dictator"
		Ending.UTOPIA_COLLAPSE: return "utopia_collapse"
		Ending.NOTEBOOK_DESTROYED: return "notebook_destroyed"
	return "none"


## Reset for new game
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
