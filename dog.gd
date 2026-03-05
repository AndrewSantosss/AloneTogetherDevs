extends CharacterBody3D

# --- Settings ---
@export var walk_speed := 6.0 	 	
@export var run_speed := 14.0 	 	
@export var roam_range := 15.0
@export var scavenge_range := 5000.0 # High range to find items anywhere

# --- Combat Settings ---
@export var health := 90.0 
@export var damage := 20
@export var attack_range := 6.0 
@export var attack_cooldown := 3

# --- POSITIONS ---
@export var follow_offset := Vector3(1.2, 0, 1.5) 

# --- TELEPORT SETTINGS ---
@export var teleport_distance := 500.0  
@export var teleport_offset := Vector3(0, 2, -2)

# --- FINAL X-RAY SILHOUETTE SHADER ---
const SILHOUETTE_SHADER = """
shader_type spatial;
// depth_test_disabled para makita sa likod ng pader
render_mode unshaded, depth_test_disabled, cull_disabled;

uniform sampler2D texture_albedo : source_color, filter_nearest;
uniform vec4 silhouette_color : source_color = vec4(0.0, 1.0, 0.0, 0.4);

void vertex() {
	// Y-BILLBOARD ONLY Math para sakto ang alignment
	mat4 modified_model_view = VIEW_MATRIX * mat4(
		vec4(MODEL_MATRIX[0].xyz, 0.0), 
		vec4(MODEL_MATRIX[1].xyz, 0.0), 
		vec4(MODEL_MATRIX[2].xyz, 0.0), 
		vec4(MODEL_MATRIX[3].xyz, 1.0)
	);
	modified_model_view[0] = vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0);
	modified_model_view[1] = vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0);
	modified_model_view[2] = vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0);
	MODELVIEW_MATRIX = modified_model_view;
}

void fragment() {
	vec4 tex = texture(texture_albedo, UV);
	// Gamitin ang 0.9 para malinis ang edges base sa Nearest filtering mo
	if (tex.a < 0.9) {
		discard;
	}
	ALBEDO = silhouette_color.rgb;
	ALPHA = silhouette_color.a;
}
"""
var silhouette_material: ShaderMaterial

# --- State Variables ---
var can_scavenge := false # Locked by default (unlocked by NPC)
var is_roaming := false
var is_scavenging := false 
var player: Node3D = null
var target_enemy: Node3D = null
var target_item: Node3D = null 
var is_attacking := false
var is_dead := false

# --- Logic Variables ---
var home_position: Vector3
var roam_target: Vector3
var is_waiting := false
var wait_timer := 0.0
var stuck_timer := 0.0
var attack_timer := 0.0
var max_health: float

# --- ANIMATION STATE VARIABLES ---
var idle_timer := 0.0
var is_sitting := false
var last_facing_dir := "side" 
var sit_transition_started := false
var time_to_sit := 3.0 

# --- Physics ---
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Node References ---
@onready var animated_sprite = $Sprite3D
@onready var detection_area = $DetectionArea 
@onready var loot_indicator = get_node_or_null("LootIndicator") 
var ui_health_bar: ProgressBar = null

func _ready():
	if not is_in_group("dog"):
		add_to_group("dog")
	
	player = get_tree().get_first_node_in_group("player")
	home_position = global_position
	# This function calls pick_new_roam_location, which was missing before
	pick_new_roam_location() 
	max_health = health
	randomize_sit_timer()
	
	if loot_indicator:
		loot_indicator.visible = false
	
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	
	await get_tree().process_frame 
	ui_health_bar = get_tree().get_first_node_in_group("dog_ui")
	
	if ui_health_bar == null:
		ui_health_bar = get_node_or_null("/root/Scene3/SubViewportContainer/Healthbar/DogHealthBar")
	
	if ui_health_bar:
		ui_health_bar.max_value = max_health
		ui_health_bar.value = health
		ui_health_bar.visible = true

	if player:
		add_collision_exception_with(player)
		
	if player:
		add_collision_exception_with(player)

	# --- SETUP SILHOUETTE MATERIAL ---
	if animated_sprite:
		var shader = Shader.new()
		shader.code = SILHOUETTE_SHADER
		silhouette_material = ShaderMaterial.new()
		silhouette_material.shader = shader
		
		# Priority 1 para ma-draw ito PAGKATAPOS ng main sprite 
		silhouette_material.render_priority = -1 
		
		# Gamitin ang material_override para sa main pass, tapos next_pass para sa silhouette
		# O kaya, i-set ang material_overlay pero siguraduhing mataas ang priority
		animated_sprite.material_overlay = silhouette_material

