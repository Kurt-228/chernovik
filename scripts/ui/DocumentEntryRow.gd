extends HBoxContainer
## Single row in the document editor.

signal delete_requested(key: String)
signal edit_requested(key: String, new_text: String)

@onready var text_label: Label = %TextLabel
@onready var edit_line: LineEdit = %EditLine
@onready var edit_button: Button = %EditButton
@onready var apply_button: Button = %ApplyButton
@onready var cancel_button: Button = %CancelButton
@onready var delete_button: Button = %DeleteButton
@onready var lock_icon: Control = %LockIcon

var entry_key: String = ""
var is_locked: bool = false
var is_active: bool = true


func setup(key: String, text: String, active: bool, locked: bool) -> void:
	entry_key = key
	is_locked = locked
	is_active = active

	text_label.text = text
	edit_line.text = text
	edit_line.visible = false
	apply_button.visible = false
	cancel_button.visible = false
	text_label.visible = true
	edit_button.visible = not locked
	delete_button.visible = not locked
	lock_icon.visible = locked

	if not active:
		modulate = Color(0.5, 0.5, 0.5, 0.5)

	delete_button.pressed.connect(_on_delete_pressed)
	edit_button.pressed.connect(_begin_edit)
	apply_button.pressed.connect(_apply_edit)
	cancel_button.pressed.connect(_cancel_edit)
	edit_line.text_submitted.connect(func(_text: String): _apply_edit())


func _on_delete_pressed() -> void:
	if is_locked:
		return
	delete_requested.emit(entry_key)


func _begin_edit() -> void:
	if is_locked:
		return
	text_label.visible = false
	edit_button.visible = false
	delete_button.visible = false
	edit_line.visible = true
	apply_button.visible = true
	cancel_button.visible = true
	edit_line.grab_focus()
	edit_line.select_all()


func _apply_edit() -> void:
	var new_text = edit_line.text.strip_edges()
	if new_text.is_empty():
		_cancel_edit()
		return
	edit_requested.emit(entry_key, new_text)


func _cancel_edit() -> void:
	edit_line.text = text_label.text
	edit_line.visible = false
	apply_button.visible = false
	cancel_button.visible = false
	text_label.visible = true
	edit_button.visible = not is_locked
	delete_button.visible = not is_locked
