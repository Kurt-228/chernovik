extends Control
## Main gameplay UI — the document editor.
## Player reads lines, clicks ✕ to "delete" (soft-delete via WorldState).
## All edits go through WorldState → EventBus → Consequences → UI.

@onready var title_label: Label = %TitleLabel
@onready var version_label: Label = %VersionLabel
@onready var entries_container: VBoxContainer = %EntriesContainer
@onready var add_line_edit: LineEdit = %AddLineEdit
@onready var add_button: Button = %AddButton
@onready var save_indicator: ColorRect = %SaveIndicator
@onready var glitch_overlay: ColorRect = %GlitchOverlay
@onready var close_button: Button = %CloseButton
@onready var quick_summer_button: Button = %QuickSummerButton
@onready var quick_rich_button: Button = %QuickRichButton
@onready var quick_teacher_button: Button = %QuickTeacherButton
@onready var quick_truth_button: Button = %QuickTruthButton
@onready var quick_health_button: Button = %QuickHealthButton
@onready var quick_perfect_button: Button = %QuickPerfectButton
@onready var quick_obey_button: Button = %QuickObeyButton
@onready var final_bar: HBoxContainer = %FinalBar
@onready var author_button: Button = %AuthorButton
@onready var freedom_button: Button = %FreedomButton
@onready var void_button: Button = %VoidButton

const ENTRY_ROW_SCENE = preload("res://scenes/ui/document_entry_row.tscn")

var tween: Tween
var _refresh_queued: bool = false


func _ready() -> void:
	EventBus.world_entry_added.connect(_on_world_changed)
	EventBus.world_entry_removed.connect(_on_world_changed)
	EventBus.world_entry_modified.connect(func(_k,_o,_n): _queue_refresh())
	EventBus.screen_glitched.connect(_on_glitch)
	EventBus.save_icon_shown.connect(_on_save_flash)

	add_button.pressed.connect(_on_add_pressed)
	close_button.pressed.connect(_on_close_pressed)
	add_line_edit.text_submitted.connect(func(_t): _on_add_pressed())
	quick_summer_button.pressed.connect(func(): _add_known_entry("eternal_summer", "В городе наступило вечное лето"))
	quick_rich_button.pressed.connect(func(): _add_known_entry("maxim_rich", "Максим стал богатым"))
	quick_teacher_button.pressed.connect(func(): _add_known_entry("teacher_returned", "Пропавший учитель вернулся в школу"))
	quick_truth_button.pressed.connect(func(): _add_known_entry("author_revealed", "Автор документа раскрыт"))
	quick_health_button.pressed.connect(func(): _remove_known_entry("disease_exists"))
	quick_perfect_button.pressed.connect(func(): _add_known_entry("perfect_city", "Город стал идеальным"))
	quick_obey_button.pressed.connect(func(): _add_known_entry("all_obey_maxim", "Все жители города подчиняются Максиму"))
	author_button.pressed.connect(func(): GameProgress.trigger_ending(GameProgress.Ending.AUTHOR))
	freedom_button.pressed.connect(func(): GameProgress.trigger_ending(GameProgress.Ending.FREEDOM))
	void_button.pressed.connect(_delete_everything)

	_refresh_entries()
	_update_header()


func _refresh_entries() -> void:
	# Clear existing rows
	for child in entries_container.get_children():
		child.queue_free()

	# Populate from WorldState visible entries
	var visible = WorldState.get_visible_entries()
	for entry in visible:
		var row := ENTRY_ROW_SCENE.instantiate()
		entries_container.add_child(row)
		row.setup(entry.key, entry.text, entry.active, entry.locked)
		row.delete_requested.connect(_on_entry_delete_requested)
		row.edit_requested.connect(_on_entry_edit_requested)

	_refresh_queued = false


func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		call_deferred("_refresh_entries")
		call_deferred("_update_header")


func _on_world_changed(_arg1 := "", _arg2 := "") -> void:
	_queue_refresh()


func _update_header() -> void:
	title_label.text = "Черновик_мира_v%d.doc" % WorldState.current_version
	version_label.text = "Версия: %d  |  Правок: %d" % [WorldState.current_version, WorldState.edits_made]
	final_bar.visible = GameProgress.truth_revealed or WorldState.is_active("maxim_truth_revealed")


## ── DELETE ENTRY ───────────────────────────────────────────────────

func _on_entry_delete_requested(key: String) -> void:
	if not WorldState.entries.has(key):
		return

	if WorldState.entries[key].locked:
		_show_lock_message(key)
		return

	# Effects
	AudioManager.play_sfx(AudioManager.SFX.KEY_CLICK)
	AudioManager.trigger_glitch(0.3)

	# Record meta-event BEFORE removal
	_record_deletion_event(key)

	# Soft-delete via WorldState → EventBus → Consequences → UI refresh
	WorldState.remove_entry(key)

	# Process delayed consequences
	Consequences.process_delayed()

	# UI
	_refresh_entries()
	_update_header()
	SaveManager.quick_save()

	_check_endings()


## ── EDIT ENTRY ─────────────────────────────────────────────────────

func _on_entry_edit_requested(key: String, new_text: String) -> void:
	WorldState.modify_entry(key, new_text)
	Consequences.process_delayed()
	_refresh_entries()
	_update_header()
	SaveManager.quick_save()