func _input(event):
	# Toggle Roaming [T]
	if event.is_action_pressed("toggle_dog_mode") or (event is InputEventKey and event.pressed and event.keycode == KEY_T):
		is_roaming = !is_roaming
		reset_scavenge()
		target_enemy = null 
		is_attacking = false
		
		if is_roaming:
			print("Dog Mode: FREE ROAM")
			home_position = global_position 
			pick_new_roam_location()
		else:
			print("Dog Mode: FOLLOW PLAYER")

	# Toggle Scavenge [Q]
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		if can_scavenge:
			trigger_scavenge()
		else:
			print("Dog doesn't know how to scavenge yet.")

func trigger_scavenge():
	print("Dog is sniffing for loot...")
	if loot_indicator: loot_indicator.visible = false
	target_item = find_nearest_loot()
	
	if target_item:
		is_scavenging = true
		is_roaming = false
		target_enemy = null
		print("Dog found loot: ", target_item.name)
	else:
		print("Dog found nothing nearby.")

func reset_scavenge():
	is_scavenging = false
	target_item = null
	if loot_indicator: loot_indicator.visible = false

func _on_detection_area_body_entered(body):
	if body != self and body != player and body.is_in_group("enemies"):
		if target_enemy == null:
			print("Dog spotted enemy: ", body.name)
			target_enemy = body

func heal(amount):
	health += amount
	if health > max_health:
		health = max_health
	if ui_health_bar:
		ui_health_bar.value = health
	print("Dog healed. Current Health: ", health)

func take_damage(amount):
	health -= amount
	if ui_health_bar:
		ui_health_bar.value = health
		# --- HEALTH BAR FLASH ---
		var bar_tween = create_tween()
		ui_health_bar.modulate = Color(3, 0, 0, 1) # Overbright Red
		bar_tween.tween_property(ui_health_bar, "modulate", Color.WHITE, 0.4)
		
	# --- RED SILHOUETTE FLASH ---
	if animated_sprite and silhouette_material:
		var flash_tween = create_tween()
		var original_color = Color(0.0, 1.0, 0.0, 0.4) # Yung dating green
		var red_flash_solid = Color(5.0, 0.0, 0.0, 1.0) 
		
		silhouette_material.set_shader_parameter("silhouette_color", red_flash_solid)
		animated_sprite.modulate.a = 0.0 # Itago ang sprite details
		
		# Fade back ang kulay at ang transparency ng main sprite
		flash_tween.tween_method(func(c): silhouette_material.set_shader_parameter("silhouette_color", c), red_flash_solid, original_color, 0.4)
		flash_tween.parallel().tween_property(animated_sprite, "modulate:a", 1.0, 0.4)
		
	if health <= 0:
		die()

func die():
	if is_dead: return
	is_dead = true
	print("Dog has died!")
	if ui_health_bar:
		ui_health_bar.value = 0
	play_anim_safe("death (side)")
	set_physics_process(false)

func _physics_process(delta):
	if is_dead: return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if attack_timer > 0:
		attack_timer -= delta

	check_teleport_to_player()

	if target_enemy != null and not is_instance_valid(target_enemy):
		target_enemy = null
		is_attacking = false
		find_nearest_enemy() 
		
	if target_item != null and not is_instance_valid(target_item):
		reset_scavenge()

	# --- MOVEMENT PRIORITY ---
	if is_instance_valid(target_enemy):
		if loot_indicator: loot_indicator.visible = false
		velocity = get_combat_velocity()
	elif is_scavenging and is_instance_valid(target_item):
		velocity = get_scavenge_velocity(delta)
	elif is_roaming:
		if loot_indicator: loot_indicator.visible = false
		velocity = get_roaming_velocity(delta)
	elif player:
		if loot_indicator: loot_indicator.visible = false
		velocity = get_follow_velocity()
		if target_enemy == null:
			find_nearest_enemy()
	else:
		velocity.x = 0
		velocity.z = 0

	move_and_slide()
	handle_animations(delta)
	
	move_and_slide()
	handle_animations(delta)

	# --- UPDATE SILHOUETTE TEXTURE ---
	if animated_sprite and silhouette_material:
		var anim = animated_sprite.animation
		if animated_sprite.sprite_frames:
			var current_tex = animated_sprite.sprite_frames.get_frame_texture(anim, animated_sprite.frame)
			silhouette_material.set_shader_parameter("texture_albedo", current_tex)

