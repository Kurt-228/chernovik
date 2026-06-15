extends Node
## Cascade engine — listens to EventBus, applies consequence rules.
## Fully event-driven: WorldState never calls Consequences directly.
##
## Flow: EventBus.entry_removed → Consequences.trigger_on_remove
##       → new entries added via WorldState.add_entry
##       → EventBus.entry_added → Consequences.trigger_on_add
##       → ... (cascade continues with guard against recursion)

# Master rule table
var rules: Dictionary = {}

# Delayed effects queue
var delayed_effects: Array[Dictionary] = []

# Fired delayed effect IDs (avoid duplicates)
var fired_delayed: Array[String] = []

# RECURSION GUARD: effects being processed right now
# Prevents A→B→A infinite loops
var _processing: Array[String] = []
# Max cascade depth (safety limit)
const MAX_CASCADE_DEPTH := 50


func _ready() -> void:
	_load_rules()
	# Subscribe to EventBus — the ONLY way Consequences activates
	EventBus.world_entry_removed.connect(_on_entry_removed)
	EventBus.world_entry_added.connect(_on_entry_added)
	EventBus.world_entry_modified.connect(_on_entry_modified)


func _load_rules() -> void:
	rules = {
		# ── BILLBOARD ──
		"billboard_exists": {
			on_remove = [
				{add = "billboard_vanished",     text = "Рекламный экран на площади исчез"},
				{add = "people_forgot_billboard", text = "Никто не помнит о существовании рекламного экрана"},
			]
		},

		# ── CRIME ──
		"crime_exists": {
			on_remove = [
				{add = "crime_vanished",  text = "Преступность полностью исчезла из города"},
				{add = "police_useless",  text = "Полиция осталась без работы"},
				{add = "prisons_empty",   text = "Тюрьмы опустели",            delay = 2},
				{add = "economy_shaken",  text = "Экономика пошатнулась — тысячи людей потеряли работу", delay = 4},
			]
		},

		"disease_exists": {
			on_remove = [
				{add = "disease_vanished", text = "Болезни исчезли из города"},
				{add = "hospitals_empty", text = "Больницы опустели за одну ночь"},
				{add = "doctors_lost_purpose", text = "Врачи не понимают, зачем учились спасать людей", delay = 2},
			]
		},

		# ── POLICE ──
		"police_works": {
			on_remove = [
				{add = "police_dissolved", text = "Полицейский участок закрыт"},
			]
		},

		# ── WEATHER ──
		"weather_normal": {
			on_remove = [
				{add = "weather_static", text = "Погода застыла — больше нет ни дождя, ни ветра"},
				{add = "crops_dying",    text = "Урожай начинает гибнуть без дождя", delay = 3},
			]
		},

		"street_name_mira": {
			on_remove = [
				{add = "street_name_missing", text = "Название улицы исчезло со всех табличек"},
				{add = "people_forget_addresses", text = "Жители путают адреса, которыми пользовались всю жизнь"},
			]
		},

		# ── ETERNAL SUMMER (player adds this) ──
		"eternal_summer": {
			on_add = [
				{add = "drought_warning", text = "Водохранилища начали пересыхать", delay = 5},
				{add = "weather_static", text = "Погода застыла — больше нет ни дождя, ни ветра"},
			]
		},

		"maxim_rich": {
			on_add = [
				{add = "class_envy", text = "Одноклассники смотрят на Максима с завистью"},
				{add = "artyom_suspicious", text = "Артём уверен, что Максим что-то скрывает", delay = 1},
			]
		},

		"teacher_returned": {
			on_add = [
				{add = "teacher_exists", text = "В школе №17 работает учитель истории Сергей Павлович"},
				{add = "wrong_teacher", text = "Учитель вернулся, но помнит другой класс"},
				{add = "school_records_changed", text = "Школьные журналы переписались сами собой", delay = 1},
			]
		},

		# ── LERA ──
		"lera_exists": {
			on_remove = [
				{add = "lera_vanished",    text = "Лера исчезла из реальности"},
				{add = "lera_forgotten",   text = "Никто не помнит Леру"},
				{add = "artyom_confused",  text = "Артём смутно чувствует, что кого-то не хватает", delay = 2},
			]
		},

		# ── ARTYOM ──
		"artyom_exists": {
			on_remove = [
				{add = "artyom_vanished", text = "Артём исчез из реальности"},
				{add = "maxim_alone",     text = "Максим остался совсем один"},
			]
		},

		# ── NINA ──
		"nina_exists": {
			on_add = [
				{add = "nina_appeared", text = "Нина появилась в городе"},
				{add = "nina_knows",    text = "Нина знает о документе"},
			]
		},

		# ── SCHOOL ──
		"school_exists": {
			on_remove = [
				{add = "school_vanished",    text = "Школа №17 исчезла"},
				{add = "students_confused",  text = "Ученики не помнят где они учились"},
				{add = "maxim_no_school",    text = "Максим больше не ходит в школу", delay = 1},
			]
		},

		"teacher_exists": {
			on_remove = [
				{add = "teacher_vanished", text = "Учитель истории исчез из расписания и памяти учеников"},
				{add = "history_lessons_empty", text = "Кабинет истории пустует", delay = 1},
			]
		},

		# ── ECONOMY ──
		"economy_normal": {
			on_remove = [
				{add = "economy_collapsed", text = "Экономика города рухнула"},
				{add = "chaos_in_streets",  text = "На улицах начался хаос", delay = 2},
			]
		},

		# ── AUTHOR ──
		"author_unknown": {
			on_remove = [
				{add = "author_revealed", text = "Автор документа раскрыт"},
			]
		},

		"author_revealed": {
			on_add = [
				{add = "author_notes_visible", text = "В документе появились заметки предыдущего Автора"},
				{add = "maxim_program", text = "Максим является программой внутри документа", delay = 1},
			]
		},

		"perfect_city": {
			on_add = [
				{add = "perfect_order", text = "Город стал идеально чистым и послушным"},
				{add = "people_stop_arguing", text = "Люди перестали спорить даже о важном"},
				{add = "utopia_cracks", text = "Идеальный город начал трескаться по краям", delay = 3},
			]
		},

		"all_obey_maxim": {
			on_add = [
				{add = "maxim_feared", text = "Все боятся расстроить Максима"},
				{add = "free_will_missing", text = "Люди улыбаются до того, как понимают почему"},
			]
		},

		# ── MAXIM'S HIDDEN NATURE ──
		"maxim_program": {
			on_add = [
				{add = "maxim_truth_revealed", text = "Максим узнал правду о своей природе"},
			]
		},

		# ── DOCUMENT ITSELF ──
		"document_found": {
			on_remove = [
				{add = "document_lost",  text = "Документ утерян навсегда"},
				{add = "world_frozen",   text = "Мир больше не может быть изменён"},
			]
		},
	}


