extends CharacterBody3D

# --- SIGNALS ---
signal player_health_low
signal dog_health_low

# --- Weapon System ---
enum Weapon { SHOTGUN, MELEE } # Idinagdag ang MELEE
var current_weapon = Weapon.SHOTGUN

# --- Player Stats ---
@export var speed = 55.0 
@export var sprint_speed = 20.0
@export var jump_velocity = 120.0 
@export var health = 100.0

# --- VISUAL SETTINGS ---
@export var flip_default = false 

# --- MOVEMENT SMOOTHING ---
@export var acceleration = 400.0 
@export var friction = 300.0 

# --- Combat Stats ---
@export var attack_damage = 45.0
@export var min_attack_damage = 10.0 
@export var attack_range = 300.0
@export var attack_hit_frame := 1

# --- NEW: Melee Stats ---
@export var melee_damage = 60.0
@export var melee_range = 5.0
@export var melee_cooldown = 0.4 # Mas mabilis kaysa shotgun/reload logic

# --- Ammo ---
@export var max_ammo := 5
@export var reload_time := 2
var current_ammo: int
var is_reloading := false
var damage_dealt := false 

# --- Stamina ---
@export var max_stamina := 100.0
@export var stamina_drain_rate := 30.0
@export var stamina_regen_rate := 15.0
var current_stamina: float
var is_exhausted := false 

# --- FOOTSTEP SETTINGS ---
@export var footstep_frames: Array[int] = [0, 2]

# --- Interaction ---
@export var interact_range = 20.0 

# --- References ---
@export_group("References")
@export var camera_pivot: Node3D
@export var camera: Camera3D 
@export var dog_companion: Node3D 
@export var cinematic_camera: Camera3D 
var default_speed: float
var default_sprint_speed: float
var speed_boost_tween: Tween # This tracks the timer

# --- UI References ---
@export_group("UI")
@onready var health_bar = get_node_or_null("../Healthbar/PlayerHealthBar")
@onready var stamina_bar = get_node_or_null("../Healthbar/PlayerHealthBar/PlayerStaminaBar")
@onready var ammo_label = get_node_or_null("AmmoLabel")
@onready var interact_label = get_node_or_null("../Healthbar/InteractionLabel")
@onready var dog_health_bar = get_node_or_null("../Healthbar/DogHealthBar")
@onready var ui_container = get_node_or_null("../Healthbar") 

# --- Nodes (Using Safe Access) ---
@onready var animated_sprite = get_node_or_null("AnimatedSprite3D")
@onready var hit_label = get_node_or_null("HitLabel3D")
@onready var hit_timer = get_node_or_null("HitTimer")
@onready var attack_ray_origin = get_node_or_null("AttackRayOrigin") 
@onready var popup_label = $Healthbar/PopupLabel

# --- Audio ---
@onready var shotgun_sound = get_node_or_null("ShotgunSound") 
@onready var reload_sound = get_node_or_null("ReloadSound") 
@onready var walk_sound = get_node_or_null("WalkSound") 
@onready var pickup_sound = get_node_or_null("PickupSound") 
# --- NEW: Reference to HitSound ---
@onready var hit_sound = get_node_or_null("HitSound")

# --- Physics/State ---
var gravity: float = 500.0 
var terminal_velocity: float = -60.0 
var is_first_person = false 
var is_sprinting := false 
var is_attacking := false 
var is_executing := false 
var is_picking_up := false 
var is_dying := false

# --- CINEMATIC SHAKE VARIABLES ---
var shake_strength: float = 0.0
var shake_decay: float = 10.0 

# --- DIALOGUE FLAGS ---
var has_warned_player_low = false
var has_warned_dog_low = false