# =========================================================
#               HELPER FUNCTIONS (Restored)
# =========================================================

func handle_animations(delta):
	if is_attacking: return
	
	if velocity.length_squared() > 0.1:
		idle_timer = 0.0
		is_sitting = false
		sit_transition_started = false
		randomize_sit_timer()
		
		var x_mag = abs(velocity.x)
		var z_mag = abs(velocity.z)
		
		# Hysteresis Logic
		var z_advantage = 1.0
		if last_facing_dir == "front" or last_facing_dir == "back":
			z_advantage = 2.0 
		else:
			z_advantage = 0.8 
			
		if z_mag * z_advantage > x_mag:
			if velocity.z > 0:
				last_facing_dir = "front"
				play_anim_safe("walk front", "walk")
			else:
				last_facing_dir = "back"
				play_anim_safe("walk back", "walk")
			animated_sprite.flip_h = false
		else:
			last_facing_dir = "side"
			play_anim_safe("walk")
			if velocity.x < 0:
				animated_sprite.flip_h = true 
			else:
				animated_sprite.flip_h = false 
				
	else:
		# Sit immediately if scavenging and found item
		if is_scavenging and is_instance_valid(target_item):
			if not is_sitting:
				start_sitting_down()
		else:
			idle_timer += delta
			if idle_timer >= time_to_sit:
				if not is_sitting:
					start_sitting_down()
			else:
				play_standing_idle()

func randomize_sit_timer():
	time_to_sit = randf_range(2.5, 6.0)

func play_standing_idle():
	if last_facing_dir == "front":
		play_anim_safe("idle front (standing)", "idle")
	elif last_facing_dir == "back":
		play_anim_safe("idle back (standing)", "idle")
	else: 
		play_anim_safe("idle")

func start_sitting_down():
	if sit_transition_started: return
	sit_transition_started = true
	
	if last_facing_dir == "back":
		if not play_anim_safe("idle sitting (back)"): _on_animation_finished() 
	elif last_facing_dir == "front":
		if not play_anim_safe("sitting"): _on_animation_finished()
	else: 
		if not play_anim_safe("sitting"): _on_animation_finished()

func _on_animation_finished():
	if sit_transition_started and not is_sitting:
		var current_anim = animated_sprite.animation
		if current_anim == "idle sitting (back)" or current_anim == "sitting":
			is_sitting = true
			if last_facing_dir == "front":
				play_anim_safe("idle dog sitting (front)", "idle back (sit)")
			elif last_facing_dir == "back":
				play_anim_safe("idle back (sit)", "idle dog sitting (front)")
			else:
				play_anim_safe("idle dog sitting (front)") 
				
	if animated_sprite.animation == "attack":
		is_attacking = false

func play_anim_safe(anim_name, fallback = ""):
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
		return true
	elif fallback != "" and animated_sprite.sprite_frames.has_animation(fallback):
		animated_sprite.play(fallback)
		return true
	return false

# --- MOVEMENT CALCULATORS ---

