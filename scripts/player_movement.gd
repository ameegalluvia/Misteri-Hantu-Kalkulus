class_name Player
extends CharacterBody2D

@export var walk_speed: float = 110.0
@export var run_speed: float = 190.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var flashlight: PointLight2D = $FlashlightNode

var last_direction: String = "down"
var is_flashlight_on: bool = true
var is_hidden: bool = false

func _ready() -> void:
	add_to_group("player")
	if flashlight:
		flashlight.enabled = is_flashlight_on

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("flashlight"):
		is_flashlight_on = not is_flashlight_on
		if flashlight:
			flashlight.enabled = is_flashlight_on

func _physics_process(delta: float) -> void:
	get_input()
	move_and_slide()
	
	if flashlight and flashlight.enabled:
		var mouse_pos: Vector2 = get_global_mouse_position()
		flashlight.rotation = global_position.angle_to_point(mouse_pos)

func get_input() -> void:
	var input_direction: Vector2 = Input.get_vector("left", "right", "up", "down")
	var state: String = "idle"

	if input_direction != Vector2.ZERO:
		if abs(input_direction.x) > abs(input_direction.y):
			if input_direction.x > 0:
				last_direction = "right"  
			else: 
				last_direction = "left"  
		else:
			if input_direction.y > 0:
				last_direction = "down"
			else:
				last_direction = "up"

		if Input.is_action_pressed("run"):
			state = "walk"
			velocity = input_direction * run_speed
		else:
			state = "walk"
			velocity = input_direction * walk_speed
	else:
		velocity = Vector2.ZERO
		state = "idle"

	anim.play(state + "_" + last_direction)
