extends Area3D

@export_file("*.tscn") var next_scene_path: String
@export var detection_radius: float = 1500.0

# Reference to the marker used for the camera pan (Fallback)
@export var enemy_view_marker: Marker3D 

@onready var interact_label = $CanvasLayer/InteractLabel

var player_in_range = false

# Removed type hint to fix error and allow flexible node access
var current_player_node = null 

func _ready():
	# Connect signals to detect player entering/leaving the gate area
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if interact_label:
		interact_label.visible = false

func _process(_delta):
	if player_in_range:
		# Check for interaction input (E key)
		if Input.is_action_just_pressed("interact") or Input.is_key_pressed(KEY_E):
			check_enemies_and_exit()

func check_enemies_and_exit():
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	var nearby_enemies_count = 0
	
	# This variable will hold the exact enemy we want to show the player
	var enemy_to_reveal: Node3D = null 
	
	for enemy in all_enemies:
		# 1. Ignore invalid or deleted enemies
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue

		# Ignore the Dog
		if "dog" in enemy.name.to_lower():
			continue
			
		# 2. Ignore dead enemies (HP < 1.0)
		var current_hp = enemy.get("health")
		if current_hp != null and current_hp < 1.0:
			continue
			
		# 3. Distance Check
		var distance = global_position.distance_to(enemy.global_position)
		
		if distance <= detection_radius:
			nearby_enemies_count += 1
			
			# If we haven't picked an enemy to look at yet, pick this one!
			if enemy_to_reveal == null:
				enemy_to_reveal = enemy

	if nearby_enemies_count > 0:
		# --- ACCESS DENIED ---
		print("Gate Locked. Enemies remaining: ", nearby_enemies_count)
		
		if interact_label:
			interact_label.text = "Area unsafe!\nKill %d remaining enemies" % nearby_enemies_count
		
		# --- DYNAMIC CAMERA PAN ---
		if current_player_node and current_player_node.get("camera_pivot"):
			var target_pos = Vector3.ZERO
			var target_rot_y = 0.0
			
			# 1. Prioritize looking at the actual enemy
			if enemy_to_reveal != null:
				print("Panning to remaining enemy: ", enemy_to_reveal.name)
				target_pos = enemy_to_reveal.global_position
				target_rot_y = enemy_to_reveal.global_rotation.y
				
			# 2. Fallback to the static marker
			elif enemy_view_marker != null:
				print("Panning to static marker (Fallback)")
				target_pos = enemy_view_marker.global_position
				target_rot_y = enemy_view_marker.global_rotation.y
			
			# Execute the pan if we have a valid target
			if target_pos != Vector3.ZERO:
				var pivot = current_player_node.camera_pivot
				if pivot.has_method("pan_to_position"):
					pivot.pan_to_position(
						target_pos, 
						target_rot_y, 
						1.5, # Duration
						2.5  # Hold time
					)

		# --- RESET UI AFTER DELAY ---
		await get_tree().create_timer(2.5).timeout
		
		# Reset text only if player is still standing there
		if player_in_range and interact_label:
			interact_label.text = "Press [ E ] to interact"
			
	else:
		# --- ACCESS GRANTED (UPDATED FOR LOADING SCREEN) ---
		print("Area clear. Loading next scene...")
		if next_scene_path:
			# DITO YUNG PAGBABAGO:
			# Tinatawag na natin ang SceneLoader autoload imbis na direktang change_scene
			SceneLoader.load_scene(next_scene_path)
		else:
			print("ERROR: No Next Scene Path set in Inspector!")

# --- Signal Functions ---

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		current_player_node = body 
		
		if interact_label:
			interact_label.text = "Press [ E ] to interact"
			interact_label.visible = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		current_player_node = null 
		
		if interact_label:
			interact_label.visible = false