func find_nearest_loot() -> Node3D:
	var loot_items = get_tree().get_nodes_in_group("loot")
	var closest = null
	var closest_dist = scavenge_range
	
	# Priority for Medkits
	var priority_items = []
	for item in loot_items:
		if is_instance_valid(item) and "medkit" in item.name.to_lower():
			priority_items.append(item)
	
	var search_list = priority_items if priority_items.size() > 0 else loot_items
	
	for item in search_list:
		if is_instance_valid(item):
			var dist = global_position.distance_to(item.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest = item
	return closest

func get_scavenge_velocity(delta) -> Vector3:
	var dist = global_position.distance_to(target_item.global_position)
	if dist > 2.5:
		if loot_indicator: loot_indicator.visible = false
		var direction = (target_item.global_position - global_position).normalized()
		if abs(direction.z) > abs(direction.x):
			last_facing_dir = "front" if direction.z > 0 else "back"
			animated_sprite.flip_h = false
		else:
			last_facing_dir = "side"
			animated_sprite.flip_h = (direction.x < 0)
		return Vector3(direction.x * run_speed, velocity.y, direction.z * run_speed)
	else:
		if loot_indicator: loot_indicator.visible = true
		return Vector3(0, velocity.y, 0)

func get_combat_velocity() -> Vector3:
	if target_enemy.has_method("get_health") and target_enemy.get_health() <= 0:
		target_enemy = null
		is_attacking = false
		return Vector3.ZERO
	var dist = global_position.distance_to(target_enemy.global_position)
	if dist > attack_range:
		var direction = (target_enemy.global_position - global_position).normalized()
		if abs(direction.z) > abs(direction.x):
			last_facing_dir = "front" if direction.z > 0 else "back"
			animated_sprite.flip_h = false
		else:
			last_facing_dir = "side"
			animated_sprite.flip_h = (direction.x < 0)
		return Vector3(direction.x * run_speed, velocity.y, direction.z * run_speed)
	else:
		if attack_timer <= 0:
			perform_attack()
		return Vector3(0, velocity.y, 0)

func perform_attack():
	is_attacking = true
	if last_facing_dir == "side":
		if target_enemy:
			var dir_to_enemy = target_enemy.global_position.x - global_position.x
			animated_sprite.flip_h = (dir_to_enemy < 0)
	else:
		animated_sprite.flip_h = false
	play_anim_safe("attack")
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(target_enemy) and target_enemy.has_method("take_damage"):
		var dist = global_position.distance_to(target_enemy.global_position)
		if dist <= attack_range + 2.0:
			target_enemy.take_damage(damage)
	attack_timer = attack_cooldown

func get_follow_velocity() -> Vector3:
	var target_pos = player.to_global(follow_offset)
	var dist_sq = global_position.distance_squared_to(target_pos)
	var target_speed = walk_speed
	if "is_sprinting" in player and player.is_sprinting:
		target_speed = run_speed
	if dist_sq > 2.0:
		var direction = (target_pos - global_position).normalized()
		return Vector3(direction.x * target_speed, velocity.y, direction.z * target_speed)
	return Vector3(0, velocity.y, 0)

func get_roaming_velocity(delta) -> Vector3:
	if target_enemy == null:
		find_nearest_enemy()
	if is_waiting:
		wait_timer -= delta
		if wait_timer <= 0:
			pick_new_roam_location()
		return Vector3(0, velocity.y, 0)
	else:
		var direction = (roam_target - global_position).normalized()
		if Vector2(velocity.x, velocity.z).length_squared() < 1.0:
			stuck_timer += delta
		else:
			stuck_timer = 0.0
		if is_on_wall() or stuck_timer > 1.0:
			wait_and_reset(1.0)
			return Vector3(0, velocity.y, 0)
		var dx = global_position.x - roam_target.x
		var dz = global_position.z - roam_target.z
		if (dx*dx + dz*dz) < 2.25:
			wait_and_reset(randf_range(2.0, 5.0))
			return Vector3(0, velocity.y, 0)
		return Vector3(direction.x * walk_speed, velocity.y, direction.z * walk_speed)

func pick_new_roam_location():
	var rx = randf_range(-roam_range, roam_range)
	var rz = randf_range(-roam_range, roam_range)
	roam_target = home_position + Vector3(rx, 0, rz)
	is_waiting = false

func check_teleport_to_player():
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist > teleport_distance:
			global_position = player.global_position + teleport_offset
			velocity = Vector3.ZERO

func find_nearest_enemy():
	if detection_area == null: return
	var bodies = detection_area.get_overlapping_bodies()
	var closest_enemy = null
	var closest_dist = 9999.0
	for body in bodies:
		if body.is_in_group("enemies") and body != self:
			if body.has_method("take_damage"):
				var dist = global_position.distance_squared_to(body.global_position)
				if dist < closest_dist:
					closest_dist = dist
					closest_enemy = body
	if closest_enemy:
		target_enemy = closest_enemy

func wait_and_reset(time):
	is_waiting = true
	wait_timer = time
	stuck_timer = 0.0
