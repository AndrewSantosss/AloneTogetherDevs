extends Control

@onready var anim_player = $AnimationPlayer
# Hanapin ang button sa scene tree (siguraduhin na "BackButton" ang pangalan sa Scene dock)
@onready var back_button = get_node_or_null("BackButton") 

func _ready():
	# --- 1. FORCE REMOVE STUCK LOADING SCREEN ---
	await get_tree().process_frame
	var root = get_tree().root
	
	if root.has_node("LoadingScreen"):
		root.get_node("LoadingScreen").queue_free()
	
	for child in root.get_children():
		if "LoadingScreen" in child.name:
			child.queue_free()
	# ---------------------------------------------

	# --- 2. START ANIMATION ---
	if anim_player:
		anim_player.play("scroll")
		if not anim_player.animation_finished.is_connected(_on_animation_finished):
			anim_player.animation_finished.connect(_on_animation_finished)
	
	# --- 3. CONNECT BACK BUTTON (AUTO-CONNECT) ---
	if back_button:
		if not back_button.pressed.is_connected(_on_back_button_pressed):
			back_button.pressed.connect(_on_back_button_pressed)
	else:
		# Fallback kung sakaling iba ang pangalan o nasa ibang path
		print("Warning: 'BackButton' node not found in script.")

# Ito ang function na nawala
func _on_back_button_pressed():
	print("Back button pressed. Returning to Main Menu...")
	return_to_main_menu()

func _on_animation_finished(anim_name):
	if anim_name == "scroll":
		return_to_main_menu()

# Shared function para iwas paulit-ulit na code
func return_to_main_menu():
	get_tree().change_scene_to_file("res://NameSelectionUI.tscn")

# OPTIONAL: Pwede ring mag-exit gamit ang 'Esc' o 'Cancel'
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		return_to_main_menu()
