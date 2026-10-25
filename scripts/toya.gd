class_name Toya
extends CharacterBody2D

enum State { PATROL, INVESTIGATE, CHASE, SEARCH, STUNNED, CALM }

@export var patrol_speed: float = 20
@export var chase_speed: float = 51
@export var vision_range: float = 50
@export var near_sense_range: float = 10  
@export var vision_angle: float = 110.0
@export var lose_sight_time: float = 2.5    
@export var search_time: float = 3.0        
@export var current_state: State = State.PATROL
@export var patrol_points: Array[Node2D] = []

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var vision_ray: RayCast2D = $VisionRayCast
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var player: Player = null
var current_patrol_index: int = 0
var facing: Vector2 = Vector2.DOWN
var last_facing: String = "right"
var last_seen_position: Vector2 = Vector2.ZERO
var lost_timer: float = 0.0
var search_timer: float = 0.0

func _ready() -> void:
	nav_agent.path_desired_distance = 8.0
	nav_agent.target_desired_distance = 12.0
	await get_tree().physics_frame          # tunggu navigasi siap
	player = get_tree().get_first_node_in_group("player") as Player
	_setup_next_patrol_point()

func _physics_process(delta: float) -> void:
	if current_state == State.STUNNED:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if current_state != State.CALM:
		_check_player_vision(delta)

	match current_state:
		State.PATROL:
			_handle_patrol()
		State.CHASE:
			_handle_chase()
		State.SEARCH:
			_handle_search(delta)
		State.CALM:
			_handle_calm()

	_update_facing()
	_update_animation()
	move_and_slide()


func _check_player_vision(delta: float) -> void:
	if player == null:
		return
		
	if _can_see_player():
		last_seen_position = player.global_position
		lost_timer = 0.0
		current_state = State.CHASE
	elif current_state == State.CHASE:
		lost_timer += delta

func _can_see_player() -> bool:
	if player == null or player.is_hidden:
		return false

	var distance: float = global_position.distance_to(player.global_position)
	if distance > vision_range:
		return false


	if distance > near_sense_range:
		var to_player: Vector2 = global_position.direction_to(player.global_position)
		var angle: float = rad_to_deg(absf(facing.angle_to(to_player)))
		if angle > vision_angle / 2.0:
			return false


	vision_ray.target_position = vision_ray.to_local(player.global_position)
	vision_ray.force_raycast_update()
	if not vision_ray.is_colliding():
		return true
	return vision_ray.get_collider() == player


func _handle_patrol() -> void:
	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		return
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		_setup_next_patrol_point()
		return
	_move_along_path(patrol_speed)

func _handle_chase() -> void:
	if lost_timer >= lose_sight_time:
		_start_search()
		return
	nav_agent.target_position = last_seen_position
	_move_along_path(chase_speed)

func _start_search() -> void:
	current_state = State.SEARCH
	search_timer = search_time
	nav_agent.target_position = last_seen_position

func _handle_search(delta: float) -> void:
	if not nav_agent.is_navigation_finished():
		_move_along_path(patrol_speed)
		return
	velocity = Vector2.ZERO
	search_timer -= delta
	if search_timer <= 0.0:
		current_state = State.PATROL
		_setup_next_patrol_point()

func _handle_calm() -> void:
	if player == null:
		velocity = Vector2.ZERO
		return
	if global_position.distance_to(player.global_position) > 200.0:
		nav_agent.target_position = player.global_position
		_move_along_path(55.0)
	else:
		velocity = Vector2.ZERO

func stun(duration: float = 4.0) -> void:
	current_state = State.STUNNED
	await get_tree().create_timer(duration).timeout
	current_state = State.PATROL
	_setup_next_patrol_point()

func _move_along_path(speed: float) -> void:
	var next_path_pos: Vector2 = nav_agent.get_next_path_position()
	velocity = global_position.direction_to(next_path_pos) * speed

func _update_facing() -> void:
	if velocity.length() > 1.0:
		facing = velocity.normalized()
	if absf(velocity.x) > 1.0:
		last_facing = "right" if velocity.x > 0.0 else "left"

func _update_animation() -> void:
	var anim_name: String = ""
	
	if velocity.length() < 1.0:
		if anim.sprite_frames.has_animation("idle"):
			anim_name = "idle"
		else:
			anim_name = "idle_" + last_facing
	elif current_state == State.CHASE:
		anim_name = "run_" + last_facing
	else:
		anim_name = "walk_" + last_facing

	if anim.sprite_frames.has_animation(anim_name) and anim.animation != anim_name:
		anim.play(anim_name)

func _setup_next_patrol_point() -> void:
	if patrol_points.is_empty():
		return
	
	var target_node = patrol_points[current_patrol_index]
	if target_node != null:
		nav_agent.target_position = target_node.global_position
		
	current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
