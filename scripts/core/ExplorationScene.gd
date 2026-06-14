extends Node2D
## Base exploration scene — handles player movement,
## interaction with objects and NPCs, and world-state reactivity.
class_name ExplorationScene

@onready var player: CharacterBody2D = %Player
@onready var interaction_zone: Area2D = %InteractionZone
@onready var scene_sprites: Node2D = %SceneSprites
@onready var npc_container: Node2D = %NPCs

# Scene-specific
@export var scene_id: String = ""
@export var scene_name: String = ""

# Reactive objects — change based on WorldState
var reactive_objects: Dictionary = {}


func _ready() -> void:
	scene_id = scene_id if not scene_id.is_empty() else name.to_snake_case()

	# Register reactive objects
	for child in scene_sprites.get_children():
		if child.has_meta("depends_on"):
			var key = child.get_meta("depends_on")
			reactive_objects[key] = child

	# Subscribe to world changes
	EventBus.world_entry_removed.connect(_on_entry_removed)
	EventBus.world_entry_added.connect(_on_entry_added)

	# Apply initial state
	_apply_world_state()


func _apply_world_state() -> void:
	for key in reactive_objects:
		reactive_objects[key].visible = WorldState.is_active(key)


func _on_entry_removed(key: String) -> void:
	if reactive_objects.has(key):
		reactive_objects[key].visible = false
		AudioManager.play_sfx(AudioManager.SFX.WORLD_SHIFT)
		# Optional: add disappearance animation
		var tween = create_tween()
		tween.tween_property(reactive_objects[key], "modulate:a", 0.0, 0.3)


func _on_entry_added(key: String) -> void:
	if reactive_objects.has(key):
		reactive_objects[key].visible = true
		reactive_objects[key].modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(reactive_objects[key], "modulate:a", 1.0, 0.5)


## Spawn an Error Person in this scene
func spawn_error_person(snapshot: Dictionary, position: Vector2, key_event: String = "") -> void:
	var error_person = load("res://scenes/characters/error_person.tscn").instantiate()
	error_person.initialize(snapshot, key_event)
	error_person.global_position = position
	npc_container.add_child(error_person)
	EventBus.error_person_appeared.emit(error_person)


## Get current scene ID
func get_scene_id() -> String:
	return scene_id
