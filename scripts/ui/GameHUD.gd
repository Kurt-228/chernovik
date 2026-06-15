extends CanvasLayer
## Small in-game shell: travel, document access, saves, and world feedback.

@onready var location_label: Label = %LocationLabel
@onready var stats_label: Label = %StatsLabel
@onready var message_label: Label = %MessageLabel
@onready var bedroom_button: Button = %BedroomButton
@onready var school_button: Button = %SchoolButton
@onready var square_button: Button = %SquareButton
@onready var apartment_button: Button = %ApartmentButton
@onready var street_button: Button = %StreetButton
@onready var document_button: Button = %DocumentButton
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var objective_label: Label = %ObjectiveLabel
@onready var world_log_label: Label = %WorldLogLabel

var _message_tween: Tween


func _ready() -> void:
	bedroom_button.pressed.connect(func(): _go("bedroom"))
	school_button.pressed.connect(func(): _go("school"))
	square_button.pressed.connect(func(): _go("city_square"))
	apartment_button.pressed.connect(func(): _go("abandoned_apartment"))
	street_button.pressed.connect(func(): _go("street"))
	document_button.pressed.connect(_open_document)
	save_button.pressed.connect(func(): SaveManager.quick_save())
	load_button.pressed.connect(_quick_load)

	EventBus.scene_changed.connect(_on_scene_changed)
	EventBus.world_entry_added.connect(func(_k, _t): _update_stats())
	EventBus.world_entry_removed.connect(func(_k): _update_stats())
	EventBus.world_entry_modified.connect(func(_k, _o, _n): _update_stats())
	EventBus.world_version_changed.connect(func(_from_version: int, _to_version: int): _update_stats())
	EventBus.save_icon_shown.connect(func(): _show_message("Сохранено"))
	EventBus.world_message_shown.connect(_show_message)
	EventBus.ending_reached.connect(func(_id): visible = false)
	_update_stats()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_focus_next"):
		_open_document()


func _go(scene_id: String) -> void:
	var manager = get_parent()
	if manager and manager.has_method("go_to_scene"):
		manager.go_to_scene(scene_id, 0.25)


func _open_document() -> void:
	var manager = get_parent()
	if manager and manager.has_method("open_document"):
		manager.open_document()


func _quick_load() -> void:
	if SaveManager.quick_load():
		_update_stats()
	else:
		_show_message("Сохранение не найдено")


func _on_scene_changed(_from_scene: String, to_scene: String) -> void:
	var names := {
		"bedroom": "Комната Максима",
		"school": "Школа N17",
		"city_square": "Центральная площадь",
		"abandoned_apartment": "Заброшенная квартира",
		"street": "Улица Мира",
		"void": "Пустота"
	}
	location_label.text = names.get(to_scene, to_scene)
	_update_stats()


func _update_stats() -> void:
	stats_label.text = "Правок: %d  |  Видимых строк: %d" % [
		WorldState.edits_made,
		WorldState.get_visible_entries().size()
	]
	objective_label.text = _current_objective()
	world_log_label.text = _world_log_text()


func _current_objective() -> String:
	if GameProgress.current_chapter == GameProgress.Chapter.ENDING:
		return "История завершена"
	if GameProgress.truth_revealed or WorldState.is_active("maxim_truth_revealed"):
		return "Финал: открой документ и выбери, кто будет автором мира"
	if GameProgress.errors_appeared:
		return "Ошибки появились: проверь школу, площадь или квартиру"
	if GameProgress.nina_met:
		return "Нина ждёт на площади. Она помнит другую версию мира"
	if WorldState.edits_made > 0:
		return "Проверь город после правок: площадь, школа, улица"
	return "Открой документ и измени первую строку мира"


func _world_log_text() -> String:
	var lines: Array[String] = []
	var watched := {
		"billboard_vanished": "Экран на площади исчез",
		"people_forgot_billboard": "Люди забыли экран",
		"nina_appeared": "Нина появилась",
		"street_name_missing": "Улица потеряла название",
		"teacher_vanished": "Учитель истории исчез",
		"disease_vanished": "Болезни исчезли",
		"hospitals_empty": "Больницы опустели",
		"police_useless": "Полиция осталась без работы",
		"economy_shaken": "Экономика шатается",
		"wrong_teacher": "Учитель вернулся неправильно",
		"weather_static": "Погода застыла",
		"utopia_cracks": "Утопия трескается",
		"free_will_missing": "Свобода воли пропала",
		"maxim_truth_revealed": "Максим узнал правду"
	}
	for key in watched:
		if WorldState.is_active(key):
			lines.append(watched[key])
	if lines.is_empty():
		return "Пока мир держит форму."
	return "\n".join(lines.slice(0, 4))


func _show_message(text: String) -> void:
	message_label.text = text
	message_label.modulate.a = 1.0
	if _message_tween and _message_tween.is_valid():
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(1.2)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.5)
