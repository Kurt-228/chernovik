extends Node
## Core world state — the single source of truth.
## Every "line" in the document is an entry here.
## Removing/adding entries triggers cascading consequences
## via the Consequences system.

const STARTING_VERSION := 27

# All world entries: key → {text, active, locked, meta}
var entries: Dictionary = {}
# Ordered list for document display
var entry_order: Array[String] = []
# Full edit history for Error Persons & meta-memory
var edit_history: Array[Dictionary] = []
# Current version number (increments on save)
var current_version: int = STARTING_VERSION
# Number of edits made this run
var edits_made: int = 0
# Has the player discovered the true nature of the document?
var player_knows_truth: bool = false
# Has the player seen their own entry?
var player_saw_own_entry: bool = false

# Editable entry properties
const PROP_TEXT = "text"
const PROP_ACTIVE = "active"
const PROP_LOCKED = "locked"
const PROP_HIDDEN = "hidden"
const PROP_META = "meta"


func _ready() -> void:
	_load_default_world()


func _load_default_world() -> void:
	entries.clear()
	entry_order.clear()
	edit_history.clear()

	# === WORLD FACTS ===
	_add_entry_internal("city_founded", "Город основан в 1847 году", true)
	_add_entry_internal("city_name", "Название города: Северск", true)
	_add_entry_internal("billboard_exists", "На центральной площади стоит большой рекламный экран", true)
	_add_entry_internal("old_bus_stop", "На улице Мира есть старая автобусная остановка", true)
	_add_entry_internal("weather_normal", "В городе обычная погода — дождь и солнце сменяют друг друга", true)
	_add_entry_internal("school_exists", "В городе есть школа №17", true)

	# === CHARACTERS ===
	_add_entry_internal("lera_exists", "Лера существует", true)
	_add_entry_internal("lera_likes_drawing", "Лера любит рисовать", true)
	_add_entry_internal("lera_best_friend", "Лера — лучшая подруга Максима", true)

	_add_entry_internal("artyom_exists", "Артём существует", true)
	_add_entry_internal("artyom_skeptic", "Артём не верит в мистику", true)
	_add_entry_internal("artyom_friend", "Артём — друг детства Максима", true)

	_add_entry_internal("nina_exists", "Нина существует", false)  # appears after first edit
	_add_entry_internal("nina_mysterious", "Нина знает о документе больше, чем говорит", false)
	_add_entry_internal("nina_past_error", "Нина является ошибкой предыдущей версии мира", false)

	# === HERO ===
	_add_entry_internal("maxim_exists", "Максим существует", true)
	_add_entry_internal("maxim_schoolboy", "Максим — обычный школьник", true)
	_add_entry_internal("maxim_likes_drawing", "Максим любит рисовать и сидеть за компьютером", true)
	_add_entry_internal("maxim_feels_wrong", "Максим чувствует, что что-то в мире не так", true)
	# Hidden truth — revealed in final act
	_add_entry_internal("maxim_program", "Максим является программой внутри документа", false)
	_add_entry_internal("maxim_previous_author", "Максим создан предыдущим Автором как инструмент редактирования", false)

	# === SOCIETY ===
	_add_entry_internal("crime_exists", "В городе существует преступность", true)
	_add_entry_internal("police_works", "Полиция выполняет свою работу", true)
	_add_entry_internal("economy_normal", "Экономика города функционирует нормально", true)

	# === MISC ===
	_add_entry_internal("author_unknown", "Автор документа неизвестен", true)
	_add_entry_internal("document_found", "Документ найден в заброшенной квартире", true)

	print("[WorldState] Loaded %d entries (v%d)" % [entries.size(), current_version])


func _add_entry_internal(key: String, text: String, active: bool, locked: bool = false, meta: Dictionary = {}) -> void:
	entries[key] = {
		PROP_TEXT: text,
		PROP_ACTIVE: active,
		PROP_LOCKED: locked,
		PROP_HIDDEN: false,
		PROP_META: meta
	}
	if not key in entry_order:
		entry_order.append(key)


## Public API — Add a new entry (player writes a line)
func add_entry(key: String, text: String) -> bool:
	if entries.has(key):
		return false  # already exists, use modify instead

	entries[key] = {
		PROP_TEXT: text,
		PROP_ACTIVE: true,
		PROP_LOCKED: false,
		PROP_HIDDEN: false,
		PROP_META: {}
	}
	entry_order.append(key)

	var record := {
		"action": "added",
		"key": key,
		"text": text,
		"version": current_version,
		"edit_number": edits_made
	}
	edit_history.append(record)
	edits_made += 1

	EventBus.world_entry_added.emit(key, text)
	Consequences.trigger_on_add(key)
	return true


