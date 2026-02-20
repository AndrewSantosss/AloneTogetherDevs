extends Control

# --- INPUT REFERENCES ---
@onready var player_input = $VBoxContainer2/PlayerNameInput
@onready var dog_input = $VBoxContainer/DogNameInput

# --- ANIMATION REFERENCES (CHARACTER & DOG) ---
@onready var character_sprite = $SubViewportContainer/SubViewport/AnimatedSprite3D
@onready var dog_sprite = $SubViewportContainer/SubViewport/Sprite3D

# --- BUTTON REFERENCES ---
@onready var start_button = $Button
@onready var credits_button = $Button2
@onready var exit_button = $Button3

# --- CONTINUE BUTTON ---
# Make sure you have created this button in the scene and named it "ContinueButton"
@onready var continue_button = $ContinueButton 

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if player_input:
		player_input.grab_focus()

	# 1. Play Idle Animations
	if character_sprite:
		character_sprite.play("idle")
	if dog_sprite:
		dog_sprite.play("idle dog sitting (front)")

	# 2. AUTOMATIC CONNECTIONS
	if start_button:
		if not start_button.pressed.is_connected(_on_start_pressed):
			start_button.pressed.connect(_on_start_pressed)
			
	if credits_button:
		if not credits_button.pressed.is_connected(_on_credits_pressed):
			credits_button.pressed.connect(_on_credits_pressed)
			
	if exit_button:
		if not exit_button.pressed.is_connected(_on_exit_pressed):
			exit_button.pressed.connect(_on_exit_pressed)
			
	# --- CONTINUE BUTTON SETUP ---
	if continue_button:
		if not continue_button.pressed.is_connected(_on_continue_pressed):
			continue_button.pressed.connect(_on_continue_pressed)
		
		# ALWAYS ENABLED so player can click it to see "NO SAVED" status
		continue_button.disabled = false
		continue_button.text = "CONTINUE"
		continue_button.modulate = Color(1, 1, 1, 1)

# --- FUNCTIONS ---

func _on_start_pressed():
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
	
	if ResourceLoader.exists("res://IntroSequence.tscn"):
		if get_node_or_null("/root/SceneLoader"):
			SceneLoader.call_deferred("load_scene", "res://IntroSequence.tscn")
		else:
			get_tree().call_deferred("change_scene_to_file", "res://IntroSequence.tscn")
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
