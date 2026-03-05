extends Node3D

@export var target: CharacterBody3D
@onready var spring_arm = $SpringArm3D
@onready var camera = $SpringArm3D/Camera3D

@export_group("Follow Settings")
@export var follow_speed = 6.0 
@export var mouse_sensitivity = 0.002
@export var mouse_smoothness = 12.0 

@export_group("Third Person")
@export var third_person_pitch_min = -35.0
@export var third_person_pitch_max = 20.0
@export var third_person_fov = 75.0

@export_group("First Person")
@export var fpp_eye_level: Vector3 = Vector3(0, 1.8, 0)
@export var first_person_pitch_min = -89.0
@export var first_person_pitch_max = 89.0
@export var first_person_fov = 100.0

# --- NEW: DYNAMIC FOV SETTINGS ---
@export_group("Dynamic FOV")
@export var sprint_fov_offset = 15.0 # Gaano kalayo ang i-z-zoom out kapag nag-sprint
@export var fov_smoothness = 8.0     # Gaano kabilis ang transition ng FOV

var shake_strength: float = 0.0
var shake_decay_rate: float = 5.0
var rng = RandomNumberGenerator.new()

var is_first_person = false
var tpp_initial_pos: Vector3
var tpp_initial_spring_length: float = 100
var _yaw_target: float = 0.0
var _pitch_target: float = 0.0

var is_panning: bool = false

func _ready():
	set_as_top_level(true)
	
	if spring_arm:
		tpp_initial_pos = spring_arm.position
		tpp_initial_spring_length = spring_arm.spring_length
		_pitch_target = spring_arm.rotation.x
	
	_yaw_target = rotation.y
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	update_camera_perspective() 
	
	if target:
		global_position = target.global_position
		
func _input(_event):
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		return
		
func _unhandled_input(event):
	if is_panning: return

	if event is InputEventMouseMotion:
		_yaw_target -= event.relative.x * mouse_sensitivity
		_pitch_target += event.relative.y * mouse_sensitivity
		
		var min_pitch = deg_to_rad(first_person_pitch_min if is_first_person else third_person_pitch_min)
		var max_pitch = deg_to_rad(first_person_pitch_max if is_first_person else third_person_pitch_max)
		_pitch_target = clamp(_pitch_target, min_pitch, max_pitch)

func _process(delta):
	if Input.is_action_just_pressed("switch_camera") and not is_panning:
		is_first_person = not is_first_person
		update_camera_perspective()
	
	# Shake Logic
	if shake_strength > 0:
		shake_strength = lerp(shake_strength, 0.0, shake_decay_rate * delta)
		camera.h_offset = rng.randf_range(-shake_strength, shake_strength)
		camera.v_offset = rng.randf_range(-shake_strength, shake_strength)
	else:
		camera.h_offset = 0
		camera.v_offset = 0
	
	if is_panning:
		pass
	else:
		# CINEMATIC ROTATION LERP
		rotation.y = lerp_angle(rotation.y, _yaw_target, delta * mouse_smoothness)
		spring_arm.rotation.x = lerp_angle(spring_arm.rotation.x, _pitch_target, delta * mouse_smoothness)

		if not target:
			return
			
		# CINEMATIC POSITION LERP
		global_position = global_position.lerp(target.global_position, delta * follow_speed)
		
		# Sync rotation
		target.global_rotation.y = self.global_rotation.y

		# --- DYNAMIC FOV LOGIC (SPRINT EFFECT) ---
		var base_fov = first_person_fov if is_first_person else third_person_fov
		var target_fov = base_fov
		
		# Chine-check natin ang is_sprinting variable mo mula sa player_code.gd
		if "is_sprinting" in target and target.is_sprinting:
			target_fov += sprint_fov_offset
			
		# Smoothly change the camera FOV frame-by-frame
		camera.fov = lerp(camera.fov, float(target_fov), delta * fov_smoothness)

func apply_shake(intensity: float):
	shake_strength = intensity

func update_camera_perspective():
	if not spring_arm or not camera:
		return

	var target_spring_length: float
	var target_position: Vector3 

	if is_first_person:
		target_spring_length = 0.0
		target_position = fpp_eye_level
	else:
		target_spring_length = tpp_initial_spring_length
		target_position = tpp_initial_pos
	
	var min_pitch = deg_to_rad(first_person_pitch_min if is_first_person else third_person_pitch_min)
	var max_pitch = deg_to_rad(first_person_pitch_max if is_first_person else third_person_pitch_max)
	_pitch_target = clamp(_pitch_target, min_pitch, max_pitch)

	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(spring_arm, "position", target_position, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(spring_arm, "spring_length", target_spring_length, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# NOTE: Tinanggal ko ang FOV tweening dito dahil ang _process na ang bahala mag-smooth ng FOV

	if target and target.has_method("set_perspective"):
		target.set_perspective(is_first_person)

func pan_to_position(target_pos: Vector3, target_rot_y: float, duration: float = 2.0, hold_time: float = 1.0):
	is_panning = true
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", target_pos, duration)
	tween.tween_property(self, "rotation:y", target_rot_y, duration)
	tween.set_parallel(false)
	
	tween.tween_interval(hold_time)
	tween.tween_callback(return_to_player)

func return_to_player():
	_yaw_target = rotation.y
	is_panning = false
