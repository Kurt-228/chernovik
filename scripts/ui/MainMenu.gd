extends Control
## Main menu screen — first thing player sees.

@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var past_runs_label: Label = %PastRunsLabel


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game)
	continue_button.pressed.connect(_on_continue)

	# Show past runs count if any
	var runs = MetaMemory.get_run_count()
	if runs > 0:
		past_runs_label.text = "Прошлых прохождений: %d" % runs

	# TODO: Enable continue if save exists
	# continue_button.disabled = not SaveManager.has_save()


func _on_new_game() -> void:
	WorldState.reset_world()
	GameProgress.reset_progress()
	MetaMemory.current_run_events.clear()
	MetaMemory.current_run_endings.clear()
	get_tree().change_scene_to_file("res://scenes/rooms/bedroom.tscn")


func _on_continue() -> void:
	# TODO: Load save
	pass
