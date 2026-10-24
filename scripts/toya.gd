class_name Toya
extends CharacterBody2D

# Kecepatan sesuai spesifikasi dokumen (patroli & mengejar)
@export var patrol_speed: float = 20
@export var chase_speed: float = 50

# Referensi node
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var vision_ray: RayCast2D = $VisionRayCast
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# Variabel State & Patroli
enum State { PATROL, INVESTIGATE, CHASE, SEARCH, STUNNED, CALM }
@export var current_state: State = State.PATROL

@export var patrol_points: Array[Node2D] = [] # Daftar titik patroli di level
var current_patrol_index: int = 0

# Referensi ke pemain (bisa diisi otomatis saat game mulai)
var player: Player = null

# Parameter Persepsi Pengelihatan
var vision_range: float = 10  # Jarak lihat normal (jadi 380 jika senter pemain menyala)
var vision_angle: float = 110.0  # Sudut pandang (dalam derajat)

func _ready() -> void:
	# Mencari node player secara otomatis di grup "player"
	await get_tree().process_frame
	if get_tree().has_group("player"):
		player = get_tree().get_first_node_in_group("player")
	
	# Hubungkan target navigasi awal jika ada titik patroli
	_setup_next_patrol_point()

func _physics_process(delta: float) -> void:
	# Jangan bergerak jika sedang stun atau game pause
	if current_state == State.STUNNED:
		velocity = Vector2.ZERO
		return

	# 1. Jalankan logika deteksi pandangan (hanya jika belum di fase tenang/CALM)
	if current_state != State.CALM:
		check_player_vision()

	# 2. Perilaku berdasarkan state
	match current_state:
		State.PATROL:
			_handle_patrol(delta)
		State.CHASE:
			_handle_chase(delta)
		State.CALM:
			_handle_calm(delta)

	move_and_slide()

# --- FUNGSI DETEKSI PANDANGAN (VISION) ---
func check_player_vision() -> void:
	if not player:
		return

	var distance_to_player: float = global_position.distance_to(player.global_position)
	
	# Jarak pandang maksimal (bisa diperluas jika senter player menyala)
	var current_vision_range = vision_range

	# Syarat 1: Dalam jarak pandang jauh ATAU sangat dekat (< 80 px dari segala arah)
	if distance_to_player <= current_vision_range or distance_to_player <= 80.0:
		
		# Jika jarak di atas 80px, cek sudut pandang
		if distance_to_player > 80.0:
			var to_player = (player.global_position - global_position).normalized()
			
			# Tentukan arah hadap Toya berdasarkan kecepatannya saat ini (atau arah ke player jika patroli)
			var facing_dir = velocity.normalized()
			if facing_dir == Vector2.ZERO:
				facing_dir = Vector2.DOWN # Default jika sedang diam
				
			var angle = rad_to_deg(facing_dir.angle_to(to_player))
			if abs(angle) > (vision_angle / 2.0):
				return # Di luar sudut pandang mata Toya

		# Syarat 2: Cek Raycast (apakah terhalang tembok)
		vision_ray.target_position = vision_ray.to_local(player.global_position)
		vision_ray.force_raycast_update()
		
		if not vision_ray.is_colliding():
			# Tidak ada tembok -> TERLIHAT!
			_enter_chase_state()
		elif vision_ray.get_collider() == player:
			_enter_chase_state()

func _enter_chase_state() -> void:
	if current_state != State.CHASE:
		current_state = State.CHASE
		# print("Toya melihat pemain dan mulai mengejar!")

# --- LOGIKA GERAK PER STATE ---
func _handle_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		return
	
	if nav_agent.is_navigation_finished():
		_setup_next_patrol_point()
		return

	var next_path_pos: Vector2 = nav_agent.get_next_path_position()
	var direction: Vector2 = global_position.direction_to(next_path_pos)
	velocity = direction * patrol_speed
	anim.play("walk")

func _handle_chase(delta: float) -> void:
	if not player:
		return
	
	# Perbarui target navigasi ke posisi pemain secara berkala
	nav_agent.target_position = player.global_position
	
	if not nav_agent.is_navigation_finished():
		var next_path_pos: Vector2 = nav_agent.get_next_path_position()
		var direction: Vector2 = global_position.direction_to(next_path_pos)
		velocity = direction * chase_speed
		anim.play("chase")
	else:
		velocity = Vector2.ZERO

func _handle_calm(delta: float) -> void:
	# Fase tenang (soal 8-10): hanya mengikuti dari jauh, tidak mengejar
	if not player:
		return
	nav_agent.target_position = player.global_position
	if global_position.distance_to(player.global_position) > 200.0:
		var next_path_pos: Vector2 = nav_agent.get_next_path_position()
		velocity = global_position.direction_to(next_path_pos) * 55.0
		anim.play("walk")
	else:
		velocity = Vector2.ZERO
		anim.play("idle")

func _setup_next_patrol_point() -> void:
	if patrol_points.is_empty():
		return
	nav_agent.target_position = patrol_points[current_patrol_index].global_position
	current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
