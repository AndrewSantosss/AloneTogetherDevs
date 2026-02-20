extends Node3D

# --- References ---
var player: CharacterBody3D
var dialogue_ui: CanvasLayer
var cam: Camera3D 

# --- New Reference (Minimap) ---
var minimap_cam: Camera3D 

# --- Level Objects ---
var truck_obstacle: Node3D 
var truck_trigger: Area3D
var victory_area: Area3D
var enemy_container: Node3D
var truck_key: Area3D
var gate_area: Area3D 
var truck_marker: Node3D 

# --- LABELS ---
var find_key_label: Label
var use_key_label: Label

# --- Guide Path Nodes ---
var guide_waypoints: Node3D
var guide_target: Node3D 
var truck_target: Node3D 
var gate_target: Node3D 

# --- State ---
var truck_objective_active := false
var battle_active := false
var key_spawned := false
var truck_moved := false
var gate_opened := false

func _ready():
	print("DEBUG: Scene 4 Initializing...")
	
	var package = find_child("PlayerPackage", true, false)
	if package:
		player = package.find_child("Player", true, false)
		var pivot = player.find_child("CameraPivot", true, false)
		if pivot:
			var spring = pivot.find_child("SpringArm3D", true, false)
			if spring: cam = spring.find_child("Camera3D", true, false)
			else: cam = pivot.find_child("Camera3D", true, false)
			
	dialogue_ui = find_child("DialogueUI", true, false)
	
	minimap_cam = find_child("MinimapCamera", true, false)
	
	truck_obstacle = find_child("truckniMitzi", true, false) 
	if not truck_obstacle:
		truck_obstacle = find_child("truckniMitz", true, false)
	
	if truck_obstacle:
		truck_trigger = truck_obstacle.find_child("TruckTrigger", true, false)
		
	truck_marker = find_child("objectiveMarkerTruc", true, false)

	# --- FIND AND HIDE LABELS ---
	find_key_label = get_node_or_null("FindKey")
	use_key_label = get_node_or_null("UseKey")
	
	if find_key_label: find_key_label.visible = false
	if use_key_label: use_key_label.visible = false
	
	victory_area = find_child("VictoryArea", true, false)
	enemy_container = find_child("EnemyContainer", true, false)
	truck_key = find_child("TruckKey", true, false)
	gate_area = find_child("SceneTransferScene5", true, false)
	
	guide_waypoints = find_child("GuideWaypoints", true, false)
	guide_target = find_child("GuideTarget", true, false)
	truck_target = find_child("TruckTarget", true, false)
	gate_target = find_child("GateTarget", true, false) 
	
	if truck_key:
		truck_key.visible = false
		truck_key.process_mode = Node.PROCESS_MODE_DISABLED
	
	if truck_trigger:
		if not truck_trigger.body_entered.is_connected(_on_truck_trigger_entered):
			truck_trigger.body_entered.connect(_on_truck_trigger_entered)
			
	if victory_area:
		if not victory_area.body_entered.is_connected(_on_victory_area_entered):
			victory_area.body_entered.connect(_on_victory_area_entered)
			
	if truck_key:
		if not truck_key.body_entered.is_connected(_on_key_pickup):
			truck_key.body_entered.connect(_on_key_pickup)

	await get_tree().create_timer(1.0).timeout
	start_level_intro()

func _process(_delta):
	if player and minimap_cam:
		minimap_cam.global_position.x = player.global_position.x
		minimap_cam.global_position.z = player.global_position.z

	if battle_active and not key_spawned:
		if enemy_container and enemy_container.get_child_count() == 0:
			spawn_truck_key()

func start_level_intro():
	if Global.has_seen("scene4_intro"):
		return
	Global.mark_as_seen("scene4_intro")
	var p_name = GameManager.player_name
	var d_name = GameManager.dog_name
	
	if dialogue_ui:
		dialogue_ui.show_text("Objective: Escape the Facility", 4.0, false)
		await run_dialogue_step(p_name + ": We made it inside... now to find a way out.", 4.0, true)
		await get_tree().create_timer(0.5).timeout
		await run_dialogue_step(p_name + ": Stay sharp, " + d_name + ". We're almost home.", 3.0, true)

func _on_truck_trigger_entered(body):
	if body == player and not truck_moved:
		var p_name = GameManager.player_name
		
		if Inventory and Inventory.has_method("has_item") and Inventory.has_item("truck_key"):
			truck_moved = true
			
			if Inventory.has_method("remove_item"):
				Inventory.remove_item("truck_key", 1)
			
			if truck_marker:
				truck_marker.visible = false
			
			await run_dialogue_step(p_name + ": Key fits perfectly.", 2.5, true)
			dialogue_ui.show_text("System: Truck Started. Path Clearing...", 3.0, false)
			
			var old_path = get_node_or_null("GuidePathContainer")
			if old_path: old_path.queue_free()
			
			move_truck_animation()
			
		elif not truck_objective_active:
			truck_objective_active = true
			await run_dialogue_step(p_name + ": Damn, this truck is blocking the only way out.", 3.0, true)
			await run_dialogue_step(p_name + ": Wait... I recognize that logo. 'Victory Liner'.", 3.5, true)
			await run_dialogue_step(p_name + ": The terminal is nearby. If the driver ran, the keys might be there.", 4.0, true)
			dialogue_ui.show_text("Objective: Search Victory Liner Terminal", 5.0, false)
			
			# --- SHOW "FindKey" LABEL ---
			if find_key_label:
				find_key_label.visible = true
			
			spawn_guide_path(guide_target) 

