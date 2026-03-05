extends Control

# --- TARGET MARKERS ---

@onready var marker_dog = $SubViewportContainer/SubViewport/MarkerDog # Siguraduhin na tama ang path

var current_target_marker : Node3D = null # Dito natin ilalagay kung sino ang tinitingnan
# --- ZOOM SETTINGS ---
@export var normal_fov : float = 75.0
@export var zoom_fov : float = 25.0 
@export var zoom_speed : float = 0.5

# --- CAM PARALLAX SETTINGS ---
@export var cam_tilt_amount : float = 0.2
@export var cam_smooth_speed : float = 5.0

@onready var camera_3d = $SubViewportContainer/SubViewport/Camera3D 
# Kunin ang MarkerPlayer node (Siguraduhin na tama ang path sa SubViewport mo)
@onready var marker_player = $SubViewportContainer/SubViewport/MarkerPlayer

var original_cam_pos : Vector3
var original_cam_rot : Vector3
var is_zoomed : bool = false

# --- EXISTING REFERENCES ---
@onready var player_input = $VBoxContainer2/PlayerNameInput
@onready var dog_input = $VBoxContainer/DogNameInput
@onready var character_sprite = $SubViewportContainer/SubViewport/AnimatedSprite3D
@onready var dog_sprite = $SubViewportContainer/SubViewport/Sprite3D

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if dog_input:
		dog_input.text_submitted.connect(func(_new_text): dog_input.release_focus())
		dog_input.focus_entered.connect(_on_dog_name_focus_entered)
		dog_input.focus_exited.connect(_on_dog_name_focus_exited)
		
	if camera_3d:
		original_cam_pos = camera_3d.position
		original_cam_rot = camera_3d.rotation
		camera_3d.fov = normal_fov
	
	if player_input:
		player_input.text_submitted.connect(func(_new_text): player_input.release_focus())
		player_input.focus_entered.connect(_on_player_name_focus_entered)
		player_input.focus_exited.connect(_on_player_name_focus_exited)

	if character_sprite: character_sprite.play("idle")
	if dog_sprite: dog_sprite.play("idle dog sitting (front)")

func _process(delta: float) -> void:
	if camera_3d:
		var screen_size = get_viewport().get_visible_rect().size
		var mouse_pos = get_viewport().get_mouse_position()
		
		# I-normalize ang mouse (-0.5 to 0.5)
		var offset_x = (mouse_pos.x / screen_size.x) - 0.5
		var offset_y = (mouse_pos.y / screen_size.y) - 0.5
		
		# --- POSITION PARALLAX ---
		var right_dir = camera_3d.transform.basis.x
		var up_dir = camera_3d.transform.basis.y
		
		var target_pos = original_cam_pos + (right_dir * offset_x * cam_tilt_amount) + (up_dir * -offset_y * cam_tilt_amount)
		camera_3d.position = camera_3d.position.lerp(target_pos, cam_smooth_speed * delta)
		
		# --- ROTATION LOGIC (FIXED) ---
		if is_zoomed and current_target_marker:
	# Titingin kung sino ang naka-focus (Player or Dog)
			var target_transform = camera_3d.global_transform.looking_at(current_target_marker.global_position, Vector3.UP)
			var target_quaternion = Quaternion(target_transform.basis)
			camera_3d.quaternion = camera_3d.quaternion.slerp(target_quaternion, cam_smooth_speed * delta)
		else:
			var target_rot_y = original_cam_rot.y + (-offset_x * 0.05)
			var target_rot_x = original_cam_rot.x + (-offset_y * 0.05)
			camera_3d.rotation.y = lerp_angle(camera_3d.rotation.y, target_rot_y, cam_smooth_speed * delta)
			camera_3d.rotation.x = lerp_angle(camera_3d.rotation.x, target_rot_x, cam_smooth_speed * delta)

# --- ZOOM FUNCTIONS (RE-ALIGNED) ---
func _on_player_name_focus_entered():
	print("Zooming in to MarkerPlayer...")
	is_zoomed = true
	var tween = create_tween()
	tween.tween_property(camera_3d, "fov", zoom_fov, zoom_speed).set_trans(Tween.TRANS_SINE)

func _on_player_name_focus_exited():
	print("Zooming out...")
	is_zoomed = false
	var tween = create_tween()
	tween.tween_property(camera_3d, "fov", normal_fov, zoom_speed).set_trans(Tween.TRANS_SINE)


# --- BUTTON REFERENCES ---
@onready var start_button = $Button
@onready var credits_button = $Button2
@onready var exit_button = $Button3

# --- CONTINUE BUTTON ---
# Make sure you have created this button in the scene and named it "ContinueButton"
@onready var continue_button = $ContinueButton 

