extends Control
## Main gameplay UI — the document editor.
## Player reads lines one by one, chooses which to delete.
## This is NOT a text editor. It's a list of "reality strings".

@onready var title_label: Label = %TitleLabel
@onready var version_label: Label = %VersionLabel
@onready var entries_container: VBoxContainer = %EntriesContainer
@onready var add_line_edit: LineEdit = %AddLineEdit
@onready var add_button: Button = %AddButton
@onready var save_indicator: ColorRect = %SaveIndicator
@onready var glitch_overlay: ColorRect = %GlitchOverlay
@onready var close_button: Button = %CloseButton

# Entry scene (packed)
const ENTRY_ROW_SCENE = preload("res://scenes/ui/document_entry_row.tscn")

# Animation
var tween: Tween


func _ready() -> void:
	EventBus.world_entry_added.connect(_on_entry_added)
	EventBus.world_entry_removed.connect(_on_entry_removed)
	EventBus.screen_glitched.connect(_on_glitch)
	EventBus.save_icon_shown.connect(_on_save_flash)

	add_button.pressed.connect(_on_add_pressed)
	close_button.pressed.connect(_on_close_pressed)
	add_line_edit.text_submitted.connect(func(t): _on_add_pressed())

	_refresh_entries()
	_update_header()


func _refresh_entries() -> void:
	# Clear existing
	for child in entries_container.get_children():
		child.queue_free()

	# Populate from WorldState
	var visible = WorldState.get_visible_entries()
	for entry in visible:
		var row := ENTRY_ROW_SCENE.instantiate()
		entries_container.add_child(row)
		row.setup(entry.key, entry.text, entry.active, entry.locked)


func _update_header() -> void:
	title_label.text = "Черновик_мира_v%d.doc" % WorldState.current_version
	version_label.text = "Версия: %d  |  Правок: %d" % [WorldState.current_version, WorldState.edits_made]


## Called when player clicks [✕] on an entry
func _on_entry_delete_requested(key: String) -> void:
	if not WorldState.entries.has(key):
		return

	if WorldState.entries[key].locked:
		_show_lock_message(key)
		return

	# Play effects
	AudioManager.play_sfx(AudioManager.SFX.KEY_CLICK)
	AudioManager.trigger_glitch(0.3)

	# Check if this is a major deletion for events
	_check_major_deletion(key)

	# Remove from world
	WorldState.remove_entry(key)

	# Refresh UI
	_refresh_entries()
	_update_header()
	_save_flash()

	# Check endings
	_check_endings()


func _on_entry_edit_requested(key: String, new_text: String) -> void:
	WorldState.modify_entry(key, new_text)
	_refresh_entries()
	_update_header()


func _on_add_pressed() -> void:
	var text = add_line_edit.text.strip_edges()
	if text.is_empty():
		return

	# Generate a key from the text
	var key = text.to_snake_case().replace(" ", "_").substr(0, 40)
	WorldState.add_entry(key, text)

	add_line_edit.clear()
	_refresh_entries()
	_update_header()
	AudioManager.play_sfx(AudioManager.SFX.KEY_CLICK)
	_save_flash()


func _on_close_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.NOTEBOOK_CLOSE)
	EventBus.document_closed.emit()
	# Switch to exploration mode
	# SceneManager.go_to_scene(last_scene)


func _on_entry_added(_key: String, _text: String) -> void:
	_refresh_entries()
	_update_header()


func _on_entry_removed(_key: String) -> void:
	_refresh_entries()
	_update_header()


func _save_flash() -> void:
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween()
	save_indicator.visible = true
	save_indicator.modulate.a = 1.0
	tween.tween_property(save_indicator, "modulate:a", 0.0, 1.5)
	tween.tween_callback(func(): save_indicator.visible = false)
	EventBus.save_icon_shown.emit()


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


func _show_lock_message(key: String) -> void:
	var text = WorldState.get_text(key)
	print("[DocumentEditor] Locked entry: %s — %s" % [key, text])


func _check_major_deletion(key: String) -> void:
	match key:
		"lera_exists":
			MetaMemory.record_event("erased_lera")
		"artyom_exists":
			MetaMemory.record_event("erased_artyom")
		"maxim_exists":
			MetaMemory.record_event("erased_self")
			GameProgress.trigger_ending(GameProgress.Ending.SACRIFICE)
		"crime_exists":
			MetaMemory.record_event("destroyed_city")
		"document_found":
			GameProgress.trigger_ending(GameProgress.Ending.NOTEBOOK_DESTROYED)


func _check_endings() -> void:
	# Check for emptiness ending
	var has_any_entry := false
	for key in WorldState.entries:
		if WorldState.entries[key].active and not WorldState.entries[key].hidden:
			has_any_entry = true
			break

	if not has_any_entry:
		GameProgress.trigger_ending(GameProgress.Ending.EMPTINESS)

	# Check for freedom ending — only maxim entries remain
	var only_maxim := true
	for key in WorldState.entries:
		if not key.begins_with("maxim_") and WorldState.entries[key].active:
			only_maxim = false
			break
	if only_maxim and WorldState.entries.has("maxim_exists"):
		# Player has erased everything except themselves — potential freedom ending
		pass
