extends CharacterBody3D

# --- Settings ---
@export var walk_speed := 40.0
@export var run_speed := 45.0
@export var detection_range := 500.0 
@export var roam_range := 50.0 

# --- Combat Settings ---
@export var attack_range := 25.0  
@export var attack_damage := 10.0
@export var attack_cooldown := 1.5
@export var health := 1000.0

# --- Audio Settings (FAKE 3D) ---
@export var hearing_distance: float = 600 
# Added Max Volume Limit: Mas mababa ito, mas mahina ang max volume.
# 0.0 is Original File Volume. -20.0 makes it much quieter.
var max_scream_volume_db: float = -30.0

# --- State Variables ---
var player: Node3D = null 
var dog: Node3D = null 
var current_target: Node3D = null 

var attack_timer := 0.0
var max_health: float

# --- Audio Logic ---
var has_screamed := false 

# --- Attack State Flag ---
var is_attacking := false 

# Roaming state variables
var home_position: Vector3
var roam_target: Vector3
var is_waiting := false
var wait_timer := 0.0
var stuck_timer := 0.0

# --- Physics ---
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Node References ---
@onready var animated_sprite = $Sprite3D
@onready var detection_area = $DetectionArea 
@onready var health_bar = get_node_or_null("HealthBarDisplay/SubViewport/ProgressBar")
@onready var scream_sound = $ScreamSound 

# NOTE: Tinanggal natin ang Hitmark sound dito para hindi tumunog pag Dog ang umaatake.

func _ready():
	if attack_range < 12.0:
		attack_range = 15.0
		
	max_health = health
	if health_bar:
		health_bar.max_value = max_health
		update_health_bar()
	
	home_position = global_position
	pick_new_roam_location()
	
	if scream_sound:
		scream_sound.stop()

func update_health_bar():
	if health_bar:
		health_bar.value = health
		if health <= 0:
			health_bar.visible = false

func take_damage(amount):
	health -= amount
	update_health_bar()
	
	# --- VISUAL FLASH LANG (Walang Sound) ---
	flash_hit()
	# ----------------------------------------
	
	if health <= 0:
		die()

# --- VISUAL FLASH FUNCTION ---
func flash_hit():
	if animated_sprite:
		var tween = create_tween()
		# Sobrang liwanag na puti (Values > 1 para mag-glow)
		tween.tween_property(animated_sprite, "modulate", Color(10, 10, 10, 1), 0.05)
		# Ibalik sa normal
		tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1), 0.05)
# -----------------------------

func die():
	queue_free()

func _physics_process(delta):
	# Safe check for Player
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	
	# Safe check for Dog
	if dog == null or not is_instance_valid(dog):
		var all_dogs = get_tree().get_nodes_in_group("dog")
		for d in all_dogs:
			if d != player:
				dog = d
				break
	
	if not is_on_floor():
		velocity.y -= gravity * delta

	if health <= 0:
		return

	if attack_timer > 0:
		attack_timer -= delta

	# --- TARGET SELECTION ---
	current_target = find_nearest_target()
	
	# --- AUDIO LOGIC FIX ---
	if scream_sound and scream_sound.playing and player:
		var dist_to_player = global_position.distance_to(player.global_position)
		if dist_to_player < hearing_distance:
			# Calculate 0.0 to 1.0 volume based on distance
			var vol = clamp(1.0 - (dist_to_player / hearing_distance), 0.0, 1.0)
			
			# FIX: I-apply ang max volume offset.
			# linear_to_db(1.0) = 0dB. 0dB - 20dB = -20dB (Mas mahina)
			scream_sound.volume_db = linear_to_db(vol) + max_scream_volume_db
		else:
			# Standard mute in Godot is -80 dB
			scream_sound.volume_db = -80.0

	if current_target != null:
		if not has_screamed:
			if scream_sound:
				# Reset volume before playing to avoid sudden loud bursts
				scream_sound.volume_db = -80.0 
				scream_sound.play()
			has_screamed = true
	else:
		has_screamed = false 

	if current_target:
		process_attack_mode(delta)
	else:
		process_roaming_mode(delta) 
		
	move_and_slide()

func get_horizontal_distance_to(target_node: Node3D) -> float:
	var my_flat = Vector3(global_position.x, 0, global_position.z)
	var target_flat = Vector3(target_node.global_position.x, 0, target_node.global_position.z)
	return my_flat.distance_to(target_flat)

func find_nearest_target() -> Node3D:
	var closest_target: Node3D = null
	var closest_dist = INF

	if player and is_instance_valid(player):
		var dist = get_horizontal_distance_to(player)
		if dist < detection_range:
			closest_dist = dist
			closest_target = player

	if dog and is_instance_valid(dog):
		var dist = get_horizontal_distance_to(dog)
		if dist < detection_range and dist < closest_dist:
			closest_target = dog
	
	return closest_target

func process_roaming_mode(delta):
	if is_waiting:
		velocity.x = 0
		velocity.z = 0
		animated_sprite.play("idle")
		wait_timer -= delta
		if wait_timer <= 0:
			pick_new_roam_location()
	else:
		var direction = (roam_target - global_position).normalized()
		velocity.x = direction.x * walk_speed
		velocity.z = direction.z * walk_speed
		animated_sprite.play("walk")

		if velocity.length_squared() > 0.1:
			rotation.y = atan2(-velocity.x, -velocity.z)
			
		if velocity.length_squared() < 1.0:
			stuck_timer += delta
		else:
			stuck_timer = 0.0
			
		if is_on_wall() or stuck_timer > 1.0:
			wait_and_reset(1.0)
			return

		var dx = global_position.x - roam_target.x
		var dz = global_position.z - roam_target.z
		if (dx*dx + dz*dz) < 2.0:
			wait_and_reset(randf_range(2.0, 5.0))

func pick_new_roam_location():
	var rx = randf_range(-roam_range, roam_range)
	var rz = randf_range(-roam_range, roam_range)
	roam_target = home_position + Vector3(rx, 0, rz)
	is_waiting = false

func wait_and_reset(time):
	is_waiting = true
	wait_timer = time
	stuck_timer = 0.0

func process_attack_mode(_delta):
	if not is_instance_valid(current_target):
		current_target = null
		is_attacking = false
		return

	var dist = get_horizontal_distance_to(current_target)
	var dir_to_target = (current_target.global_position - global_position)
	rotation.y = atan2(-dir_to_target.x, -dir_to_target.z)
	
	if dist > attack_range + 1.0:
		var direction = dir_to_target.normalized()
		velocity.x = direction.x * run_speed
		velocity.z = direction.z * run_speed
		if not is_attacking:
			animated_sprite.play("walk")
			
	else:
		velocity.x = 0
		velocity.z = 0
		
		if not is_attacking:
			animated_sprite.play("idle")
		
		if attack_timer <= 0 and not is_attacking:
			if current_target.has_method("take_damage"):
				start_attack_sequence()

func start_attack_sequence():
	is_attacking = true 
	animated_sprite.play("attack")
	
	await get_tree().create_timer(0.3).timeout
	
	if is_instance_valid(current_target):
		var current_dist = get_horizontal_distance_to(current_target)
		if current_dist <= attack_range + 5.0: 
			print("DEBUG: Enemy damaging ", current_target.name)
			current_target.take_damage(attack_damage)
		else:
			print("DEBUG: Target escaped range! Dist: ", current_dist, " vs Range: ", attack_range)
	
	attack_timer = attack_cooldown
	is_attacking = false
	animated_sprite.play("idle")
