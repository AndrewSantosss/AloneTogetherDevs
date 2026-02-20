extends Area3D

signal sequence_triggered 

@export var duration: float = 10.0
@export var return_duration: float = 2.0

# Auto-filled markers
@export var start_point: Node3D
@export var end_point: Node3D
@export var focus_point: Node3D

var has_triggered = false
var player: CharacterBody3D
var temp_cam: Camera3D # The temporary "Cinematic" camera

func _ready():
	# Auto-Find Markers
	if not start_point: start_point = find_child("CamStart", true, false)
	if not end_point: end_point = find_child("CamEnd", true, false)
	if not focus_point: focus_point = find_child("CamFocus", true, false)
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		
	print("Cinematic Trigger Ready. Markers: ", start_point != null, end_point != null, focus_point != null)

func _on_body_entered(body):
	if has_triggered: return
	
	if body.is_in_group("player") or body.name == "Player":
		print("DEBUG: Player entered. Starting Cinematic...")
		player = body
		
		if start_point and end_point and focus_point:
			has_triggered = true
			sequence_triggered.emit()
			start_virtual_cam_cinematic()
		else:
			print("CRITICAL ERROR: Missing Markers! Check scene tree.")

func start_virtual_cam_cinematic():
	# 1. Lock Player Controls
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
	if "velocity" in player:
		player.velocity = Vector3.ZERO
	
	# 2. SPAWN VIRTUAL CAMERA (The Fix)
	# We create a brand new camera just for this scene
	temp_cam = Camera3D.new()
	add_child(temp_cam) # Add it to the scene
	
	# Set it to the start position
	temp_cam.global_position = start_point.global_position
	temp_cam.look_at(focus_point.global_position)
	
	# FORCE the game to look through this new camera
	temp_cam.make_current()
	
	# 3. Animation (Tween)
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Move the VIRTUAL camera
	tween.tween_property(temp_cam, "global_position", end_point.global_position, duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(func(val): temp_cam.look_at(focus_point.global_position), 0.0, 1.0, duration)
	
	await tween.finished
	
	# 4. Transition Back
	end_cinematic()

func end_cinematic():
	print("DEBUG: Ending Cinematic")
	
	# 1. Find the Player's Real Camera to switch back to
	var player_cam = player.find_child("Camera3D", true, false)
	
	# If we can't find "Camera3D", try finding ANY camera
	if not player_cam:
		var all_cams = player.find_children("*", "Camera3D", true, false)
		if all_cams.size() > 0: player_cam = all_cams[0]

	# 2. Switch View back to Player
	if player_cam:
		player_cam.make_current()
	else:
		print("WARNING: Could not find player camera to switch back to!")

	# 3. Cleanup
	if temp_cam:
		temp_cam.queue_free() # Delete the TV camera
	
	# 4. Unlock Player
	if player.has_method("set_physics_process"):
		player.set_physics_process(true)
	
	# Re-enable mouse look if you have a pivot
	var pivot = player.find_child("CameraPivot", true, false)
	if pivot: pivot.set_process_input(true)