## Public API — Remove an entry (player deletes a line)
func remove_entry(key: String) -> bool:
	if not entries.has(key):
		return false
	if entries[key][PROP_LOCKED]:
		return false  # cannot delete locked entries

	var removed_text = entries[key][PROP_TEXT]

	var record := {
		"action": "removed",
		"key": key,
		"old_text": removed_text,
		"version": current_version,
		"edit_number": edits_made
	}
	edit_history.append(record)

	entries.erase(key)
	entry_order.erase(key)
	edits_made += 1

	EventBus.world_entry_removed.emit(key)
	Consequences.trigger_on_remove(key)
	return true


## Public API — Modify existing entry (player edits a line)
func modify_entry(key: String, new_text: String) -> bool:
	if not entries.has(key):
		return false
	if entries[key][PROP_LOCKED]:
		return false

	var old_text = entries[key][PROP_TEXT]
	entries[key][PROP_TEXT] = new_text

	var record := {
		"action": "modified",
		"key": key,
		"old_text": old_text,
		"new_text": new_text,
		"version": current_version,
		"edit_number": edits_made
	}
	edit_history.append(record)
	edits_made += 1

	EventBus.world_entry_modified.emit(key, old_text, new_text)
	Consequences.trigger_on_modify(key, old_text, new_text)
	return true


## Toggle entry active/inactive (reveal/hide without deleting)
func toggle_entry(key: String) -> bool:
	if not entries.has(key):
		return false
	entries[key][PROP_ACTIVE] = !entries[key][PROP_ACTIVE]
	if entries[key][PROP_ACTIVE]:
		EventBus.world_entry_added.emit(key, entries[key][PROP_TEXT])
	else:
		EventBus.world_entry_removed.emit(key)
	return true


## Reveal a hidden entry
func reveal_entry(key: String) -> void:
	if entries.has(key):
		entries[key][PROP_HIDDEN] = false
		entries[key][PROP_ACTIVE] = true
		EventBus.world_entry_added.emit(key, entries[key][PROP_TEXT])


## Hide entry from document but keep in state
func hide_entry(key: String) -> void:
	if entries.has(key):
		entries[key][PROP_HIDDEN] = true


## Lock an entry (cannot be deleted)
func lock_entry(key: String) -> void:
	if entries.has(key):
		entries[key][PROP_LOCKED] = true


## Unlock entry
func unlock_entry(key: String) -> void:
	if entries.has(key):
		entries[key][PROP_LOCKED] = false


## Get visible (non-hidden) entries for document display
func get_visible_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in entry_order:
		if entries.has(key) and not entries[key][PROP_HIDDEN]:
			result.append({
				"key": key,
				"text": entries[key][PROP_TEXT],
				"active": entries[key][PROP_ACTIVE],
				"locked": entries[key][PROP_LOCKED]
			})
	return result


## Get all entries (including hidden) for internal use
func get_all_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in entry_order:
		if entries.has(key):
			result.append({
				"key": key,
				"text": entries[key][PROP_TEXT],
				"active": entries[key][PROP_ACTIVE],
				"locked": entries[key][PROP_LOCKED],
				"hidden": entries[key][PROP_HIDDEN]
			})
	return result


## Check if a specific entry is active (exists and active)
func is_active(key: String) -> bool:
	return entries.has(key) and entries[key][PROP_ACTIVE]


## Get entry text
func get_text(key: String) -> String:
	if entries.has(key):
		return entries[key][PROP_TEXT]
	return ""


## Save current world state as snapshot (for Error Persons)
func create_snapshot() -> Dictionary:
	var snap := {
		"version": current_version,
		"edit_number": edits_made,
		"entries": entries.duplicate(true),
		"entry_order": entry_order.duplicate()
	}
	return snap


## Increment version (called on document save)
func increment_version() -> void:
	var old = current_version
	current_version += 1
	EventBus.world_version_changed.emit(old, current_version)
	print("[WorldState] Version %d → %d" % [old, current_version])


## Reset entire world (for new game+)
func reset_world() -> void:
	current_version = STARTING_VERSION
	edits_made = 0
	edit_history.clear()
	player_knows_truth = false
	player_saw_own_entry = false
	_load_default_world()
	EventBus.world_version_changed.emit(STARTING_VERSION, STARTING_VERSION)


## Delete entire document (ending: Пустота)
func delete_all() -> void:
	entries.clear()
	entry_order.clear()
	edit_history.append({
		"action": "delete_all",
		"version": current_version,
		"edit_number": edits_made
	})
	edits_made += 1
	print("[WorldState] ENTIRE DOCUMENT DELETED")


## Delete Maxim's own entry (ending: Самопожертвование)
func delete_maxim() -> void:
	remove_entry("maxim_exists")
	remove_entry("maxim_schoolboy")
	remove_entry("maxim_likes_drawing")
	remove_entry("maxim_feels_wrong")
	remove_entry("maxim_program")
	remove_entry("maxim_previous_author")
	print("[WorldState] MAXIM DELETED FROM EXISTENCE")
