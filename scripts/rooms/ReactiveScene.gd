extends Node2D
## Generic reactive scene — objects appear/disappear based on WorldState.
## Each child with metadata "_depends_on" reacts to WorldState changes.

@onready var player: CharacterBody2D = $Player

var _reactive_nodes: Dictionary = {}  # key → node


func _ready() -> void:
	_scan_reactive_children(self)
	EventBus.world_entry_removed.connect(_on_entry_removed)
	EventBus.world_entry_added.connect(_on_entry_added)
	EventBus.world_version_changed.connect(func(_from_version: int, _to_version: int): _apply_initial_state())
	_apply_initial_state()


func _scan_reactive_children(node: Node) -> void:
	for child in node.get_children():
		if child.has_meta("_depends_on"):
			var key = child.get_meta("_depends_on")
			_reactive_nodes[key] = child
		_scan_reactive_children(child)


func _apply_initial_state() -> void:
	for key in _reactive_nodes:
		_reactive_nodes[key].visible = WorldState.is_active(key)


func _on_entry_removed(key: String) -> void:
	if _reactive_nodes.has(key):
		_reactive_nodes[key].visible = false
		AudioManager.play_sfx(AudioManager.SFX.WORLD_SHIFT)
		var tween = create_tween()
		tween.tween_property(_reactive_nodes[key], "modulate:a", 0.0, 0.3)


func _on_entry_added(key: String) -> void:
	if _reactive_nodes.has(key):
		_reactive_nodes[key].visible = true
		_reactive_nodes[key].modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(_reactive_nodes[key], "modulate:a", 1.0, 0.5)