## ── ADD ENTRY ──────────────────────────────────────────────────────

func _on_add_pressed() -> void:
	var text = add_line_edit.text.strip_edges()
	if text.is_empty():
		return

	var key = _generate_unique_key(text)
	WorldState.add_entry(key, text)

	add_line_edit.clear()
	Consequences.process_delayed()
	_refresh_entries()
	_update_header()
	AudioManager.play_sfx(AudioManager.SFX.KEY_CLICK)
	SaveManager.quick_save()


func _add_known_entry(key: String, text: String) -> void:
	if WorldState.is_active(key):
		EventBus.world_message_shown.emit("Эта строка уже есть в мире")
		return
	WorldState.add_entry(key, text)
	Consequences.process_delayed()
	_refresh_entries()
	_update_header()
	AudioManager.trigger_glitch(0.2)
	SaveManager.quick_save()
	_check_endings()


func _remove_known_entry(key: String) -> void:
	if not WorldState.is_active(key):
		EventBus.world_message_shown.emit("Эта строка уже удалена")
		return
	_record_deletion_event(key)
	WorldState.remove_entry(key)
	Consequences.process_delayed()
	_refresh_entries()
	_update_header()
	AudioManager.trigger_glitch(0.25)
	SaveManager.quick_save()
	_check_endings()


func _generate_unique_key(text: String) -> String:
	var base = text.to_snake_case().replace(" ", "_").substr(0, 40)
	if not WorldState.entries.has(base):
		return base
	# Collision — append suffix
	var i := 2
	while WorldState.entries.has("%s_%d" % [base, i]):
		i += 1
	return "%s_%d" % [base, i]


## ── CLOSE ──────────────────────────────────────────────────────────

func _on_close_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.NOTEBOOK_CLOSE)
	EventBus.document_closed.emit()
	# Free self — caller cleans up its reference
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_viewport().set_input_as_handled()


## ── EFFECTS / UI ───────────────────────────────────────────────────

func _save_flash() -> void:
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween()
	save_indicator.visible = true
	save_indicator.modulate.a = 1.0
	tween.tween_property(save_indicator, "modulate:a", 0.0, 1.5)
	tween.tween_callback(func(): save_indicator.visible = false)


func _on_save_flash() -> void:
	_save_flash()


func _on_glitch(duration: float) -> void:
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween()
	glitch_overlay.visible = true
	glitch_overlay.modulate = Color(1, 1, 1, 0.3)
	tween.tween_property(glitch_overlay, "modulate:a", 0.3, 0.05)
	tween.tween_property(glitch_overlay, "modulate:a", 0.6, 0.05)
	tween.tween_property(glitch_overlay, "modulate:a", 0.1, 0.05)
	tween.tween_property(glitch_overlay, "modulate:a", 0.5, 0.05)
	tween.tween_property(glitch_overlay, "modulate:a", 0.0, duration * 0.5)


## ── HELPERS ────────────────────────────────────────────────────────

func _show_lock_message(key: String) -> void:
	print("[DocumentEditor] Locked entry: %s — %s" % [key, WorldState.get_text(key)])


func _delete_everything() -> void:
	MetaMemory.record_event("deleted_world")
	WorldState.delete_all()
	SaveManager.quick_save()
	GameProgress.trigger_ending(GameProgress.Ending.EMPTINESS)


func _record_deletion_event(key: String) -> void:
	match key:
		"lera_exists":
			MetaMemory.record_event("erased_lera")
		"artyom_exists":
			MetaMemory.record_event("erased_artyom")
		"maxim_exists":
			MetaMemory.record_event("erased_self")
			GameProgress.trigger_ending(GameProgress.Ending.SACRIFICE)
		"crime_exists":
			MetaMemory.record_event("removed_crime")
		"disease_exists":
			MetaMemory.record_event("removed_disease")
		"school_exists":
			MetaMemory.record_event("destroyed_school")
		"billboard_exists":
			MetaMemory.record_event("removed_billboard")
		"economy_normal":
			MetaMemory.record_event("collapsed_economy")
		"weather_normal":
			MetaMemory.record_event("removed_weather")
		"document_found":
			MetaMemory.record_event("lost_document")
			GameProgress.trigger_ending(GameProgress.Ending.NOTEBOOK_DESTROYED)
		_:
			MetaMemory.record_event("removed_" + key)


## ── ENDING CHECKS ──────────────────────────────────────────────────

func _check_endings() -> void:
	if WorldState.is_active("maxim_feared") and WorldState.is_active("free_will_missing"):
		MetaMemory.record_event("became_dictator")
		GameProgress.trigger_ending(GameProgress.Ending.DICTATOR)
		return

	if WorldState.is_active("utopia_cracks") and WorldState.is_active("disease_vanished") and WorldState.is_active("crime_vanished"):
		MetaMemory.record_event("perfect_utopia")
		GameProgress.trigger_ending(GameProgress.Ending.UTOPIA_COLLAPSE)
		return

	# Emptiness: nothing visible left
	var has_visible := false
	for key in WorldState.entries:
		if WorldState.is_active(key):
			has_visible = true
			break
	if not has_visible:
		GameProgress.trigger_ending(GameProgress.Ending.EMPTINESS)
