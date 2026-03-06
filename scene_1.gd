extends Node3D

# --- UI References ---
@onready var instruction_overlay = $CanvasLayer/InstructionOverlay 
@onready var countdown_label = $CanvasLayer/InstructionOverlay/CountdownLabel 
@onready var continue_label = $CanvasLayer/InstructionOverlay/ContinueLabel

# --- References ---
var player: CharacterBody3D
var dog: CharacterBody3D
var cam: Camera3D
var dialogue_ui: CanvasLayer
var minimap_cam: Camera3D 

var objective: Label
var objectivekill: Label

# --- Triggers ---
var pan_trigger: Area3D
var pan_trigger_2: Area3D
var story_area: Area3D 
var story_area_2: Area3D 

@export var city_marker: Node3D 

# --- Flags ---
var has_triggered_story_1 = false 
var has_triggered_story_2 = false 
var can_close_instructions = false # Flag para malaman kung tapos na ang countdown

# --- NOTIFICATION UI ---
@onready var notification_label = $CanvasLayer/NotificationLabel

func _ready():
	print("DEBUG: Finding Nodes...")
	
	# --- SETUP NOTIFICATION LABEL ---
	setup_notification_ui()
	
	# --- SETUP INSTRUCTION SEQUENCE ---
	if instruction_overlay:
		start_countdown_sequence()
		
	objective = get_node_or_null("Objective")
	objectivekill = get_node_or_null("ObjectiveKill")
	if objective: objective.visible = false
	if objectivekill: objectivekill.visible = false
	
	var package = find_child("PlayerPackage", true, false)
	if package:
		player = package.find_child("Player", true, false)
		var dog_main = package.find_child("dogMain", true, false)
		if dog_main:
			dog = dog_main.find_child("dog", true, false)
			
		var pivot = player.find_child("CameraPivot", true, false)
		if pivot:
			var spring = pivot.find_child("SpringArm3D", true, false)
			if spring: cam = spring.find_child("Camera3D", true, false)
			else: cam = pivot.find_child("Camera3D", true, false)
			
	dialogue_ui = find_child("DialogueUI", true, false)
	pan_trigger = get_node_or_null("PanTrigger")
	pan_trigger_2 = get_node_or_null("PanTrigger2")
	story_area = find_child("StoryArea", true, false)
	story_area_2 = find_child("StoryArea2", true, false)
	minimap_cam = find_child("MinimapCamera", true, false)
	
	if pan_trigger: pan_trigger.triggered.connect(_on_pan_trigger_activated)
	if pan_trigger_2: pan_trigger_2.triggered.connect(_on_pan_trigger_2_activated)
	
	if story_area:
		if not story_area.body_entered.is_connected(_on_story_area_entered):
			story_area.body_entered.connect(_on_story_area_entered)
			
	if story_area_2:
		if not story_area_2.body_entered.is_connected(_on_story_2_area_entered):
			story_area_2.body_entered.connect(_on_story_2_area_entered)

	if player:
		if player.has_signal("player_health_low"):
			if not player.player_health_low.is_connected(_on_player_low_health):
				player.player_health_low.connect(_on_player_low_health)
		if player.has_signal("dog_health_low"):
			if not player.dog_health_low.is_connected(_on_dog_low_health):
				player.dog_health_low.connect(_on_dog_low_health)

	await get_tree().create_timer(1.0).timeout
	start_level_intro()

# --- NOTIFICATION LOGIC ---
func setup_notification_ui():
	if notification_label:
		notification_label.text = "Objective Updated"
		notification_label.visible = true
		notification_label.modulate.a = 0.0 # Start hidden

func show_objective_update_notif():
	if notification_label:
		var tween = create_tween()
		notification_label.modulate.a = 0.0 # Force reset
		tween.tween_property(notification_label, "modulate:a", 1.0, 0.5) # Fade in
		tween.tween_interval(2.0)                                     # Stay
		tween.tween_property(notification_label, "modulate:a", 0.0, 0.5) # Fade out

