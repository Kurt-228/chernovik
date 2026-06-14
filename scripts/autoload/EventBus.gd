extends Node
## Global event bus — decouples everything.
## Any system can emit/connect without direct references.

# World state changes
signal world_entry_added(key: String, text: String)
signal world_entry_removed(key: String)
signal world_entry_modified(key: String, old_text: String, new_text: String)

# Game flow
signal document_opened()
signal document_closed()
signal day_passed(day_number: int)
signal scene_changed(from_scene: String, to_scene: String)

# Character events
signal character_appeared(character_id: String, scene_id: String)
signal character_disappeared(character_id: String)
signal character_died(character_id: String)

# Anomalies
signal anomaly_detected(type: String, description: String)
signal error_person_appeared(person: Node)
signal world_version_changed(from_version: int, to_version: int)

# UI
signal typing_effect_finished()
signal screen_glitched(duration: float)
signal save_icon_shown()
