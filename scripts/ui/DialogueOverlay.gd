extends CanvasLayer
## Visual novel dialogue overlay.
## Appears over scenes when dialogue is happening.
## Supports character portraits, typing effect, and choices.

@onready var dialogue_box: Panel = %DialogueBox
@onready var speaker_name: Label = %SpeakerName
@onready var dialogue_text: RichTextLabel = %DialogueText
@onready var choices_container: VBoxContainer = %ChoicesContainer
@onready var continue_indicator: Control = %ContinueIndicator
@onready var character_portrait: TextureRect = %CharacterPortrait

const CHOICE_BUTTON_SCENE = preload("res://scenes/ui/dialogue_choice_button.tscn")

# Typing effect
var tween: Tween
var full_text: String = ""
var is_typing: bool = false
var typing_speed: float = 0.03  # seconds per character
var current_char_index: int = 0

# Current dialogue state
var current_character: String = ""
var current_choices: Array[Dictionary] = []
var dialogue_queue: Array[Dictionary] = []
var is_active: bool = false

# Signals
signal dialogue_finished()
signal choice_selected(choice_id: String)


func _ready() -> void:
	dialogue_box.visible = false
	choices_container.visible = false
	continue_indicator.visible = false


## Start a dialogue sequence
func start_dialogue(character_id: String, text: String, choices: Array[Dictionary] = []) -> void:
	dialogue_queue.append({
		"character": character_id,
		"text": text,
		"choices": choices
	})

	if not is_active:
		_show_next()


func _show_next() -> void:
	if dialogue_queue.is_empty():
		_end_dialogue()
		return

	var entry = dialogue_queue.pop_front()
	current_character = entry.character
	current_choices = entry.choices

	dialogue_box.visible = true
	is_active = true

	# Set speaker name
	var char_data = CharacterManager.get_character(current_character)
	speaker_name.text = char_data.get("name", current_character)

	# Set portrait
	# TODO: load actual portrait textures
	# character_portrait.texture = load("res://assets/sprites/portraits/%s.png" % current_character)

	# Clear previous
	dialogue_text.text = ""
	choices_container.visible = false
	continue_indicator.visible = false

	# Start typing effect
	_type_text(entry.text)


func _type_text(text: String) -> void:
	full_text = text
	current_char_index = 0
	is_typing = true

	if tween and tween.is_valid():
		tween.kill()

	tween = create_tween()
	var total_time = text.length() * typing_speed
	tween.tween_method(_update_typing, 0, text.length(), total_time)
	tween.tween_callback(_on_typing_finished)


func _update_typing(char_index: int) -> void:
	current_char_index = char_index
	dialogue_text.text = full_text.substr(0, char_index)
	AudioManager.play_sfx(AudioManager.SFX.KEY_CLICK, 0.1)


func _on_typing_finished() -> void:
	is_typing = false
	dialogue_text.text = full_text
	EventBus.typing_effect_finished.emit()

	if current_choices.is_empty():
		continue_indicator.visible = true
	else:
		_show_choices()


func _show_choices() -> void:
	choices_container.visible = true
	for child in choices_container.get_children():
		child.queue_free()

	for choice in current_choices:
		var btn = CHOICE_BUTTON_SCENE.instantiate()
		choices_container.add_child(btn)
		btn.setup(choice.get("id", ""), choice.get("text", ""))
		btn.pressed.connect(_on_choice_selected.bind(choice.get("id", "")))


func _on_choice_selected(choice_id: String) -> void:
	choices_container.visible = false
	continue_indicator.visible = false
	choice_selected.emit(choice_id)
	_show_next()


## Skip typing effect (show full text immediately)
func skip_typing() -> void:
	if is_typing:
		if tween and tween.is_valid():
			tween.kill()
		dialogue_text.text = full_text
		is_typing = false
		_on_typing_finished()


func _end_dialogue() -> void:
	is_active = false
	dialogue_box.visible = false
	dialogue_finished.emit()


func _input(event: InputEvent) -> void:
	if not is_active:
		return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		if is_typing:
			skip_typing()
		elif continue_indicator.visible:
			_show_next()