# --- NEW: Sequence Logic ---
func start_countdown_sequence():
	instruction_overlay.visible = true
	instruction_overlay.modulate.a = 1.0
	if continue_label: continue_label.visible = false
	if countdown_label: countdown_label.visible = true
	
	for i in range(5, 0, -1):
		if countdown_label:
			countdown_label.text = "(" + str(i) + ")"
		await get_tree().create_timer(1.0).timeout
	
	if countdown_label: countdown_label.visible = false
	if continue_label: 
		continue_label.visible = true
		continue_label.text = "Press any key to continue"
		var pulse = create_tween().set_loops()
		pulse.tween_property(continue_label, "modulate:a", 0.3, 0.8)
		pulse.tween_property(continue_label, "modulate:a", 1.0, 0.8)
	
	can_close_instructions = true

func _input(event):
	if can_close_instructions and instruction_overlay.visible:
		if event is InputEventKey or event is InputEventMouseButton:
			if event.pressed:
				instruction_overlay.visible = false
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(_delta):
	if player and minimap_cam:
		minimap_cam.global_position.x = player.global_position.x
		minimap_cam.global_position.z = player.global_position.z

func start_level_intro():
	if Global.has_seen("scene1_intro"):
		return 
	Global.mark_as_seen("scene1_intro")
	
	var p_name = GameManager.player_name
	var d_name = GameManager.dog_name
	
	if dialogue_ui:
		dialogue_ui.show_text("Objective: Reach the City Center", 5.0, false)
		await run_dialogue_step(p_name + ": Easy, " + d_name + ". We're almost there.", 4.0, true)
		await run_dialogue_step(p_name + ": Just a few more blocks to the safe zone.", 3.0, true)

func _on_story_area_entered(body):
	if body == player and not has_triggered_story_1:
		has_triggered_story_1 = true
		var p_name = GameManager.player_name
		var d_name = GameManager.dog_name
		await run_dialogue_step(p_name + ": This place... it used to be full of life.", 4.0, true)
		await run_dialogue_step(p_name + ": I almost forgotten what peace feels like... it's been such a long road.", 5.0, true)
		await run_dialogue_step(p_name + ": Stay close, " + d_name + ".", 3.0, true)
		
		if objective:
			objective.visible = true
			show_objective_update_notif() # Call notification
		if objectivekill: objectivekill.visible = false

func _on_story_2_area_entered(body):
	if body == player and not has_triggered_story_2:
		has_triggered_story_2 = true
		var p_name = GameManager.player_name
		await run_dialogue_step(p_name + ": Shh... did you hear that?", 3.0, true)
		await run_dialogue_step(p_name + ": Something's moving up ahead. Feels dangerous.", 4.0, true)
		await run_dialogue_step("STAY ALERT", 3.0, false)

func _on_pan_trigger_activated():
	var p_name = GameManager.player_name
	await run_dialogue_step(p_name + ": You mean I have to kill all of THOSE?", 4.0, true)
	if objective: objective.visible = false
	if objectivekill:
		objectivekill.visible = true
		show_objective_update_notif() # Call notification

func _on_pan_trigger_2_activated():
	var p_name = GameManager.player_name
	await run_dialogue_step(p_name + ": The city center... it looks worse from here.", 4.0, true)
	await run_dialogue_step(p_name + ": I have to get out of here.", 3.0, true)

func _on_player_low_health():
	if dialogue_ui and not dialogue_ui.visible:
		var p_name = GameManager.player_name
		dialogue_ui.show_text(p_name + ": My vision is blurring... I need to heal.", 3.0, true)

func _on_dog_low_health():
	if dialogue_ui and not dialogue_ui.visible:
		var p_name = GameManager.player_name
		var d_name = GameManager.dog_name
		dialogue_ui.show_text(p_name + ": Hold on " + d_name + "! I've got you!", 3.0, true)

func run_dialogue_step(text, time, is_cinematic = false):
	if dialogue_ui and dialogue_ui.has_method("show_text"):
		dialogue_ui.show_text(text, time, is_cinematic)
		await dialogue_ui.finished
	else:
		await get_tree().create_timer(time).timeout

func apply_camera_shake(duration: float, intensity: float):
	if not cam: return
	var original_h = cam.h_offset
	var original_v = cam.v_offset
	var elapsed = 0.0
	while elapsed < duration:
		cam.h_offset = original_h + randf_range(-intensity, intensity)
		cam.v_offset = original_v + randf_range(-intensity, intensity)
		elapsed += get_process_delta_time()
		await get_tree().process_frame
	cam.h_offset = original_h
	cam.v_offset = original_v
