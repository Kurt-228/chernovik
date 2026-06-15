extends Node
## Core world state — the single source of truth.
## Every "line" in the document is an entry here.
## Removed entries are NOT erased — they are marked hidden/inactive
## so Error Persons and MetaMemory can still reference them.
##
## FLOW: DocumentEditor → WorldState.add/remove/modify → EventBus → Consequences → EventBus → UI

const STARTING_VERSION := 27

# All world entries: key → {text, active, hidden, locked, meta}
# active=false + hidden=true = "deleted" (soft delete, entry still exists for history)
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

# Entry property constants
const PROP_TEXT   := "text"
const PROP_ACTIVE := "active"
const PROP_HIDDEN := "hidden"
const PROP_LOCKED := "locked"
const PROP_META   := "meta"


func _ready() -> void:
	_load_default_world()


func _load_default_world() -> void:
	entries.clear()
	entry_order.clear()
	edit_history.clear()

	# === WORLD FACTS ===
	_add_internal("city_founded",       "Город основан в 1847 году")
	_add_internal("city_name",          "Название города: Северск")
	_add_internal("billboard_exists",   "На центральной площади стоит большой рекламный экран")
	_add_internal("street_name_mira",    "Улица Мира называется улицей Мира")
	_add_internal("old_bus_stop",       "На улице Мира есть старая автобусная остановка")
	_add_internal("weather_normal",     "В городе обычная погода — дождь и солнце сменяют друг друга")
	_add_internal("school_exists",      "В городе есть школа №17")
	_add_internal("teacher_exists",     "В школе №17 работает учитель истории Сергей Павлович")

	# === CHARACTERS ===
	_add_internal("lera_exists",        "Лера существует")
	_add_internal("lera_likes_drawing", "Лера любит рисовать")
	_add_internal("lera_best_friend",   "Лера — лучшая подруга Максима")

	_add_internal("artyom_exists",      "Артём существует")
	_add_internal("artyom_skeptic",     "Артём не верит в мистику")
	_add_internal("artyom_friend",      "Артём — друг детства Максима")

	# Nina starts hidden — appears after first edit
	_add_internal("nina_exists",        "Нина существует",        false)
	_add_internal("nina_mysterious",    "Нина знает о документе больше, чем говорит", false)
	_add_internal("nina_past_error",    "Нина является ошибкой предыдущей версии мира", false)

	# === HERO ===
	_add_internal("maxim_exists",            "Максим существует")
	_add_internal("maxim_schoolboy",         "Максим — обычный школьник")
	_add_internal("maxim_likes_drawing",     "Максим любит рисовать и сидеть за компьютером")
	_add_internal("maxim_feels_wrong",       "Максим чувствует, что что-то в мире не так")
	# Hidden truth — revealed in final act
	_add_internal("maxim_program",           "Максим является программой внутри документа", false)
	_add_internal("maxim_previous_author",   "Максим создан предыдущим Автором как инструмент редактирования", false)

	# === SOCIETY ===
	_add_internal("crime_exists",      "В городе существует преступность")
	_add_internal("disease_exists",    "Люди в городе могут болеть")
	_add_internal("police_works",      "Полиция выполняет свою работу")
	_add_internal("economy_normal",    "Экономика города функционирует нормально")

	# === MISC ===
	_add_internal("author_unknown",    "Автор документа неизвестен")
	_add_internal("document_found",    "Документ найден в заброшенной квартире")

	print("[WorldState] Loaded %d entries (v%d)" % [entries.size(), current_version])


func _add_internal(key: String, text: String, active := true, hidden := false, locked := false, meta := {}) -> void:
	entries[key] = {
		PROP_TEXT:   text,
		PROP_ACTIVE: active,
		PROP_LOCKED: locked,
		PROP_HIDDEN: hidden,
		PROP_META:   meta
	}
	if not key in entry_order:
		entry_order.append(key)


## ── PUBLIC API ────────────────────────────────────────────────────

## Add a new entry (player writes a line)
func add_entry(key: String, text: String) -> bool:
	if entries.has(key) and entries[key][PROP_ACTIVE] and not entries[key][PROP_HIDDEN]:
		return false  # already exists and visible — use modify_entry() instead

	# If key existed but was soft-deleted, revive it
	if entries.has(key):
		entries[key][PROP_ACTIVE] = true
		entries[key][PROP_HIDDEN] = false
		entries[key][PROP_TEXT] = text
		if not key in entry_order:
			entry_order.append(key)
	else:
		entries[key] = {
			PROP_TEXT:   text,
			PROP_ACTIVE: true,
			PROP_LOCKED: false,
			PROP_HIDDEN: false,
			PROP_META:   {}
		}
		entry_order.append(key)

	_record_and_emit("added", key, text)
	return true