## ── EVENT HANDLERS (called by EventBus) ───────────────────────────

func _on_entry_removed(key: String) -> void:
	_trigger("on_remove", key)


func _on_entry_added(key: String, _text: String) -> void:
	_trigger("on_add", key)


func _on_entry_modified(key: String, _old_text: String, _new_text: String) -> void:
	_trigger("on_modify", key)


## ── CORE TRIGGER WITH RECURSION GUARD ──────────────────────────────

func _trigger(trigger_type: String, key: String) -> void:
	# Recursion guard: if we're already processing consequences for this key+type, skip
	var guard_id = "%s:%s" % [trigger_type, key]
	if guard_id in _processing:
		return
	if _processing.size() >= MAX_CASCADE_DEPTH:
		push_warning("[Consequences] CASCADE DEPTH LIMIT REACHED at %s" % guard_id)
		return

	_processing.append(guard_id)

	if not rules.has(key):
		_processing.erase(guard_id)
		return

	var rule = rules[key]
	if not rule.has(trigger_type):
		_processing.erase(guard_id)
		return

	print("[Consequences] %s → %s" % [key, trigger_type])

	for effect in rule[trigger_type]:
		_apply_effect(effect)

	_processing.erase(guard_id)


## ── APPLY EFFECT ───────────────────────────────────────────────────

func _apply_effect(effect: Dictionary) -> void:
	if effect.has("delay"):
		var trigger_at = WorldState.edits_made + effect.delay
		var effect_id = effect.get("add", effect.get("remove", "?")) + "_d%d" % trigger_at
		if effect_id in fired_delayed:
			return
		delayed_effects.append({
			"trigger_at": trigger_at,
			"effect":     effect,
			"id":         effect_id
		})
		print("[Consequences] Delayed queued: %s (fires at edit %d)" % [effect_id, trigger_at])
	else:
		_execute_effect(effect)


func _execute_effect(effect: Dictionary) -> void:
	if effect.has("add") and effect.has("text"):
		var key: String = effect.add
		if not WorldState.entries.has(key) or not WorldState.is_active(key):
			WorldState.add_entry(key, effect.text)
			print("[Consequences] Added: %s" % key)

	if effect.has("remove"):
		var key: String = effect.remove
		if WorldState.entries.has(key) and WorldState.is_active(key):
			WorldState.remove_entry(key)
			print("[Consequences] Removed: %s" % key)


## ── DELAYED EFFECTS ────────────────────────────────────────────────

## Call this after each edit to check if any delayed effects should fire
func process_delayed() -> void:
	var current_edit = WorldState.edits_made
	var to_fire: Array[Dictionary] = []

	for delayed in delayed_effects:
		if current_edit >= delayed.trigger_at:
			to_fire.append(delayed)

	for d in to_fire:
		delayed_effects.erase(d)
		fired_delayed.append(d.id)
		_execute_effect(d.effect)
		print("[Consequences] Delayed fired: %s" % d.id)


func reset() -> void:
	delayed_effects.clear()
	fired_delayed.clear()
	_processing.clear()
