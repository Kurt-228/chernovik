extends CharacterBody2D
## Error Person — remembers past versions of the world.
## Each Error Person has a snapshot of the world from a different
## point in the edit history. They react to the player based on
## what changed between "their" world and the current one.

class_name ErrorPerson

# The world state this person remembers
var remembered_snapshot: Dictionary = {}
var remembered_version: int = 0
var remembered_key_event: String = ""

# How this person views the player
enum Opinion { HERO, VILLAIN, GHOST, SAVIOR, UNKNOWN }
var opinion: Opinion = Opinion.UNKNOWN

# Dialogue state
var has_introduced: bool = false
var has_reacted: bool = false

# Movement
@export var wander_speed: float = 50.0
@export var wander_range: float = 100.0
var origin: Vector2
var target_position: Vector2
var target_reached_threshold: float = 10.0

# Visual
@onready var sprite: Sprite2D = %Sprite
@onready var eyes_effect: GPUParticles2D = %EyesEffect
@onready var interaction_area: Area2D = %InteractionArea
@onready var dialogue_bubble: Label = %DialogueBubble


func _ready() -> void:
	origin = global_position
	_pick_new_target()
	interaction_area.body_entered.connect(_on_player_near)
	interaction_area.body_exited.connect(_on_player_far)

	# TODO: tint sprite eyes red
	# sprite.material.set_shader_parameter("eye_color", Color.RED)


func initialize(snapshot: Dictionary, key_event: String = "") -> void:
	remembered_snapshot = snapshot
	remembered_version = snapshot.get("version", 0)
	remembered_key_event = key_event
	opinion = _calculate_opinion()
	print("[ErrorPerson] Initialized: remembers v%d, opinion=%s" % [remembered_version, Opinion.keys()[opinion]])


func _calculate_opinion() -> Opinion:
	# Compare remembered world to current
	var diff = _compute_diff()
	var removed_count = diff.removed.size()
	var added_count = diff.added.size()

	# Player erased this person's family/friends → villain
	for removed in diff.removed:
		if removed.begins_with("lera_") or removed.begins_with("artyom_"):
			return Opinion.VILLAIN

	# Player erased this person themselves
	if "maxim_exists" in diff.removed:
		return Opinion.GHOST

	if removed_count > 5:
		return Opinion.VILLAIN
	elif added_count > 5 and removed_count == 0:
		return Opinion.SAVIOR

	return Opinion.UNKNOWN


func _compute_diff() -> Dictionary:
	var current = WorldState.entries
	var remembered = remembered_snapshot.get("entries", {})

	var removed: Array[String] = []
	var added: Array[String] = []
	var modified: Array[Dictionary] = []

	for key in remembered:
		if not current.has(key):
			removed.append(key)
		elif remembered[key].get("text", "") != current[key].get("text", ""):
			modified.append({"key": key, "old": remembered[key].text, "new": current[key].text})

	for key in current:
		if not remembered.has(key):
			added.append(key)

	return {"removed": removed, "added": added, "modified": modified}


## Get a context-appropriate dialogue line
func get_greeting() -> String:
	match opinion:
		Opinion.VILLAIN:
			return "Ты уничтожил мой мир. Я помню каждый удалённый тобой фрагмент."
		Opinion.SAVIOR:
			return "Ты создал то, чего раньше не было. Я вижу новые строки."
		Opinion.GHOST:
			return "Ты... ты тоже исчез, да? Как и я?"
		Opinion.HERO:
			return "Ты тот, кто может всё исправить. Я ждал тебя."

	# UNKNOWN — use meta-memory for extra creepiness
	var meta_line = MetaMemory.generate_error_dialogue()
	if not meta_line.is_empty():
		return meta_line

	return "Ты снова всё испортил."


func get_reaction_to_player() -> String:
	if has_reacted:
		return "..."

	has_reacted = true
	var diff = _compute_diff()

	# Specific reactions
	for removed in diff.removed:
		if removed == "lera_exists":
			return "Лера... ты стёр Леру. Она была единственным светом в этом городе."
		if removed == "crime_exists":
			return "Преступности больше нет. Но знаешь что? Люди нашли новые способы делать друг другу больно."
		if removed == "school_exists":
			return "Школа исчезла. Дети больше не знают кем хотят стать. Ты отнял у них будущее."

	return "Каждое твоё изменение оставляет шрам. Ты чувствуешь их?"


func _on_player_near(_body: Node2D) -> void:
	dialogue_bubble.visible = true
	if not has_introduced:
		dialogue_bubble.text = get_greeting()
		has_introduced = true
	else:
		dialogue_bubble.text = get_reaction_to_player()


func _on_player_far(_body: Node2D) -> void:
	dialogue_bubble.visible = false


func _physics_process(delta: float) -> void:
	# Wander
	var distance = global_position.distance_to(target_position)
	if distance < target_reached_threshold:
		_pick_new_target()

	var direction = global_position.direction_to(target_position)
	velocity = direction * wander_speed
	move_and_slide()


func _pick_new_target() -> void:
	var angle = randf_range(0, TAU)
	var distance = randf_range(0, wander_range)
	target_position = origin + Vector2(cos(angle), sin(angle)) * distance