func _on_victory_area_entered(body):
	if body == player and truck_objective_active and not battle_active and not key_spawned:
		battle_active = true
		var old_path = get_node_or_null("GuidePathContainer")
		if old_path: old_path.queue_free()
		
		var p_name = GameManager.player_name
		await run_dialogue_step(p_name + ": It's an ambush! They're everywhere!", 3.0, true)
		await run_dialogue_step(p_name + ": I have to take them out before I can search!", 3.5, true)
		dialogue_ui.show_text("Objective: Eliminate all Enemies", 4.0, false)

func spawn_truck_key():
	key_spawned = true
	battle_active = false
	if truck_key:
		truck_key.visible = true
		truck_key.process_mode = Node.PROCESS_MODE_INHERIT
	
	var p_name = GameManager.player_name
	dialogue_ui.show_text("System: Area Secure. Key Detected.", 4.0, false)
	await run_dialogue_step(p_name + ": Clear... Finally.", 2.0, true)
	await run_dialogue_step(p_name + ": Look, something shiny on the floor. That must be the key.", 3.5, true)

func _on_key_pickup(body):
	if body == player:
		if Inventory:
			Inventory.add_item("truck_key", 1)
		if truck_key:
			truck_key.queue_free()
			
		dialogue_ui.show_text("System: Acquired Truck Key", 3.0, false)
		
		# --- HIDE "FindKey", SHOW "UseKey" ---
		if find_key_label: find_key_label.visible = false
		if use_key_label: use_key_label.visible = true
			
		if truck_marker:
			truck_marker.visible = true
			
		var p_name = GameManager.player_name
		await run_dialogue_step(p_name + ": Got it. Now to move that truck and get out of here.", 3.5, true)
		spawn_guide_path(truck_target)

func move_truck_animation():
	if not truck_obstacle: return
	
	# --- HIDE ALL LABELS ---
	if find_key_label: find_key_label.visible = false
	if use_key_label: use_key_label.visible = false
		
	apply_camera_shake(1.0, 0.1)
	await get_tree().create_timer(1.0).timeout
	var tween = create_tween()
	var target_pos = truck_obstacle.global_position + (truck_obstacle.global_transform.basis.z * 25.0)
	tween.tween_property(truck_obstacle, "global_position", target_pos, 5.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	dialogue_ui.show_text("Objective: Proceed to Extraction Point", 4.0, false)
	spawn_guide_path(gate_target)

# ... (Helper functions below remain unchanged: spawn_guide_path, spawn_arrows_between, run_dialogue_step, apply_camera_shake)
func spawn_guide_path(target_node):
	if not player or not target_node: return
	var old_path = get_node_or_null("GuidePathContainer")
	if old_path: old_path.queue_free()
	var container = Node3D.new()
	container.name = "GuidePathContainer"
	add_child(container)
	var points_list = []
	points_list.append(player.global_position)
	if guide_waypoints and target_node != gate_target and target_node != gate_area:
		var wps = guide_waypoints.get_children()
		if target_node == truck_target: wps.reverse()
		for child in wps: points_list.append(child.global_position)
	elif target_node == gate_target:
		for child in target_node.get_children(): points_list.append(child.global_position)
		if target_node.get_child_count() == 0: points_list.append(target_node.global_position)
	else:
		points_list.append(target_node.global_position)
	var global_arrow_index = 0
	for i in range(points_list.size() - 1):
		var p_start = points_list[i]
		var p_end = points_list[i+1]
		global_arrow_index = spawn_arrows_between(container, p_start, p_end, global_arrow_index)

func spawn_arrows_between(container, start_pos, end_pos, start_index) -> int:
	var distance = start_pos.distance_to(end_pos)
	var step_size = 6.0 
	var count = floor(distance / step_size)
	var height_offset = 3.0 
	for i in range(count):
		var t = float(i) / float(count)
		var pos = start_pos.lerp(end_pos, t)
		pos.y = start_pos.y + height_offset 
		var arrow = MeshInstance3D.new()
		var prism = PrismMesh.new()
		prism.size = Vector3(3.0, 3.0, 0.5) 
		arrow.mesh = prism
		container.add_child(arrow)
		arrow.global_position = pos
		arrow.look_at(end_pos + Vector3(0, height_offset, 0), Vector3.UP)
		arrow.rotate_object_local(Vector3.RIGHT, -PI/2)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0, 0, 0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(1, 0, 0)
		mat.emission_energy_multiplier = 10.0
		arrow.material_override = mat
		var tween = create_tween().set_loops()
		tween.tween_interval((start_index + i) * 0.1) 
		tween.tween_property(mat, "albedo_color:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	return start_index + count

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
