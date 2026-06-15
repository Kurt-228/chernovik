extends Node
## Manages all characters in the game.
## Characters appear/disappear based on WorldState.
## Handles dialogue triggers and relationship tracking.

# All character definitions
var characters: Dictionary = {}
# Currently active characters in-scene
var active_characters: Array[String] = []
# Relationship scores (player actions affect these)
var relationships: Dictionary = {}
# Dialogue queues
var dialogue_queue: Array[Dictionary] = []


func _ready() -> void:
	_define_characters()
	EventBus.world_entry_removed.connect(_on_entry_removed)
	EventBus.world_entry_added.connect(_on_entry_added)


func _define_characters() -> void:
	characters = {
		"maxim": {
			"name": "Максим",
			"age": 17,
			"role": "protagonist",
			"description": "Главный герой. Школьник, любит рисовать.",
			"depends_on": "maxim_exists",
			"current_scene": "bedroom",
			"visible": true
		},
		"lera": {
			"name": "Лера",
			"age": 17,
			"role": "best_friend",
			"description": "Лучшая подруга. Весёлая, саркастичная.",
			"depends_on": "lera_exists",
			"current_scene": "school",
			"visible": true
		},
		"artyom": {
			"name": "Артём",
			"age": 18,
			"role": "childhood_friend",
			"description": "Друг детства. Практичный, не верит в мистику.",
			"depends_on": "artyom_exists",
			"current_scene": "school",
			"visible": true
		},
		"nina": {
			"name": "Нина",
			"age": -1,  # unknown
			"role": "mystery",
			"description": "Таинственная девушка. Знает о документе.",
			"depends_on": "nina_exists",
			"current_scene": "city_square",
			"visible": false  # appears after first edit
		},
		"author": {
			"name": "Автор",
			"age": -1,
			"role": "creator",
			"description": "Предыдущий владелец ноутбука.",
			"depends_on": "author_revealed",
			"current_scene": "void",
			"visible": false
		}
	}

	# Init relationships
	for char_id in characters:
		relationships[char_id] = 50.0  # neutral starting point


func _on_entry_removed(key: String) -> void:
	for char_id in characters:
		if characters[char_id].depends_on == key:
			characters[char_id].visible = false
			active_characters.erase(char_id)
			EventBus.character_disappeared.emit(char_id)
			print("[CharacterManager] %s DISAPPEARED" % characters[char_id].name)


func _on_entry_added(key: String, _text: String = "") -> void:
	for char_id in characters:
		if characters[char_id].depends_on == key:
			characters[char_id].visible = true
			EventBus.character_appeared.emit(char_id, characters[char_id].current_scene)
			print("[CharacterManager] %s APPEARED" % characters[char_id].name)


## Check if character is currently visible/alive
func is_visible(char_id: String) -> bool:
	if not characters.has(char_id):
		return false
	var char = characters[char_id]
	return char.visible and WorldState.is_active(char.depends_on)


## Get character info
func get_character(char_id: String) -> Dictionary:
	return characters.get(char_id, {})


## Modify relationship (player action consequences)
func modify_relationship(char_id: String, amount: float) -> void:
	if not relationships.has(char_id):
		return
	relationships[char_id] = clampf(relationships[char_id] + amount, 0.0, 100.0)


## Get relationship level
func get_relationship(char_id: String) -> float:
	return relationships.get(char_id, 0.0)


## Queue dialogue for next scene load
func queue_dialogue(char_id: String, text: String, responses: Array[Dictionary] = []) -> void:
	dialogue_queue.append({
		"character": char_id,
		"text": text,
		"responses": responses
	})


## Get and clear dialogue queue
func get_dialogue_queue() -> Array[Dictionary]:
	var q = dialogue_queue.duplicate()
	dialogue_queue.clear()
	return q
