extends Node
## Cascade engine — every edit has consequences.
## Rules define what happens when an entry is added/removed/modified.
## Some effects are immediate, some delayed by N edits.

# Master rule table
var rules: Dictionary = {}

# Delayed effects queue: {trigger_after_edit: int, rule: Dictionary}
var delayed_effects: Array[Dictionary] = []

# Track which delayed effects have fired (avoid duplicates)
var fired_delayed: Array[String] = []


func _ready() -> void:
	_load_rules()


func _load_rules() -> void:
	rules = {
		# ── BILLBOARD ──
		"billboard_exists": {
			on_remove = [
				{add = "billboard_vanished", text = "Рекламный экран на площади исчез", immediate = true},
				{add = "people_forgot_billboard", text = "Никто не помнит о существовании рекламного экрана", immediate = true},
			]
		},

		# ── CRIME ──
		"crime_exists": {
			on_remove = [
				{add = "crime_vanished", text = "Преступность полностью исчезла из города", immediate = true},
				{add = "police_useless", text = "Полиция осталась без работы", immediate = true},
				{add = "prisons_empty", text = "Тюрьмы опустели", delay = 2},
				{add = "economy_shaken", text = "Экономика пошатнулась — тысячи людей потеряли работу в сфере безопасности", delay = 4},
			]
		},

		# ── WEATHER ──
		"weather_normal": {
			on_remove = [
				{add = "weather_static", text = "Погода застыла — больше нет ни дождя, ни ветра", immediate = true},
				{add = "crops_dying", text = "Урожай начинает гибнуть без дождя", delay = 3},
			]
		},

		# ── RAIN (player adds eternal summer) ──
		"rain_removed": {
			on_add = [
				{add = "eternal_summer", text = "В городе наступило вечное лето", immediate = true},
				{add = "drought_warning", text = "Водохранилища начали пересыхать", delay = 5},
			]
		},

		# ── LERA ──
		"lera_exists": {
			on_remove = [
				{add = "lera_vanished", text = "Лера исчезла из реальности", immediate = true},
				{add = "lera_forgotten", text = "Никто, кроме Артёма не помнит Леру", immediate = true},
				{add = "artyom_confused", text = "Артём смутно чувствует, что кого-то не хватает", delay = 2},
			]
		},

		# ── ARTYOM ──
		"artyom_exists": {
			on_remove = [
				{add = "artyom_vanished", text = "Артём исчез из реальности", immediate = true},
				{add = "maxim_alone", text = "Максим остался совсем один", immediate = true},
			]
		},

		# ── NINA (revealed after first edit) ──
		"nina_exists": {
			on_add = [
				{add = "nina_appeared", text = "Нина появилась в городе", immediate = true},
				{add = "nina_knows", text = "Нина знает о документе", immediate = true},
			]
		},

		# ── SCHOOL ──
		"school_exists": {
			on_remove = [
				{add = "school_vanished", text = "Школа №17 исчезла", immediate = true},
				{add = "students_confused", text = "Ученики не помнят где они учились", immediate = true},
				{add = "maxim_no_school", text = "Максим больше не ходит в школу", delay = 1},
			]
		},

		# ── POLICE (when crime is removed) ──
		"police_works": {
			on_remove = [
				{add = "police_dissolved", text = "Полицейский участок закрыт", immediate = true},
			]
		},

		# ── ECONOMY ──
		"economy_normal": {
			on_remove = [
				{add = "economy_collapsed", text = "Экономика города рухнула", immediate = true},
				{add = "chaos_in_streets", text = "На улицах начался хаос", delay = 2},
			]
		},

		# ── AUTHOR ──
		"author_unknown": {
			on_remove = [
				{add = "author_revealed", text = "Автор документа раскрыт", immediate = true},
			]
		},

		# ── MAXIM'S HIDDEN NATURE ──
		"maxim_program": {
			on_add = [
				{add = "maxim_truth_revealed", text = "Максим узнал правду о своей природе", immediate = true},
			]
		},

		# ── DOCUMENT ITSELF ──
		"document_found": {
			on_remove = [
				{add = "document_lost", text = "Документ утерян навсегда", immediate = true},
				{add = "world_frozen", text = "Мир больше не может быть изменён", immediate = true},
			]
		},
	}


## Main trigger — called when an entry is removed
func trigger_on_remove(key: String) -> void:
	print("[Consequences] Entry removed: %s" % key)
	if not rules.has(key):
		return
	var rule = rules[key]
	if not rule.has("on_remove"):
		return

	for effect in rule.on_remove:
		_apply_effect(effect)


## Called when an entry is added
func trigger_on_add(key: String) -> void:
	print("[Consequences] Entry added: %s" % key)
	if not rules.has(key):
		return
	var rule = rules[key]
	if not rule.has("on_add"):
		return

	for effect in rule.on_add:
		_apply_effect(effect)


## Called when an entry is modified
func trigger_on_modify(key: String, _old_text: String, new_text: String) -> void:
	print("[Consequences] Entry modified: %s → %s" % [key, new_text])
	if not rules.has(key):
		return
	var rule = rules[key]
	if not rule.has("on_modify"):
		return

	for effect in rule.on_modify:
		_apply_effect(effect)


## Apply a single effect (immediate or delayed)
func _apply_effect(effect: Dictionary) -> void:
	if effect.get("immediate", false) or not effect.has("delay"):
		_execute_effect(effect)
	elif effect.has("delay"):
		var trigger_at = WorldState.edits_made + effect.delay
		var effect_id = effect.get("add", "") + str(trigger_at)
		if effect_id in fired_delayed:
			return
		delayed_effects.append({
			"trigger_at": trigger_at,
			"effect": effect,
			"id": effect_id
		})
		print("[Consequences] Delayed effect queued: %s (fires at edit %d)" % [effect.get("add", "?"), trigger_at])


## Execute an effect immediately
func _execute_effect(effect: Dictionary) -> void:
	if effect.has("add") and effect.has("text"):
		var key: String = effect.add
		if not WorldState.entries.has(key):
			WorldState.add_entry(key, effect.text)
			print("[Consequences] Added: %s" % key)

	if effect.has("remove"):
		var key: String = effect.remove
		if WorldState.entries.has(key):
			WorldState.remove_entry(key)
			print("[Consequences] Removed: %s" % key)


## Check delayed effects — call after each edit
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
		print("[Consequences] Delayed effect fired: %s" % d.id)


## Reset for new game
func reset() -> void:
	delayed_effects.clear()
	fired_delayed.clear()