# --- SILHOUETTE / X-RAY SHADER ---
const SILHOUETTE_SHADER = """
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled;

uniform sampler2D texture_albedo : source_color, filter_nearest;
// Kulay ng Silhouette (Red, Green, Blue, Alpha). Naka-set sa Light Blue na may 50% transparency.
uniform vec4 silhouette_color : source_color = vec4(0.0, 0.6, 1.0, 0.5);

void fragment() {
	vec4 tex = texture(texture_albedo, UV);
	if (tex.a < 0.1) {
		discard;
	}
	ALBEDO = silhouette_color.rgb;
	ALPHA = silhouette_color.a;
}
"""
var silhouette_material: ShaderMaterial

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	floor_snap_length = 0.2 
	wall_min_slide_angle = deg_to_rad(15.0)
	
	if ammo_label:
		ammo_label.top_level = true

	if animated_sprite:
		animated_sprite.process_mode = Node.PROCESS_MODE_ALWAYS
		if not animated_sprite.frame_changed.is_connected(_on_frame_changed):
			animated_sprite.frame_changed.connect(_on_frame_changed)
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# --- SETUP SILHOUETTE MATERIAL ---
	if animated_sprite:
		var shader = Shader.new()
		shader.code = SILHOUETTE_SHADER
		silhouette_material = ShaderMaterial.new()
		silhouette_material.shader = shader
		# Mahalaga ito: render_priority = -1 para nasa likod lang siya ng main texture!
		silhouette_material.render_priority = -1 
		animated_sprite.material_overlay = silhouette_material
	
	# Safe connection to avoid crashes if timer is missing
	if hit_timer:
		hit_timer.timeout.connect(_on_hit_timer_timeout)

	if health == null: health = 100.0
	
	current_stamina = max_stamina
	if stamina_bar:
		stamina_bar.max_value = max_stamina
		stamina_bar.value = current_stamina
	
	current_ammo = max_ammo 
	update_ui()
	
	if cinematic_camera: cinematic_camera.current = false
	if camera: 
		camera.current = true
		default_speed = speed
	default_sprint_speed = sprint_speed

func _on_hit_timer_timeout():
	if hit_label:
		hit_label.hide()

func start_reload():
	if current_weapon == Weapon.MELEE: return # Bawal mag-reload kung melee
	if is_reloading or is_executing or is_picking_up: return
	
	# Prevent reloading if the gun is already full
	if current_ammo == max_ammo: return 
	
	# Prevent reloading if we have no reserve ammo
	if Inventory.get_item_count("ammo") <= 0:
		spawn_floating_text("No Ammo!")
		return
	
	is_attacking = false 
	is_reloading = true
	update_ui()
	
	if reload_sound: reload_sound.play()
	if animated_sprite and animated_sprite.sprite_frames.has_animation("reload"):
		animated_sprite.play("reload")
	
	await get_tree().create_timer(reload_time).timeout
	_finish_reload()

func _finish_reload():
	if not is_reloading: return 
	
	# Calculate how much ammo we need to fill the gun
	var needed = max_ammo - current_ammo
	var available = Inventory.get_item_count("ammo")
	
	# Take whichever is smaller: the ammo we need, or the ammo we actually have
	var to_load = min(needed, available)
	
	if to_load > 0:
		current_ammo += to_load
		Inventory.remove_item("ammo", to_load) # Deduct from inventory
	
	is_reloading = false
	update_ui()
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	_update_animation_state(input_dir)

func play_pickup_animation(item_name: String):
	if is_picking_up: return
	
	if pickup_sound:
		pickup_sound.pitch_scale = randf_range(0.9, 1.1)
		pickup_sound.play()
	
	spawn_floating_text("+1 " + item_name)
	
	is_picking_up = true
	velocity.x = 0 # Instant stop para hindi mag-slide
	velocity.z = 0
	
	if animated_sprite and animated_sprite.sprite_frames.has_animation("pickup"):
		animated_sprite.play("pickup")
	else:
		await get_tree().create_timer(0.5).timeout
		is_picking_up = false

func spawn_floating_text(text_content: String):
	if not ui_container: return
	var label = Label.new()
	ui_container.add_child(label)
	label.text = text_content
	label.modulate = Color(1, 1, 0)
	var viewport_size = get_viewport().get_visible_rect().size
	label.position = Vector2(viewport_size.x / 2, viewport_size.y / 1.5) 
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 100, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN)
	await tween.finished
	label.queue_free()

