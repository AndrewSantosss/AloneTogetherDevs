extends Area3D

# --- VARIABLES ---
@export var dialogue_ui: CanvasLayer 
@export var player: Node3D 
@export var helicopter: Node3D
# Drag your Main Menu scene file here in the Inspector
@export_file("*.tscn") var main_menu_scene: String 

@onready var end_screen_label = $CanvasLayer/EndScreenLabel

var ending_triggered = false

func _ready():
	if end_screen_label:
		end_screen_label.visible = false
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Check if it is the player
	if not ending_triggered and (body.name == "PlayerPackage" or body.is_in_group("player")):
		
		# --- MEMORY CHECK ---
		# If we have already seen this ending (e.g. somehow re-triggered), stop.
		if Global.has_seen("scene6_ending"):
			return 
			
		start_ending_sequence(body)

func start_ending_sequence(player_body):
	ending_triggered = true
	
	# --- MARK AS SEEN ---
	Global.mark_as_seen("scene6_ending")
	
	# 1. Disable Player Control
	if player_body.has_method("set_physics_process"):
		player_body.set_physics_process(false) 
	
	# 2. First Dialogue
	if dialogue_ui:
		dialogue_ui.start_dialogue(["We are finally here, Lets get on the helicopter to go to the laboratory"])
		await dialogue_ui.dialogue_finished 
	else:
		await get_tree().create_timer(3.0).timeout 

	# 3. Move Player to Helicopter
	var tween = create_tween()
	tween.tween_property(player_body, "global_position", helicopter.global_position, 2.0)
	await tween.finished

	# 4. Second Dialogue
	if dialogue_ui:
		dialogue_ui.start_dialogue(["See you later game"])
		await dialogue_ui.dialogue_finished
	else:
		await get_tree().create_timer(2.0).timeout

	# 5. Show Big Text
	if end_screen_label:
		end_screen_label.visible = true
		var text_tween = create_tween()
		end_screen_label.modulate.a = 0.0
		text_tween.tween_property(end_screen_label, "modulate:a", 1.0, 1.0)
		
		# Wait for reading
		await text_tween.finished
		await get_tree().create_timer(4.0).timeout
	
	# 6. Change to Main Menu
	if main_menu_scene:
		get_tree().change_scene_to_file(main_menu_scene)
	else:
		print("Main Menu scene path is missing!")
