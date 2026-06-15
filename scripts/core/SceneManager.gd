extends Node
## Scene management — handles transitions between rooms/scenes.
## Tracks current scene, applies fade transitions,
## triggers world-state-dependent scene modifications.

# Current scene info
var current_scene_id: String = ""
var current_scene_node: Node = null
var previous_scene_id: String = ""
var document_overlay: Control = null
var ending_overlay: Control = null
var _error_scenes_spawned: Array[String] = []

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
@onready var dialogue_overlay: CanvasLayer = $DialogueOverlay
var tween: Tween


func _ready() -> void:
	EventBus.scene_changed.connect(_on_scene_changed)
	EventBus.ending_reached.connect(_on_ending_reached)
	EventBus.world_entry_removed.connect(_on_world_entry_removed)
	EventBus.world_entry_added.connect(_on_world_entry_added)
	EventBus.world_entry_modified.connect(func(_key: String, _old_text: String, _new_text: String): _on_world_edited())
	call_deferred("go_to_scene", GameProgress.current_scene_id, 0.0)


## Go to a scene by ID
func go_to_scene(scene_id: String, fade_duration: float = 1.0) -> void:
	if not SCENES.has(scene_id):
		push_error("[SceneManager] Unknown scene: %s" % scene_id)
		return

	await _fade_out(fade_duration)

	previous_scene_id = current_scene_id
	current_scene_id = scene_id
	GameProgress.current_scene_id = scene_id

	# Unload current scene
	if current_scene_node:
		current_scene_node.queue_free()

	# Load new scene
	var scene_path = SCENES[scene_id]
	var packed = load(scene_path)
	if packed:
		current_scene_node = packed.instantiate()
		add_child(current_scene_node)
		move_child(current_scene_node, 0)
		print("[SceneManager] Loaded: %s" % scene_id)
	else:
		push_error("[SceneManager] Failed to load: %s" % scene_path)

	EventBus.scene_changed.emit(previous_scene_id, current_scene_id)

	await _fade_in(fade_duration)
	call_deferred("_run_scene_story", scene_id)


## Open document overlay (doesn't change scene, overlays on top)
func open_document() -> void:
	if document_overlay and is_instance_valid(document_overlay):
		return
	var doc_path = SCENES["document"]
	var packed = load(doc_path)
	if packed:
		document_overlay = packed.instantiate()
		document_overlay.name = "DocumentOverlay"
		document_overlay.tree_exited.connect(func(): document_overlay = null)
		add_child(document_overlay)
		EventBus.document_opened.emit()
		print("[SceneManager] Document opened")


func _on_ending_reached(ending_id: String) -> void:
	if ending_overlay and is_instance_valid(ending_overlay):
		return
	if document_overlay and is_instance_valid(document_overlay):
		document_overlay.queue_free()

	var packed = load(SCENES["ending_screen"])
	if not packed:
		push_error("[SceneManager] Failed to load ending screen")
		return

	ending_overlay = packed.instantiate()
	add_child(ending_overlay)
	ending_overlay.show_ending(ending_id)


func _run_scene_story(scene_id: String) -> void:
	_show_scene_intro(scene_id)
	_maybe_spawn_error_person()


func _show_scene_intro(scene_id: String) -> void:
	match scene_id:
		"bedroom":
			_dialogue_once("intro_bedroom", "maxim", "Обычная комната. Компьютер, стол, кровать. И чувство, будто кто-то уже правил этот день до меня.")
		"school":
			if WorldState.is_active("lera_exists"):
				_dialogue_once("intro_school_lera", "lera", "Ты сегодня странный. Смотришь на людей так, будто проверяешь, настоящие ли они.")
			if WorldState.is_active("artyom_exists"):
				_dialogue_once("intro_school_artyom", "artyom", "Если ты опять про пропавшие предметы, я всё ещё голосую за сон и недосып.")
			if not WorldState.is_active("school_exists"):
				_dialogue_once("school_erased_intro", "maxim", "Здесь должна быть школа. Память держит форму здания, но мир уже не обязан ей подчиняться.")
		"city_square":
			if WorldState.is_active("billboard_exists"):
				_dialogue_once("intro_square_billboard", "maxim", "Рекламный экран на площади раздражал всех. Именно поэтому я уверен: он был здесь.")
			else:
				_dialogue_once("intro_square_no_billboard", "maxim", "Пустое место. Никто даже не понимает, почему я смотрю на стену.")
			if WorldState.is_active("nina_exists"):
				_dialogue_once("intro_nina", "nina", "Ты нашёл документ. Значит, старая версия снова проиграла.")
		"street":
			if WorldState.is_active("crime_exists"):
				_dialogue_once("intro_street_crime", "maxim", "Улица кажется обычной. Именно это и пугает: обычность тоже можно стереть.")
			else:
				_dialogue_once("intro_street_no_crime", "maxim", "Преступность исчезла, но люди не стали добрее. Они просто потеряли слово для того, что делают.")
		"abandoned_apartment":
			_dialogue_once("intro_apartment", "maxim", "Здесь пахнет пылью и перегретым пластиком. Ноутбук ждал не владельца. Он ждал редактора.")
			if WorldState.is_active("author_notes_visible"):
				_dialogue_once("author_notes_found", "author", "Максим не должен был знать, что он строка. Но хороший инструмент рано или поздно читает инструкцию.")


