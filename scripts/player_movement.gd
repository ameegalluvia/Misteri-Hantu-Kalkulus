class_name Player
extends CharacterBody2D

@export var walk_speed = 200
@export var run_speed = 400

@onready var anim = $AnimatedSprite2D

var last_direction = "down"

func get_input():
	var input_direction = Input.get_vector("left", "right", "up", "down")
	var state = "idle"

	if input_direction != Vector2.ZERO:
		# tentukan arah terakhir
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

		# jalan atau lari
		if Input.is_action_pressed("run"):
			state = "walk"
			velocity = input_direction * run_speed
		else:
			state = "walk"
			velocity = input_direction * walk_speed
	else:
		velocity = Vector2.ZERO

	anim.play(state + "_" + last_direction)

func _physics_process(delta):
	get_input()
	move_and_slide()
