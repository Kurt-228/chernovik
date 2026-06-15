extends Control
## Main menu — first screen. Starts the game.

@onready var new_game_btn: Button = $VBoxContainer/NewGameButton
@onready var continue_btn: Button = $VBoxContainer/ContinueButton
@onready var title_label: Label = $TitleLabel
@onready var runs_label: Label = $RunsLabel


func _ready() -> void:
	new_game_btn.pressed.connect(_on_new_game)
	continue_btn.pressed.connect(_on_continue)

	var runs = MetaMemory.get_run_count()
	if runs > 0:
		runs_label.text = "Прошлых прохождений: %d" % runs
	continue_btn.disabled = not SaveManager.has_save()


func _on_new_game() -> void:
	WorldState.reset_world()
	GameProgress.reset_progress()
	Consequences.reset()
	MetaMemory.current_run_events.clear()
	MetaMemory.current_run_endings.clear()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_continue() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://scenes/main.tscn")