# --- SHAKE FUNCTION ---
func shake_ui(node: Control):
	var original_pos = node.position
	var tween = create_tween()
	# Gagawa ng mabilis na pabalik-balik na galaw
	for i in range(4):
		tween.tween_property(node, "position:x", original_pos.x + 10, 0.05)
		tween.tween_property(node, "position:x", original_pos.x - 10, 0.05)
	tween.tween_property(node, "position:x", original_pos.x, 0.05)

func _on_start_pressed():
	# --- VALIDATION WITH SHAKE ---
	var has_error = false
	if player_input.text.strip_edges() == "":
		shake_ui(player_input.get_parent() if player_input.get_parent() is VBoxContainer else player_input)
		has_error = true
	if dog_input.text.strip_edges() == "":
		shake_ui(dog_input.get_parent() if dog_input.get_parent() is VBoxContainer else dog_input)
		has_error = true
		
	if has_error:
		return # Huwag ituloy ang laro kung walang pangalan

	# 1. RESET DATA FIRST! 
	# (Do this before setting names, otherwise this function deletes your input)
	GameManager.start_new_game()
	
	# 2. NOW Save the Names into GameManager
	if player_input.text.strip_edges() != "":
		GameManager.player_name = player_input.text
	else:
		GameManager.player_name = "Hero"

	if dog_input.text.strip_edges() != "":
		GameManager.dog_name = dog_input.text
	else:
		GameManager.dog_name = "Dog"
	
	print("DEBUG: Names set to: ", GameManager.player_name, " and ", GameManager.dog_name)
	
	# 3. Load the Scene
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if ResourceLoader.exists("res://intro_story.tscn"):
		if get_node_or_null("/root/SceneLoader"):
			SceneLoader.call_deferred("load_scene", "res://intro_story.tscn")
		else:
			get_tree().call_deferred("change_scene_to_file", "res://intro_story.tscn")
	else:
		if get_node_or_null("/root/SceneLoader"):
			SceneLoader.call_deferred("load_scene", "res://Scene1.tscn")
		else:
			get_tree().call_deferred("change_scene_to_file", "res://Scene1.tscn")

func _on_continue_pressed():
	print("[NameSelection] Continue Pressed.")
	
	# 1. SKIP re-loading from disk here to prevent crashes on corrupt files.
	# We rely on the GameManager state loaded at startup.
	# GameManager.load_game() 
	
	# 2. VALIDATION CHECK
	# Check if save file exists AND path is valid
	if GameManager.has_save_file() and GameManager.current_scene_path != "":
		var path = GameManager.current_scene_path
		
		if ResourceLoader.exists(path):
			print("[NameSelection] Save found. Loading scene:", path)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
			# Use call_deferred to prevent Vulkan resizing errors
			if SceneLoader:
				SceneLoader.call_deferred("load_scene", path)
			else:
				get_tree().call_deferred("change_scene_to_file", path)
			return # SUCCESS - Exit function
			
	# 3. FAILURE HANDLING (Do nothing but show feedback)
	# If we reached here, either no save exists or the path is invalid.
	print("[NameSelection] No valid save to continue.")
	_show_no_save_feedback()

func _show_no_save_feedback():
	# Does not crash, does not exit. Just updates UI text.
	if continue_button:
		continue_button.text = "NO SAVED"
		
		# Wait 1.5 seconds then reset text
		await get_tree().create_timer(1.5).timeout
		
		# Check if button still exists (in case user exited scene)
		if continue_button:
			continue_button.text = "CONTINUE"

func _on_credits_pressed():
	if ResourceLoader.exists("res://Credits.tscn"):
		# Also deferred to be safe
		get_tree().call_deferred("change_scene_to_file", "res://Credits.tscn")
	else:
		print("ERROR: Wala pang Credits.tscn!")

func _on_exit_pressed():
	get_tree().quit()

# Fallback
func _on_button_pressed():
	_on_start_pressed()
	
# --- PLAYER ZOOM ---

# --- DOG ZOOM ---
func _on_dog_name_focus_entered():
	print("Zooming in to Dog...")
	current_target_marker = marker_dog # Ituro sa MarkerDog
	is_zoomed = true
	var tween = create_tween()
	tween.tween_property(camera_3d, "fov", zoom_fov, zoom_speed).set_trans(Tween.TRANS_SINE)

func _on_dog_name_focus_exited():
	print("Zooming out from Dog...")
	is_zoomed = false
	current_target_marker = null
	var tween = create_tween()
	tween.tween_property(camera_3d, "fov", normal_fov, zoom_speed).set_trans(Tween.TRANS_SINE)
