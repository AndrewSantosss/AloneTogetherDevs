extends CharacterBody3D

# --- SHADER PARA SA SOLID WHITE FLASH ---
const FLASH_SHADER = """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D texture_albedo : source_color, filter_nearest;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Inaayos ang UV para sa Sprite3D (Vertical flip issue fix)
	vec2 fixed_uv = vec2(UV.x, 1.0 - UV.y);
	vec4 tex = texture(texture_albedo, fixed_uv);
	
	if (tex.a < 0.1) {
		discard;
	}
	
	// Normal color na hinahaluan ng puti
	ALBEDO = mix(tex.rgb, vec3(1.0, 1.0, 1.0), flash_amount);
	
	// EMISSION: Ito ang magpapakinang sa puti kahit nasa madilim na lugar!
	EMISSION = vec3(1.0, 1.0, 1.0) * flash_amount;
	
	ALPHA = tex.a;
}
"""
var flash_material: ShaderMaterial

# --- Settings ---
@export var walk_speed := 40.0
@export var run_speed := 45.0
@export var detection_range := 500.0
@export var roam_range := 50.0

# --- Combat Settings ---
@export var attack_range := 25.0
@export var attack_damage := 10.0
@export var attack_cooldown := 2.0
@export var health := 70.0

# --- Audio Settings (FAKE 3D) ---
@export var hearing_distance: float = 600
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
@onready var health_bar = get_node_or_null("HealthBarDisplay/SubViewport/ProgressBar")
@onready var scream_sound = $ScreamSound

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
		
	# --- SETUP FLASH MATERIAL ---
	if animated_sprite:
		var shader = Shader.new()
		shader.code = FLASH_SHADER
		flash_material = ShaderMaterial.new()
		flash_material.shader = shader
		animated_sprite.material_override = flash_material

func update_health_bar():
	if health_bar:
		health_bar.value = health
		if health <= 0:
			health_bar.visible = false

func take_damage(amount):
	health -= amount
	update_health_bar()
	flash_hit()
	spawn_damage_number(amount)
	
	if health <= 0:
		die()

func flash_hit():
	if flash_material:
		var tween = create_tween()
		tween.tween_method(set_flash_amount, 1.0, 0.0, 0.2)

func set_flash_amount(value: float):
	if flash_material:
		flash_material.set_shader_parameter("flash_amount", value)

func die():
	set_physics_process(false)
	if has_node("CollisionShape3D"):
		$CollisionShape3D.set_deferred("disabled", true)
	if has_node("DetectionArea/CollisionShape3D"):
		get_node("DetectionArea/CollisionShape3D").set_deferred("disabled", true)
		
	if health_bar:
		health_bar.visible = false
		
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate:a", 0.0, 1.0)
		tween.tween_callback(queue_free)
	else:
		queue_free()

func _physics_process(delta):
	if animated_sprite and flash_material:
		var current_tex = animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
		flash_material.set_shader_parameter("texture_albedo", current_tex)

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	
	# --- FIX: SIGURADUHIN NA ANG CHARACTER NODE ANG KINUKUHA ---
	if dog == null or not is_instance_valid(dog):
		var dogs = get_tree().get_nodes_in_group("dog")
		for d in dogs:
			if d.has_method("take_damage") and d != player: # Hanapin ang node na pwedeng atakihin
				dog = d
				break
	
	if not is_on_floor():
		velocity.y -= gravity * delta

	if health <= 0:
		return

	if attack_timer > 0:
		attack_timer -= delta

	current_target = find_nearest_target()
	
	if scream_sound and scream_sound.playing and player:
		var dist_to_player = global_position.distance_to(player.global_position)
		if dist_to_player < hearing_distance:
			var vol = clamp(1.0 - (dist_to_player / hearing_distance), 0.0, 1.0)
			scream_sound.volume_db = linear_to_db(vol) + max_scream_volume_db
		else:
			scream_sound.volume_db = -80.0

	if current_target != null:
		if not has_screamed:
			if scream_sound:
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
	
	if is_instance_valid(current_target):
		var current_dist = get_horizontal_distance_to(current_target)
		if current_dist <= attack_range + 8.0:
			current_target.take_damage(attack_damage)
	
	attack_timer = attack_cooldown
	await get_tree().create_timer(0.5).timeout
	is_attacking = false
	animated_sprite.play("idle")
	
func spawn_damage_number(amount: float):
	var dmg_label = Label3D.new()
	add_child(dmg_label)
	
	dmg_label.text = str(roundi(amount))
	dmg_label.font_size = 150
	dmg_label.outline_size = 20
	dmg_label.outline_modulate = Color(0, 0, 0, 1)
	dmg_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	
	var final_scale = Vector3.ONE
	if amount >= 50:
		dmg_label.modulate = Color(1.0, 0.8, 0.0)
		final_scale = Vector3(1.5, 1.5, 1.5)
	else:
		dmg_label.modulate = Color.WHITE
		
	var start_pos = Vector3(randf_range(-0.5, 0.5), randf_range(1.0, 2.0), randf_range(-0.5, 0.5))
	dmg_label.position = start_pos
	
	var target_pos = start_pos + Vector3(randf_range(-2.5, 2.5), randf_range(1.0, 2.5), randf_range(-2.0, 2.0))
	var tween = create_tween()
	dmg_label.scale = Vector3.ZERO
	
	tween.set_parallel(true)
	tween.tween_property(dmg_label, "scale", final_scale * 1.5, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(dmg_label, "position", target_pos, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	tween.set_parallel(false)
	tween.tween_property(dmg_label, "scale", final_scale, 0.1)
	tween.tween_interval(0.2)
	
	tween.set_parallel(true)
	tween.tween_property(dmg_label, "position:y", target_pos.y - 1.5, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(dmg_label, "modulate:a", 0.0, 0.3)
	
	tween.set_parallel(false)
	tween.tween_callback(dmg_label.queue_free)
