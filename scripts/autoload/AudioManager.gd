extends Node
## Audio manager — handles music and sound effects.
## Supports crossfade, glitch effects, and dynamic mood shifts.

enum MusicMood {
	CALM,       # Piano + ambient
	EXPLORING,  # Synth + quiet background
	ANOMALY,    # Distorted sounds, digital interference
	ERROR,      # Humming, echo voices, radio static
	FINAL,      # Orchestral
	SILENCE     # No music
}

enum SFX {
	KEY_CLICK,
	FILE_SAVE,
	DIGITAL_GLITCH,
	WORLD_SHIFT,
	NOTEBOOK_OPEN,
	NOTEBOOK_CLOSE,
	ERROR_HUM,
	WHISPER,
	HEARTBEAT
}

var current_mood: MusicMood = MusicMood.CALM
var target_mood: MusicMood = MusicMood.CALM

# Audio players
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer

# Volume settings
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var ambient_volume: float = 0.5

# Glitch state
var is_glitching: bool = false
var glitch_timer: float = 0.0


func _ready() -> void:
	_setup_audio_players()


func _setup_audio_players() -> void:
	# Music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)

	# SFX player (one-shot sounds)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "SFX"
	add_child(sfx_player)

	# Ambient player (background layers)
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "Ambient"
	add_child(ambient_player)

	print("[AudioManager] Players set up")


## Set music mood with optional crossfade
func set_mood(mood: MusicMood, fade_duration: float = 2.0) -> void:
	if mood == current_mood:
		return

	target_mood = mood
	var stream := _get_stream_for_mood(mood)

	if stream:
		_crossfade_to(stream, fade_duration)
	else:
		music_player.stop()

	current_mood = mood
	print("[AudioManager] Mood → %s" % MusicMood.keys()[mood])


func _get_stream_for_mood(mood: MusicMood) -> AudioStream:
	# Placeholder — will load actual audio files
	match mood:
		MusicMood.CALM:
			return load("res://assets/music/calm_piano.ogg") if ResourceLoader.exists("res://assets/music/calm_piano.ogg") else null
		MusicMood.EXPLORING:
			return load("res://assets/music/exploring_synth.ogg") if ResourceLoader.exists("res://assets/music/exploring_synth.ogg") else null
		MusicMood.ANOMALY:
			return load("res://assets/music/anomaly_distorted.ogg") if ResourceLoader.exists("res://assets/music/anomaly_distorted.ogg") else null
		MusicMood.ERROR:
			return load("res://assets/music/error_hum.ogg") if ResourceLoader.exists("res://assets/music/error_hum.ogg") else null
		MusicMood.FINAL:
			return load("res://assets/music/final_orchestral.ogg") if ResourceLoader.exists("res://assets/music/final_orchestral.ogg") else null
	return null


func _crossfade_to(stream: AudioStream, duration: float) -> void:
	# Simple implementation: stop current, play new
	# TODO: implement actual crossfade with tween
	music_player.stream = stream
	music_player.volume_db = linear_to_db(music_volume)
	music_player.play()


## Play a one-shot sound effect
func play_sfx(sfx: SFX, pitch_variation: float = 0.0) -> void:
	var stream := _get_sfx_stream(sfx)
	if not stream:
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "SFX"
	player.volume_db = linear_to_db(sfx_volume)
	player.finished.connect(player.queue_free)
	if pitch_variation != 0.0:
		player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	add_child(player)
	player.play()


func _get_sfx_stream(sfx: SFX) -> AudioStream:
	match sfx:
		SFX.KEY_CLICK:
			return load("res://assets/sounds/key_click.ogg") if ResourceLoader.exists("res://assets/sounds/key_click.ogg") else null
		SFX.FILE_SAVE:
			return load("res://assets/sounds/file_save.ogg") if ResourceLoader.exists("res://assets/sounds/file_save.ogg") else null
		SFX.DIGITAL_GLITCH:
			return load("res://assets/sounds/digital_glitch.ogg") if ResourceLoader.exists("res://assets/sounds/digital_glitch.ogg") else null
		SFX.WORLD_SHIFT:
			return load("res://assets/sounds/world_shift.ogg") if ResourceLoader.exists("res://assets/sounds/world_shift.ogg") else null
		SFX.NOTEBOOK_OPEN:
			return load("res://assets/sounds/notebook_open.ogg") if ResourceLoader.exists("res://assets/sounds/notebook_open.ogg") else null
		SFX.NOTEBOOK_CLOSE:
			return load("res://assets/sounds/notebook_close.ogg") if ResourceLoader.exists("res://assets/sounds/notebook_close.ogg") else null
		SFX.ERROR_HUM:
			return load("res://assets/sounds/error_hum.ogg") if ResourceLoader.exists("res://assets/sounds/error_hum.ogg") else null
		SFX.WHISPER:
			return load("res://assets/sounds/whisper.ogg") if ResourceLoader.exists("res://assets/sounds/whisper.ogg") else null
		SFX.HEARTBEAT:
			return load("res://assets/sounds/heartbeat.ogg") if ResourceLoader.exists("res://assets/sounds/heartbeat.ogg") else null
	return null


## Trigger a screen glitch effect (audio + visual)
func trigger_glitch(duration: float = 0.5) -> void:
	is_glitching = true
	glitch_timer = duration
	play_sfx(SFX.DIGITAL_GLITCH)
	EventBus.screen_glitched.emit(duration)


func _process(delta: float) -> void:
	if is_glitching:
		glitch_timer -= delta
		if glitch_timer <= 0.0:
			is_glitching = false


## Set volume levels
func set_music_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	music_player.volume_db = linear_to_db(music_volume)


func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)


func set_ambient_volume(vol: float) -> void:
	ambient_volume = clampf(vol, 0.0, 1.0)
	ambient_player.volume_db = linear_to_db(ambient_volume)
