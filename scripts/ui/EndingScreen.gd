extends Control
## Ending screen — shows after player reaches an ending.
## Different visuals/text per ending type.

@onready var ending_title: Label = %EndingTitle
@onready var ending_description: RichTextLabel = %EndingDescription
@onready var ending_quote: Label = %EndingQuote
@onready var stats_label: Label = %StatsLabel
@onready var new_game_button: Button = %NewGameButton
@onready var background: ColorRect = %Background

# Ending definitions
const ENDINGS := {
	"author": {
		"title": "Автор",
		"description": "Максим стал новым создателем мира.\nТеперь он пишет реальность.\nБудет ли его мир лучше предыдущего?",
		"quote": "\"Каждый новый день — это чистый лист. Буквально.\"",
		"color": Color(0.1, 0.3, 0.5)
	},
	"freedom": {
		"title": "Свобода",
		"description": "Документ удалён.\nМир больше некому редактировать.\nОн живёт сам — хаотично, несовершенно, свободно.",
		"quote": "\"Настоящая свобода — это отсутствие автора.\"",
		"color": Color(0.2, 0.6, 0.2)
	},
	"emptiness": {
		"title": "Пустота",
		"description": "Ты удалил всё.\nКаждую строчку.\nОстался только белый экран.",
		"quote": "\"Ничего. И никогда больше не будет.\"",
		"color": Color(0.95, 0.95, 0.95)
	},
	"sacrifice": {
		"title": "Самопожертвование",
		"description": "Ты удалил собственную строку.\nМир продолжает существовать.\nНо тебя в нём больше нет.",
		"quote": "\"Чтобы мир жил, автор должен уйти.\"",
		"color": Color(0.8, 0.5, 0.2)
	},
	"dictator": {
		"title": "Диктатор",
		"description": "Ты переписал мир под себя.\nВсе подчиняются. Никто не помнит прошлого.\nКроме тебя.",
		"quote": "\"Абсолютная власть — это абсолютное одиночество.\"",
		"color": Color(0.5, 0.1, 0.1)
	},
	"utopia_collapse": {
		"title": "Коллапс утопии",
		"description": "Ты создал идеальный мир.\nОн не выдержал собственного совершенства.\nИ рухнул.",
		"quote": "\"Идеальный мир невозможен. И слава богу.\"",
		"color": Color(0.6, 0.4, 0.6)
	},
	"notebook_destroyed": {
		"title": "Уничтожение",
		"description": "Ты уничтожил ноутбук.\nДокумента больше нет.\nРеальность застыла навсегда.",
		"quote": "\"Иногда лучший выбор — не выбирать.\"",
		"color": Color(0.3, 0.3, 0.3)
	}
}


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game)


func show_ending(ending_id: String) -> void:
	var data = ENDINGS.get(ending_id, ENDINGS["emptiness"])

	ending_title.text = data.title
	ending_description.text = data.description
	ending_quote.text = data.quote
	background.color = data.color

	# Stats
	var total_edits = WorldState.edits_made
	var total_runs = MetaMemory.get_run_count()
	var entries_remaining = WorldState.entries.size()
	stats_label.text = "Правок сделано: %d\nПрохождений: %d\nСтрок в мире: %d" % [total_edits, total_runs + 1, entries_remaining]

	# Animate
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 2.0)


func _on_new_game() -> void:
	MetaMemory.save_run()
	WorldState.reset_world()
	GameProgress.reset_progress()
	MetaMemory.current_run_events.clear()
	MetaMemory.current_run_endings.clear()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