func _on_world_entry_removed(key: String) -> void:
	match key:
		"billboard_exists":
			_dialogue_once("react_removed_billboard", "maxim", "Экран исчез. Не сломался, не погас. Его никогда не было. Кроме как в моей голове.")
		"lera_exists":
			_dialogue_once("react_removed_lera", "maxim", "Я помню Леру. Мир нет. Это не делает меня правым.")
		"artyom_exists":
			_dialogue_once("react_removed_artyom", "maxim", "Артём бы сказал, что я сошёл с ума. Теперь даже некому это сказать.")
		"crime_exists":
			_dialogue_once("react_removed_crime", "maxim", "Я убрал преступность. Слово исчезло быстрее, чем причины.")
		"disease_exists":
			_dialogue_once("react_removed_disease", "maxim", "Болезни исчезли. В больницах тихо так, будто оттуда удалили не боль, а смысл.")
		"school_exists":
			_dialogue_once("react_removed_school", "maxim", "Школа исчезла из города так тихо, будто её стёрли ластиком.")
		"street_name_mira":
			_dialogue_once("react_removed_street_name", "maxim", "Таблички на улице пустые. Я всё ещё знаю название, но уже не уверен, что оно моё.")
		"teacher_exists":
			_dialogue_once("react_removed_teacher", "maxim", "Сергей Павлович исчез. Лера спрашивает, почему у нас всегда был свободный урок истории.")
	_maybe_spawn_error_person()


func _on_world_entry_added(key: String, _text: String) -> void:
	match key:
		"nina_appeared":
			_dialogue_once("react_nina_appeared", "nina", "Не бойся. Я не из твоего мира. Хотя после пары правок ты тоже уже не совсем из него.")
		"wrong_teacher":
			_dialogue_once("react_wrong_teacher", "lera", "Учитель вернулся, но он назвал меня другим именем. Максим, что ты сделал?")
		"teacher_vanished":
			_dialogue_once("react_teacher_vanished", "artyom", "Истории больше нет в расписании. И никто не считает это странным.")
		"class_envy":
			_dialogue_once("react_rich_maxim", "artyom", "Вчера у тебя не было денег на булочку. Сегодня у твоей семьи три квартиры. Объясни нормально.")
		"maxim_truth_revealed":
			_dialogue_once("react_truth", "author", "Ты не нашёл документ, Максим. Документ нашёл способ открыть самого себя.")
		"author_notes_visible":
			_dialogue_once("react_author_notes", "maxim", "Заметки Автора выглядят как предупреждения. Или как оправдания.")
		"weather_static":
			_dialogue_once("react_weather_static", "nina", "Идеальная погода — первый признак мира, который перестал дышать.")
		"utopia_cracks":
			_dialogue_once("react_utopia_cracks", "nina", "Идеальный мир не ломается громко. Он просто перестаёт оставлять место живым людям.")
		"free_will_missing":
			_dialogue_once("react_free_will_missing", "author", "Подчинение — самый короткий путь к порядку. И самый верный путь к пустоте.")
	_maybe_spawn_error_person()


func _on_world_edited() -> void:
	_maybe_spawn_error_person()


func _maybe_spawn_error_person() -> void:
	if not current_scene_node:
		return
	if current_scene_id in ["bedroom", "void"]:
		return
	if not GameProgress.errors_appeared and WorldState.edits_made < GameProgress.edits_before_errors:
		return
	if current_scene_id in _error_scenes_spawned:
		return

	var packed = load("res://scenes/characters/error_person.tscn")
	if not packed:
		return

	var error_person = packed.instantiate()
	current_scene_node.add_child(error_person)
	error_person.global_position = _error_position_for_scene(current_scene_id)
	if error_person.has_method("initialize"):
		error_person.initialize(WorldState.create_snapshot(), _last_edit_key())
	_error_scenes_spawned.append(current_scene_id)
	EventBus.error_person_appeared.emit(error_person)
	_dialogue_once("error_person_first_seen", "error", "Ты меня не создавал. Ты меня оставил между версиями.")


func _error_position_for_scene(scene_id: String) -> Vector2:
	match scene_id:
		"school":
			return Vector2(920, 430)
		"city_square":
			return Vector2(1280, 430)
		"street":
			return Vector2(1380, 520)
		"abandoned_apartment":
			return Vector2(620, 520)
	return Vector2(960, 540)


func _last_edit_key() -> String:
	if WorldState.edit_history.is_empty():
		return ""
	return str(WorldState.edit_history.back().get("key", ""))


func _dialogue_once(id: String, character_id: String, text: String) -> void:
	if GameProgress.has_seen_dialogue(id):
		return
	GameProgress.mark_dialogue_seen(id)
	_start_dialogue(character_id, text)


func _start_dialogue(character_id: String, text: String) -> void:
	if dialogue_overlay and dialogue_overlay.has_method("start_dialogue"):
		dialogue_overlay.start_dialogue(character_id, text)


func _fade_out(duration: float) -> void:
	if duration <= 0.0:
		transition_rect.color.a = 1.0
		transition_rect.visible = true
		return
	transition_rect.visible = true
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 1.0, duration)
	await tween.finished


func _fade_in(duration: float) -> void:
	if duration <= 0.0:
		transition_rect.color.a = 0.0
		transition_rect.visible = false
		return
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