func _on_frame_changed():
	if not animated_sprite: return
	var anim = animated_sprite.animation
	var frame = animated_sprite.frame

	if anim == "ultimate":
		if frame == 8 or frame == 13 or frame == 15 or frame == 18:
			apply_cinematic_shake(18.0) 
			if shotgun_sound:
				shotgun_sound.stop() 
				shotgun_sound.play()

	if anim in ["move_forward", "move_backward", "move_left", "move_right"]:
		if frame in footstep_frames and is_on_floor():
			if walk_sound:
				if is_sprinting:
					walk_sound.pitch_scale = randf_range(1.4, 1.6)
				else:
					walk_sound.pitch_scale = randf_range(0.8, 1.2)
				walk_sound.play()

func apply_cinematic_shake(amount: float):
	shake_strength = amount

func _physics_process(delta):
	if is_dying: return # Huwag mag-process kung patay na
	
	if get_tree().paused or is_executing: 
		velocity.x = 0
		velocity.z = 0
		if animated_sprite and animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
		return
		
	check_dog_health()

	# --- APPROACH 2: CAMERA SHAKE PARA SA LAHAT NG CAMERA ---
	if shake_strength > 0:
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		# Random offset para sa alog
		var offset_h = randf_range(-shake_strength, shake_strength) * 0.1
		var offset_v = randf_range(-shake_strength, shake_strength) * 0.1
		
		if cinematic_camera and cinematic_camera.current:
			cinematic_camera.h_offset = offset_h
			cinematic_camera.v_offset = offset_v
		elif camera and camera.current:
			camera.h_offset = offset_h
			camera.v_offset = offset_v
	else:
		if cinematic_camera: cinematic_camera.h_offset = 0; cinematic_camera.v_offset = 0
		if camera: camera.h_offset = 0; camera.v_offset = 0

	# ... rest of your code (is_executing, etc.)

	if is_executing: 
		if cinematic_camera and cinematic_camera.current:
			var target_look = cinematic_camera.global_position
			target_look.y = global_position.y 
			look_at(target_look, Vector3.UP)
		return 
	
	if get_tree().paused: return

	check_interaction()

	if Input.is_action_just_pressed("execute"): 
		attempt_ultimate()
		return 

	if Input.is_action_just_pressed("heal") or Input.is_key_pressed(KEY_Q):
		try_to_heal()
		
	if Input.is_action_just_pressed("change_view"):
		is_first_person = !is_first_person 
		# --- SYNC WEAPON CAMERA ---
		if camera: camera.current = true
		if cinematic_camera: cinematic_camera.current = false

	var y_velocity = velocity.y
	if not is_on_floor():
		y_velocity -= gravity * delta
		y_velocity = max(y_velocity, terminal_velocity)
	else:
		y_velocity = -0.5 
		
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_attacking and not is_picking_up:
		y_velocity = jump_velocity

	# --- WEAPON ATTACK LOGIC (SHOTGUN & MELEE) ---
	if Input.is_action_just_pressed("attack") and not is_attacking and not is_reloading and not is_picking_up:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if current_weapon == Weapon.SHOTGUN:
				if current_ammo > 0:
					is_attacking = true
					damage_dealt = false 
					velocity.x = 0
					velocity.z = 0
					current_ammo -= 1
					update_ui()
					if shotgun_sound: shotgun_sound.play()
					if animated_sprite and animated_sprite.animation != "attack": animated_sprite.play("attack")
					if current_ammo <= 0: 
						await get_tree().create_timer(0.2).timeout
						start_reload()
				else:
					if Inventory.get_item_count("ammo") > 0:
						start_reload()
					else:
						spawn_floating_text("NO AMMO!")
			
			elif current_weapon == Weapon.MELEE:
				is_attacking = true
				damage_dealt = false
				velocity.x = 0
				velocity.z = 0
				if animated_sprite and animated_sprite.sprite_frames.has_animation("melee"):
					animated_sprite.play("melee")
				else:
					animated_sprite.play("attack") # Fallback sa normal attack kung walang melee anim

	if is_attacking:
		# Shotgun Damage
		if current_weapon == Weapon.SHOTGUN:
			if animated_sprite and animated_sprite.frame == attack_hit_frame and not damage_dealt:
				if camera_pivot and camera_pivot.has_method("apply_shake"):
					camera_pivot.apply_shake(3.0) 
				deal_damage()
				damage_dealt = true 
		# Melee Damage
		elif current_weapon == Weapon.MELEE:
			if animated_sprite and animated_sprite.frame == 1 and not damage_dealt:
				deal_melee_damage()
				damage_dealt = true

	if not is_attacking and not is_picking_up:
		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if camera_pivot:
			var direction = (camera_pivot.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			var current_speed = speed
			is_sprinting = false 
			var stamina_changed = false

			if animated_sprite:
				if input_dir.x < 0: animated_sprite.flip_h = flip_default 
				elif input_dir.x > 0: animated_sprite.flip_h = !flip_default 

			if is_exhausted:
				if current_stamina >= (max_stamina * 0.2): 
					is_exhausted = false

			if Input.is_action_pressed("sprint") and direction != Vector3.ZERO and current_stamina > 0 and not is_exhausted:
				current_speed = sprint_speed
				is_sprinting = true
				current_stamina -= stamina_drain_rate * delta
				stamina_changed = true
				if current_stamina <= 0:
					current_stamina = 0
					is_exhausted = true
					is_sprinting = false
			
			elif current_stamina < max_stamina:
				current_stamina += stamina_regen_rate * delta
				stamina_changed = true
				if current_stamina > max_stamina:
					current_stamina = max_stamina

			current_stamina = clamp(current_stamina, 0.0, max_stamina)
			
			if stamina_changed: update_ui()

			if direction:
				velocity.x = move_toward(velocity.x, direction.x * current_speed, acceleration * delta)
				velocity.z = move_toward(velocity.z, direction.z * current_speed, acceleration * delta)
			else:
				velocity.x = 0
				velocity.z = 0
				if walk_sound: walk_sound.stop()
			
			if not is_executing:
				_update_animation_state(input_dir)
	else:
		# PIGILAN ANG SLIDING HABANG PUMUPULOT O UMAATAKE
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		velocity.z = move_toward(velocity.z, 0, friction * delta)
	
	velocity.y = y_velocity
	move_and_slide()
	
	# --- UPDATE SILHOUETTE TEXTURE ---
	if animated_sprite and silhouette_material:
		# Disable silhouette kapag umaatake (shotgun or melee), nagre-reload, o pumupulot
		if is_attacking or is_reloading or is_picking_up:
			silhouette_material.set_shader_parameter("silhouette_color", Color(0, 0, 0, 0))
		else:
			silhouette_material.set_shader_parameter("silhouette_color", Color(0.0, 0.6, 1.0, 0.5))
			var anim = animated_sprite.animation
			var frame_idx = animated_sprite.frame
			var current_tex = animated_sprite.sprite_frames.get_frame_texture(anim, frame_idx)
			if current_tex:
				silhouette_material.set_shader_parameter("texture_albedo", current_tex)

func _update_animation_state(input_dir: Vector2):
	if is_executing or is_picking_up or not animated_sprite: return
	
	if is_reloading:
		if animated_sprite.animation != "reload":
			if animated_sprite.sprite_frames.has_animation("reload"):
				animated_sprite.play("reload")
		return
		
	var target_anim = "idle"
	
	if not is_on_floor():
		target_anim = "jump"
	
	elif input_dir.length() > 0: 
		if input_dir.y < 0: target_anim = "move_forward"
		elif input_dir.y > 0: target_anim = "move_backward"
		elif input_dir.x < 0: target_anim = "move_left"
		elif input_dir.x > 0: target_anim = "move_right"
		if is_sprinting: animated_sprite.speed_scale = 1.5
		else: animated_sprite.speed_scale = 1.0
	else:
		if is_first_person: target_anim = "aim"
		else: target_anim = "idle"
		animated_sprite.speed_scale = 1.0
		
	if animated_sprite.animation != target_anim:
		if animated_sprite.sprite_frames.has_animation(target_anim):
			animated_sprite.play(target_anim)

func attempt_ultimate():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_enemy = null
	var closest_dist = attack_range 
	
	for enemy in enemies:
		if not enemy.has_method("take_damage") and not enemy.has_method("die"): continue
		if is_instance_valid(enemy):
			var dist = Vector2(global_position.x, global_position.z).distance_to(Vector2(enemy.global_position.x, enemy.global_position.z))
			if dist < closest_dist:
				closest_enemy = enemy
				closest_dist = dist
	
	if closest_enemy: perform_ultimate_kill(closest_enemy)

func perform_ultimate_kill(target_enemy):
	is_executing = true
	velocity = Vector3.ZERO 
	freeze_enemies(true)
	if camera_pivot:
		camera_pivot.set_process(false)
		camera_pivot.set_process_unhandled_input(false)
	if health_bar and health_bar.get_parent(): health_bar.get_parent().visible = false
	if animated_sprite:
		animated_sprite.stop() 
		if animated_sprite.sprite_frames.has_animation("ultimate"): animated_sprite.play("ultimate")
		else: animated_sprite.play("attack")
	if cinematic_camera and camera:
		var goal_transform = cinematic_camera.global_transform
		cinematic_camera.global_transform = camera.global_transform
		cinematic_camera.make_current()
		var target_look = cinematic_camera.global_position
		target_look.y = global_position.y 
		look_at(target_look, Vector3.UP)
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(cinematic_camera, "global_transform", goal_transform, 1.5)
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(target_enemy):
		if target_enemy.has_method("die"): target_enemy.die()
		elif target_enemy.has_method("take_damage"): target_enemy.take_damage(99999)
		else: target_enemy.queue_free()
	end_ultimate_sequence()

func end_ultimate_sequence():
	if cinematic_camera and camera:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(cinematic_camera, "global_transform", camera.global_transform, 1.0)
		await tween.finished
	freeze_enemies(false)
	shake_strength = 0.0
	if camera: camera.current = true
	if health_bar and health_bar.get_parent(): health_bar.get_parent().visible = true
	if camera_pivot:
		camera_pivot.set_process(true)
		camera_pivot.set_process_unhandled_input(true)
	is_executing = false
	if animated_sprite:
		animated_sprite.play("idle")

func freeze_enemies(freeze: bool):
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.set_physics_process(not freeze)
			enemy.set_process(not freeze)
			var sprite = enemy.get_node_or_null("Sprite3D")
			if sprite and sprite is AnimatedSprite3D:
				if freeze: sprite.pause()
				else: sprite.play()
			var anim_player = enemy.get_node_or_null("AnimationPlayer")
			if anim_player and anim_player is AnimationPlayer:
				if freeze: anim_player.pause()
				else: anim_player.play()

func try_to_heal():
	if health >= 100: return
	if GameManager.has_method("use_medkit") and GameManager.use_medkit():
		health += 50.0 
		if health > 100.0: health = 100.0
		has_warned_player_low = false 
		update_ui()
		play_pickup_animation("Healing!") 
	else:
		if interact_label:
			interact_label.text = "No Medkits!"
			interact_label.visible = true
			await get_tree().create_timer(1.0).timeout
			interact_label.visible = false
			
func _unhandled_input(event):
	if is_dying: return

	# --- WEAPON SWITCHING (SCROLL WHEEL) ---
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if current_weapon == Weapon.SHOTGUN:
				current_weapon = Weapon.MELEE
				spawn_floating_text("Melee Mode")
				is_first_person = false 
				if camera: camera.current = true
			else:
				current_weapon = Weapon.SHOTGUN
				spawn_floating_text("Shotgun Mode")
				is_first_person = true 
				if camera: camera.current = true
			update_ui()

	# Manual Reload
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		start_reload()

	# Key 1: Medkit
	if event is InputEventKey and event.pressed and event.keycode == KEY_1:
		if health >= 100:
			show_warning("Health is already full!")
		elif Inventory.consume_item("medkit"):
			heal_player(25)
			play_pickup_animation("Used Medkit")

	# Key 2: Candy
	if event is InputEventKey and event.pressed and event.keycode == KEY_2:
		if Inventory.consume_item("candy"):
			activate_speed_boost()
		else:
			show_warning("No Candy left!")
			
	# --- DEV CHEAT: INSTANT KILL (X KEY) ---
	if event is InputEventKey and event.pressed and event.keycode == KEY_X:
		dev_kill_all_enemies()

func _on_animation_finished():
	if is_executing or not animated_sprite: return 
	
	if animated_sprite.animation in ["attack", "melee"]: 
		if animated_sprite.animation == "melee":
			await get_tree().create_timer(melee_cooldown).timeout
			
		is_attacking = false
		damage_dealt = false 
		_update_animation_state(Input.get_vector("move_left", "move_right", "move_forward", "move_backward"))
	
	if animated_sprite.animation == "pickup":
		is_picking_up = false
		_update_animation_state(Input.get_vector("move_left", "move_right", "move_forward", "move_backward"))

func update_ui():
	if health_bar: health_bar.value = health
	if stamina_bar: stamina_bar.value = current_stamina
	if ammo_label:
		if current_weapon == Weapon.MELEE:
			ammo_label.text = "MELEE"
		elif is_reloading: 
			ammo_label.text = "Reloading..."
		else:
			var reserve = Inventory.get_item_count("ammo")
			ammo_label.text = "" + str(current_ammo) + " / " + str(reserve)

func check_dog_health():
	if is_instance_valid(dog_companion):
		var dog_hp = dog_companion.get("health")
		if dog_hp == null: dog_hp = 100
		if dog_health_bar: dog_health_bar.value = dog_hp
		if dog_hp <= 30.0 and not has_warned_dog_low:
			dog_health_low.emit()
			has_warned_dog_low = true
		elif dog_hp > 30.0:
			has_warned_dog_low = false

func check_interaction():
	if not camera or not interact_label: return
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_visible_rect().size / 2
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * interact_range
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.hit_from_inside = true 
	var exclusions = [self]
	if is_instance_valid(dog_companion): exclusions.append(dog_companion)
	query.exclude = exclusions
	query.collide_with_areas = true 
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	if result:
		var collider = result.collider
		
		# Case 1: Save Point
		if collider.has_method("save_point"):
			interact_label.text = "Rest & Save\n[E]"
			interact_label.visible = true
			if Input.is_action_just_pressed("interact") or Input.is_key_pressed(KEY_E):
				if GameManager.has_method("save_game"):
					GameManager.save_game(self)
					health = 100.0 
					current_ammo = max_ammo 
					has_warned_player_low = false
					update_ui()
					interact_label.text = "Game Saved!"
					await get_tree().create_timer(1.5).timeout
					return
		
		# Case 2: General Interact
		elif collider.has_method("interact"):
			var prompt = "Interact"
			if "prompt_text" in collider:
				prompt = collider.prompt_text
			
			interact_label.text = prompt + "\n[E]"
			interact_label.visible = true
			
			if Input.is_action_just_pressed("interact") or Input.is_key_pressed(KEY_E):
				collider.interact(self) 
			return
			
	interact_label.visible = false

func deal_damage():
	var active_cam = camera 
	if not active_cam: return 
	
	var current_range = attack_range
	var current_dmg = attack_damage
	
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_visible_rect().size / 2
	var ray_origin = active_cam.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + active_cam.project_ray_normal(mouse_pos) * current_range
	
	var query1 = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query1.exclude = [self]
	var aim_result = space_state.intersect_ray(query1)
	var target_position = ray_end 
	if aim_result: target_position = aim_result.position
	
	var attack_start_point = attack_ray_origin.global_position if attack_ray_origin else global_position
	var attack_direction = (target_position - attack_start_point).normalized()
	var attack_end_point = attack_start_point + (attack_direction * current_range)
	
	var query2 = PhysicsRayQueryParameters3D.create(attack_start_point, attack_end_point)
	var exclusions = [self]
	if is_instance_valid(dog_companion): exclusions.append(dog_companion)
	query2.exclude = exclusions
	var hit_result = space_state.intersect_ray(query2)
	
	if hit_result:
		var collider = hit_result.collider
		if collider.is_in_group("enemies"):
			if collider.has_method("take_damage"):
				var distance_to_enemy = global_position.distance_to(collider.global_position)
				var ratio = clamp(distance_to_enemy / current_range, 0.0, 1.0)
				var final_damage = lerp(current_dmg, current_dmg * 0.1, ratio) 
				collider.take_damage(final_damage)
				
				if hit_sound:
					hit_sound.pitch_scale = randf_range(0.9, 1.1)
					hit_sound.play()

# --- MELEE DAMAGE LOGIC (Pinatapat sa Cursor) ---
func deal_melee_damage():
	var active_cam = camera
	if not active_cam: return
	
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_visible_rect().size / 2 # Center of screen/cursor
	
	# 1. Project ray mula sa camera kung saan nakatapat ang mouse
	var ray_origin = active_cam.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + active_cam.project_ray_normal(mouse_pos) * melee_range
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var exclusions = [self]
	if is_instance_valid(dog_companion): exclusions.append(dog_companion)
	query.exclude = exclusions
	
	var hit_result = space_state.intersect_ray(query)
	
	if hit_result:
		var collider = hit_result.collider
		if collider.is_in_group("enemies") and collider.has_method("take_damage"):
			collider.take_damage(melee_damage)
			if hit_sound:
				hit_sound.pitch_scale = randf_range(1.2, 1.4)
				hit_sound.play()

func show_warning(text: String):
	if popup_label:
		popup_label.text = text
		popup_label.visible = true
		popup_label.modulate.a = 1.0 
		var tween = create_tween()
		tween.tween_interval(1.0) 
		tween.tween_property(popup_label, "modulate:a", 0.0, 1.0)
		tween.tween_callback(popup_label.hide)

func die():
	if is_dying: return
	is_dying = true
	print("Player has died!")
	get_tree().call_deferred("reload_current_scene")

func take_damage(amount):
	if is_dying: return 
	
	health -= amount
	apply_cinematic_shake(50.0) 
	
	if animated_sprite and silhouette_material:
		var flash_tween = create_tween()
		var blue_color = Color(0.0, 0.6, 1.0, 0.5) 
		var red_flash_solid = Color(5.0, 0.0, 0.0, 1.0) 
		
		silhouette_material.set_shader_parameter("silhouette_color", red_flash_solid)
		animated_sprite.modulate.a = 0.0
		
		flash_tween.tween_method(
			func(c): silhouette_material.set_shader_parameter("silhouette_color", c),
			red_flash_solid, 
			blue_color, 
			0.4
		).set_trans(Tween.TRANS_SINE)
		
		flash_tween.parallel().tween_property(animated_sprite, "modulate:a", 1.0, 0.4)

	if health_bar:
		var bar_tween = create_tween()
		health_bar.modulate = Color(0.5, 0, 0, 1) 
		bar_tween.tween_property(health_bar, "modulate", Color.WHITE, 0.4).set_trans(Tween.TRANS_SINE)

	if hit_label:
		hit_label.show()
	if hit_timer:
		hit_timer.start()
	
	if health <= 30.0 and not has_warned_player_low:
		player_health_low.emit()
		has_warned_player_low = true
	
	update_ui()
	if health <= 0: die()
	
func heal_player(amount: float):
	var max_hp = 100.0 
	health += amount
	if health > max_hp:
		health = max_hp
	update_ui() 
	print("Healed! Health is now: ", health)

func restore_stamina(amount: float):
	current_stamina += amount
	if current_stamina > max_stamina:
		current_stamina = max_stamina
	update_ui()
	print("Stamina restored! Stamina is now: ", current_stamina)

func activate_speed_boost():
	if speed_boost_tween:
		speed_boost_tween.kill()
	speed = default_speed * 1.5
	sprint_speed = default_sprint_speed * 1.5
	print("SPEED BOOST! Speed is now: ", speed)
	spawn_floating_text("Speed Up!") 
	speed_boost_tween = create_tween()
	speed_boost_tween.tween_interval(5.0) 
	speed_boost_tween.tween_callback(reset_speed)

func reset_speed():
	speed = default_speed
	sprint_speed = default_sprint_speed
	print("Speed boost ended. Back to normal.")
	
func dev_kill_all_enemies():
	print("DEV CHEAT: Executing Order 66 (Killing all enemies in range!)")
	var enemies = get_tree().get_nodes_in_group("enemies")
	var kill_count = 0
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= attack_range: 
				if enemy.has_method("die"):
					enemy.die()
				elif enemy.has_method("take_damage"):
					enemy.take_damage(99999)
				else:
					enemy.queue_free()
				kill_count += 1
	if kill_count > 0:
		spawn_floating_text("DEV: " + str(kill_count) + " Enemies Killed!")
		if hit_sound:
			hit_sound.pitch_scale = 0.5 
			hit_sound.play()
	else:
		spawn_floating_text("DEV: No enemies in range.")
