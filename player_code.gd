extends CharacterBody3D

# --- SIGNALS ---
signal player_health_low
signal dog_health_low

# --- Player Stats ---
@export var speed = 10.0 
@export var sprint_speed = 20.0
@export var jump_velocity = 120.0 
@export var health = 150.0

# --- VISUAL SETTINGS ---
@export var flip_default = false 

# --- MOVEMENT SMOOTHING ---
@export var acceleration = 400.0 
@export var friction = 300.0 

# --- Combat Stats ---
@export var attack_damage = 500.0
@export var min_attack_damage = 10.0 
@export var attack_range = 300.0
@export var attack_hit_frame := 1

# --- Ammo ---
@export var max_ammo := 5
@export var reload_time := 1.5 
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

# --- CINEMATIC SHAKE VARIABLES ---
var shake_strength: float = 0.0
var shake_decay: float = 10.0 

# --- DIALOGUE FLAGS ---
var has_warned_player_low = false
var has_warned_dog_low = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	floor_snap_length = 0.2 
	wall_min_slide_angle = deg_to_rad(15.0)

	if animated_sprite:
		animated_sprite.process_mode = Node.PROCESS_MODE_ALWAYS
		if not animated_sprite.frame_changed.is_connected(_on_frame_changed):
			animated_sprite.frame_changed.connect(_on_frame_changed)
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
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
	if is_reloading or is_executing or is_picking_up: return
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
	current_ammo = max_ammo
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
	check_dog_health()

	if shake_strength > 0:
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		if cinematic_camera:
			cinematic_camera.h_offset = randf_range(-shake_strength, shake_strength) * 0.5
			cinematic_camera.v_offset = randf_range(-shake_strength, shake_strength) * 0.5
	else:
		if cinematic_camera:
			cinematic_camera.h_offset = 0
			cinematic_camera.v_offset = 0

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

	var y_velocity = velocity.y
	if not is_on_floor():
		y_velocity -= gravity * delta
		y_velocity = max(y_velocity, terminal_velocity)
	else:
		y_velocity = -0.5 
		
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_attacking and not is_picking_up:
		y_velocity = jump_velocity

	if Input.is_action_just_pressed("attack") and not is_attacking and not is_reloading and not is_picking_up:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
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
				start_reload()

	if is_attacking:
		if animated_sprite and animated_sprite.frame == attack_hit_frame and not damage_dealt:
			if camera_pivot and camera_pivot.has_method("apply_shake"):
				camera_pivot.apply_shake(3.0) 
			deal_damage()
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
	
	velocity.y = y_velocity
	move_and_slide()

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
	if camera: camera.make_current()
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
	# Key 1: Medkit
	if event.is_action_pressed("use_medkit"):
		if health >= 100:
			show_warning("Health is already full!")
		elif Inventory.consume_item("medkit"):
			heal_player(25)
			play_pickup_animation("Used Medkit")

	# Key 2: Candy (UPDATED)
	if event.is_action_pressed("use_candy"):
		# We don't check for 'stamina full' anymore because speed boosts are always useful!
		if Inventory.consume_item("candy"):
			activate_speed_boost() # <--- CALL THE NEW FUNCTION
		else:
			show_warning("No Candy left!")

func _on_animation_finished():
	if is_executing or not animated_sprite: return 
	
	if animated_sprite.animation == "attack":
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
		if is_reloading: ammo_label.text = "Reloading..."
		else: ammo_label.text = "Ammo: " + str(current_ammo) + " / " + str(max_ammo)

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
	if not camera: return 
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_visible_rect().size / 2
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * attack_range
	var query1 = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query1.exclude = [self]
	var aim_result = space_state.intersect_ray(query1)
	var target_position = ray_end 
	if aim_result: target_position = aim_result.position
	var attack_start_point = attack_ray_origin.global_position if attack_ray_origin else global_position
	var attack_direction = (target_position - attack_start_point).normalized()
	var attack_end_point = attack_start_point + (attack_direction * attack_range)
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
				var ratio = clamp(distance_to_enemy / attack_range, 0.0, 1.0)
				var final_damage = lerp(attack_damage, min_attack_damage, ratio)
				collider.take_damage(final_damage)
				
				# --- NEW: Play Sound ONLY when Player attacks ---
				if hit_sound:
					hit_sound.pitch_scale = randf_range(0.9, 1.1)
					hit_sound.play()
				# -----------------------------------------------

func show_warning(text: String):
	if popup_label:
		popup_label.text = text
		popup_label.visible = true
		popup_label.modulate.a = 1.0 # Reset transparency
		
		# Create a detailed animation (Tween)
		var tween = create_tween()
		# Wait for 1 second, then fade out over 1 second
		tween.tween_interval(1.0) 
		tween.tween_property(popup_label, "modulate:a", 0.0, 1.0)
		# Hide it after fading
		tween.tween_callback(popup_label.hide)

func die():
	print("Player has died!")
	get_tree().reload_current_scene()

func take_damage(amount):
	health -= amount
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
	var max_hp = 100.0 # Or use your specific max health variable if you have one
	health += amount
	if health > max_hp:
		health = max_hp
	
	update_ui() # Important: Refreshes the health bar immediately!
	print("Healed! Health is now: ", health)

func restore_stamina(amount: float):
	current_stamina += amount
	if current_stamina > max_stamina:
		current_stamina = max_stamina
		
	update_ui() # Important: Refreshes the stamina bar immediately!
	print("Stamina restored! Stamina is now: ", current_stamina)

func activate_speed_boost():
	# 1. If a boost timer is already running, kill it so we can restart
	if speed_boost_tween:
		speed_boost_tween.kill()
	
	# 2. Apply 50% boost (1.5x)
	speed = default_speed * 1.5
	sprint_speed = default_sprint_speed * 1.5
	print("SPEED BOOST! Speed is now: ", speed)
	spawn_floating_text("Speed Up!") # Optional: Reuses your text popup logic
	
	# 3. Create a timer for 5 seconds
	speed_boost_tween = create_tween()
	speed_boost_tween.tween_interval(5.0) # Wait 5 seconds
	speed_boost_tween.tween_callback(reset_speed) # Then run reset_speed

func reset_speed():
	speed = default_speed
	sprint_speed = default_sprint_speed
	print("Speed boost ended. Back to normal.")
