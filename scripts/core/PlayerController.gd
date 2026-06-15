extends CharacterBody2D
## Simple WASD/Arrow movement for the player.

@export var speed: float = 200.0

var input_enabled: bool = true


func _ready() -> void:
	EventBus.document_opened.connect(func(): input_enabled = false)
	EventBus.document_closed.connect(func(): input_enabled = true)
	EventBus.ending_reached.connect(func(_ending_id: String): input_enabled = false)


func _physics_process(_delta: float) -> void:
	if not input_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y += 1.0
	input = input.normalized()
	velocity = input * speed
	move_and_slide()
