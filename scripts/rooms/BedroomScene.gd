extends Node2D
## Bedroom scene — first exploration area.
## Player can walk around, interact with the notebook to open the document editor.

@onready var player: CharacterBody2D = $Player
@onready var notebook: Area2D = $Notebook
@onready var notebook_hint: Label = $Notebook/NotebookHint
@onready var hint_label: Label = $HintLabel

var can_interact: bool = false
var document_open: bool = false


func _ready() -> void:
	# Connect notebook interaction
	notebook.body_entered.connect(func(_b): _set_hint(true))
	notebook.body_exited.connect(func(_b): _set_hint(false))

	# Update hint based on world state
	if not WorldState.is_active("billboard_exists"):
		hint_label.text += "\nСтранно... рекламный щит на площади исчез."


func _set_hint(visible: bool) -> void:
	can_interact = visible
	notebook_hint.visible = visible


func _input(event: InputEvent) -> void:
	# Open: F key or Enter when near notebook
	if can_interact and (event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_F and event.pressed)):
		_open_document()
	# Close: Esc
	if event.is_action_pressed("ui_cancel") and document_open:
		_close_document()


func _open_document() -> void:
	if document_open:
		return
	document_open = true
	notebook_hint.visible = false

	AudioManager.play_sfx(AudioManager.SFX.NOTEBOOK_OPEN)
	EventBus.document_opened.emit()

	var doc_scene = load("res://scenes/ui/document_editor.tscn")
	var doc = doc_scene.instantiate()
	doc.name = "DocumentOverlay"
	doc.tree_exited.connect(func():
		document_open = false
		player.set_process(true)
		player.set_physics_process(true)
	)
	add_child(doc)

	# Pause player movement
	player.set_process(false)
	player.set_physics_process(false)


func _close_document() -> void:
	document_open = false
	if has_node("DocumentOverlay"):
		$DocumentOverlay.queue_free()
	AudioManager.play_sfx(AudioManager.SFX.NOTEBOOK_CLOSE)
	EventBus.document_closed.emit()

	# Resume player
	player.set_process(true)
	player.set_physics_process(true)
