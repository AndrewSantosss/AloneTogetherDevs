extends Node3D

@onready var anim_player = $AnimationPlayer
@onready var cam = $Camera3D
# Ito yung black screen sa loob mismo ng Scene 5
@onready var internal_black_screen = $ColorRect 

func _ready():
	print("--- SCENE 5 STARTED ---")
	
	# 1. Siguraduhin na walang ibang Loading Screen na nakalusot
	var root = get_tree().root
	for child in root.get_children():
		if "LoadingScreen" in child.name:
			child.queue_free()

	# 2. Camera Setup
	if cam:
		cam.make_current()

	# 3. Itago ang HUD ng PlayerPackage (para cinematic feel)
	if has_node("PlayerPackage"):
		$PlayerPackage.visible = false

	# 4. Play Animation
	if anim_player:
		if anim_player.has_animation("pan_cure"):
			print("Playing Cinematic...")
			anim_player.play("pan_cure")
			play_dramatic_dialogue()
		else:
			print("ERROR: Animation missing!")
			start_gameplay()

func play_dramatic_dialogue():
	# Dialogue logic (same as before)
	var dialogue_ui = null
	if has_node("PlayerPackage"):
		dialogue_ui = $PlayerPackage.find_child("DialogueUI", true, false)
	
	if dialogue_ui:
		dialogue_ui.visible = true 
		await get_tree().create_timer(1.0).timeout
		dialogue_ui.show_text("Player: Look... do you see it?", 3.0, true)
		await get_tree().create_timer(3.5).timeout
		dialogue_ui.show_text("Player: It wasn't a lie... It's actually real.", 3.5, true)
		await get_tree().create_timer(4.0).timeout
		dialogue_ui.show_text("Player: We made it, buddy. No more running.", 3.0, true)

func start_gameplay():
	print("Cinematic done. Moving to Scene 6.")
	get_tree().change_scene_to_file("res://Scene6ROOFTOP.tscn")
