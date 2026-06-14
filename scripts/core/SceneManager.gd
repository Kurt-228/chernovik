extends Node
## Scene management — handles transitions between rooms/scenes.
## Tracks current scene, applies fade transitions,
## triggers world-state-dependent scene modifications.

# Current scene info
var current_scene_id: String = ""
var current_scene_node: Node = null
var previous_scene_id: String = ""

# Scene registry
const SCENES := {
	"bedroom": "res://scenes/rooms/bedroom.tscn",
	"school": "res://scenes/rooms/school.tscn",
	"city_square": "res://scenes/rooms/city_square.tscn",
	"abandoned_apartment": "res://scenes/rooms/abandoned_apartment.tscn",
	"street": "res://scenes/rooms/street.tscn",
	"void": "res://scenes/world/void.tscn",
	"document": "res://scenes/ui/document_editor.tscn",
	"main_menu": "res://scenes/ui/main_menu.tscn",
	"ending_screen": "res://scenes/ui/ending_screen.tscn",
}

# Transition
@onready var transition_rect: ColorRect = $TransitionRect
var tween: Tween


func _ready() -> void:
	EventBus.scene_changed.connect(_on_scene_changed)


## Go to a scene by ID
func go_to_scene(scene_id: String, fade_duration: float = 1.0) -> void:
	if not SCENES.has(scene_id):
		push_error("[SceneManager] Unknown scene: %s" % scene_id)
		return

	await _fade_out(fade_duration)

	previous_scene_id = current_scene_id
	current_scene_id = scene_id

	# Unload current scene
	if current_scene_node:
		current_scene_node.queue_free()

	# Load new scene
	var scene_path = SCENES[scene_id]
	var packed = load(scene_path)
	if packed:
		current_scene_node = packed.instantiate()
		add_child(current_scene_node)
		print("[SceneManager] Loaded: %s" % scene_id)
	else:
		push_error("[SceneManager] Failed to load: %s" % scene_path)

	EventBus.scene_changed.emit(previous_scene_id, current_scene_id)

	await _fade_in(fade_duration)


## Open document overlay (doesn't change scene, overlays on top)
func open_document() -> void:
	var doc_path = SCENES["document"]
	var packed = load(doc_path)
	if packed:
		var doc = packed.instantiate()
		add_child(doc)
		EventBus.document_opened.emit()
		print("[SceneManager] Document opened")


func _fade_out(duration: float) -> void:
	transition_rect.visible = true
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 1.0, duration)
	await tween.finished


func _fade_in(duration: float) -> void:
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 0.0, duration)
	await tween.finished
	transition_rect.visible = false


func _on_scene_changed(from_scene: String, to_scene: String) -> void:
	# Adjust music based on scene
	match to_scene:
		"bedroom", "school", "street":
			AudioManager.set_mood(AudioManager.MusicMood.CALM)
		"city_square":
			AudioManager.set_mood(AudioManager.MusicMood.EXPLORING)
		"abandoned_apartment":
			AudioManager.set_mood(AudioManager.MusicMood.ANOMALY)
		"void":
			AudioManager.set_mood(AudioManager.MusicMood.SILENCE)
		"document":
			AudioManager.set_mood(AudioManager.MusicMood.EXPLORING)