## Soft-delete an entry (player deletes a line)
## Entry stays in memory but becomes hidden/inactive for history tracking
func remove_entry(key: String) -> bool:
	if not entries.has(key):
		return false
	if entries[key][PROP_LOCKED]:
		return false

	var removed_text = entries[key][PROP_TEXT]
	entries[key][PROP_ACTIVE] = false
	entries[key][PROP_HIDDEN] = true

	_record_and_emit("removed", key, removed_text)
	return true


## Modify existing entry (player edits a line)
func modify_entry(key: String, new_text: String) -> bool:
	if not entries.has(key):
		return false
	if entries[key][PROP_LOCKED]:
		return false

	var old_text = entries[key][PROP_TEXT]
	entries[key][PROP_TEXT] = new_text

	_record_and_emit("modified", key, old_text, new_text)
	return true


## Hard delete — actually removes from entries dict (for internal/Cascade use only)
func _hard_erase(key: String) -> void:
	if not entries.has(key):
		return
	entries.erase(key)
	entry_order.erase(key)


## ── INTERNAL: record history + emit EventBus ──────────────────────

func _record_and_emit(action: String, key: String, arg1 := "", arg2 := "") -> void:
	var record := {
		"action":      action,
		"key":         key,
		"version":     current_version,
		"edit_number": edits_made
	}
	match action:
		"added":
			record["text"] = arg1
		"removed":
			record["old_text"] = arg1
		"modified":
			record["old_text"] = arg1
			record["new_text"] = arg2

	edit_history.append(record)
	edits_made += 1

	match action:
		"added":
			EventBus.world_entry_added.emit(key, arg1)
		"removed":
			EventBus.world_entry_removed.emit(key)
		"modified":
			EventBus.world_entry_modified.emit(key, arg1, arg2)


## ── QUERIES ────────────────────────────────────────────────────────

## Visible entries for document display (active, not hidden)
func get_visible_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in entry_order:
		if not entries.has(key):
			continue
		var e = entries[key]
		if e[PROP_ACTIVE] and not e[PROP_HIDDEN]:
			result.append({
				"key":    key,
				"text":   e[PROP_TEXT],
				"active": e[PROP_ACTIVE],
				"locked": e[PROP_LOCKED]
			})
	return result


## All entries (including soft-deleted) for Error Persons and meta
func get_all_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in entry_order:
		if entries.has(key):
			var e = entries[key]
			result.append({
				"key":    key,
				"text":   e[PROP_TEXT],
				"active": e[PROP_ACTIVE],
				"locked": e[PROP_LOCKED],
				"hidden": e[PROP_HIDDEN]
			})
	return result


## Check if entry is "alive" (active and visible)
func is_active(key: String) -> bool:
	return entries.has(key) and entries[key][PROP_ACTIVE] and not entries[key][PROP_HIDDEN]


## Get entry text (works even for soft-deleted entries)
func get_text(key: String) -> String:
	if entries.has(key):
		return entries[key][PROP_TEXT]
	return ""


## Reveal a hidden entry (for story progression)
func reveal_entry(key: String) -> void:
	if entries.has(key):
		entries[key][PROP_HIDDEN] = false
		entries[key][PROP_ACTIVE] = true
		EventBus.world_entry_added.emit(key, entries[key][PROP_TEXT])


## Hide entry from document but keep active
func hide_entry(key: String) -> void:
	if entries.has(key):
		entries[key][PROP_HIDDEN] = true


## Lock/unlock
func lock_entry(key: String) -> void:
	if entries.has(key):
		entries[key][PROP_LOCKED] = true

func unlock_entry(key: String) -> void:
	if entries.has(key):
		entries[key][PROP_LOCKED] = false


## ── SNAPSHOT & VERSIONING ──────────────────────────────────────────

func create_snapshot() -> Dictionary:
	return {
		"version":     current_version,
		"edit_number": edits_made,
		"entries":     entries.duplicate(true),
		"entry_order": entry_order.duplicate()
	}


func increment_version() -> void:
	var old = current_version
	current_version += 1
	EventBus.world_version_changed.emit(old, current_version)


## ── RESET / ENDINGS ────────────────────────────────────────────────

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
	edit_history.append({
		"action": "delete_all",
		"version": current_version,
		"edit_number": edits_made
	})
	for key in entries.keys():
		entries[key][PROP_ACTIVE] = false
		entries[key][PROP_HIDDEN] = true
	edits_made += 1
	print("[WorldState] ENTIRE DOCUMENT DELETED (soft)")


## Delete Maxim's own entry (ending: Самопожертвование)
func delete_maxim() -> void:
	var maxim_keys = ["maxim_exists","maxim_schoolboy","maxim_likes_drawing","maxim_feels_wrong","maxim_program","maxim_previous_author"]
	for k in maxim_keys:
		if entries.has(k):
			entries[k][PROP_ACTIVE] = false
			entries[k][PROP_HIDDEN] = true
	print("[WorldState] MAXIM DELETED FROM EXISTENCE")
