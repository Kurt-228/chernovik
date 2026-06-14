extends HBoxContainer
## Single row in the document editor.
## Shows entry text + delete button.

signal delete_requested(key: String)
signal edit_requested(key: String, new_text: String)

@onready var text_label: Label = %TextLabel
@onready var delete_button: Button = %DeleteButton
@onready var lock_icon: TextureRect = %LockIcon

var entry_key: String = ""
var is_locked: bool = false
var is_active: bool = true


func setup(key: String, text: String, active: bool, locked: bool) -> void:
	entry_key = key
	is_locked = locked
	is_active = active

	text_label.text = text
	delete_button.visible = not locked
	lock_icon.visible = locked

	# Visual state
	if not active:
		modulate = Color(0.5, 0.5, 0.5, 0.5)

	delete_button.pressed.connect(_on_delete_pressed)


func _on_delete_pressed() -> void:
	if is_locked:
		return
	delete_requested.emit(entry_key)
