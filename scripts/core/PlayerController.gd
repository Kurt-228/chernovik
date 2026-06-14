extends CharacterBody2D
## Simple WASD/Arrow movement for the player.

@export var speed: float = 200.0


func _physics_process(_delta: float) -> void:
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input * speed
	move_and_slide()
