extends Node3D

# --- References ---
var player: CharacterBody3D
var dog: CharacterBody3D
var dialogue_ui: CanvasLayer
var cam: Camera3D 
var minimap_cam: Camera3D 
var voice_player: AudioStreamPlayer 

# --- Visuals ---
var objective_arrow: Node3D 
var arrow_mesh: MeshInstance3D
var objective_marker_1: Node3D # "objective_marker_1" (?)
var objective_marker_2: Node3D # "objective_marker_2" (!)

# --- Sub-Labels for Marker 1 ---
var lbl_investigate: Label
var lbl_get_medkit: Label
var lbl_bring_medkit: Label

var npc_node: Node3D 
var npc_trigger_area: Area3D

# --- Blocking Mechanics ---
var blocker_trigger: Area3D
var invisible_wall: Node3D 

# --- Scene Transfer & Guide ---
var gate_node: Node3D 
var guide_target: Node3D 
var guide_waypoints: Node3D 

# --- Triggers ---
var pan_trigger: Area3D
var pan_trigger_2: Area3D
var story_area: Area3D 

# --- Quest State ---
var npc_cutscene_played := false
var quest_started := false
var quest_completed := false
var is_interacting := false
var story_triggered := false

# Tracks if we picked up a specific medkit in THIS scene
var medkit_acquired_in_scene := false 

# --- Preload Voice Lines ---
const VO_INTRO_0 = preload("res://dialogues/NPC/npc_intro_0.wav")
const VO_INTRO_1 = preload("res://dialogues/NPC/npc_intro_1.wav")
const VO_INTRO_2 = preload("res://dialogues/NPC/npc_intro_2.wav")
const VO_INTRO_3 = preload("res://dialogues/NPC/npc_intro_3.wav")
const VO_INTRO_4 = preload("res://dialogues/NPC/npc_intro_4.wav")
const VO_INTRO_5 = preload("res://dialogues/NPC/npc_intro_5.wav")
const VO_INTRO_6 = preload("res://dialogues/NPC/npc_intro_6.wav")
const VO_INTRO_7 = preload("res://dialogues/NPC/npc_intro_7.wav")
const VO_INTRO_8 = preload("res://dialogues/NPC/npc_intro_8.wav")
const VO_INTRO_9 = preload("res://dialogues/NPC/npc_intro_9.wav")
const VO_INTRO_10 = preload("res://dialogues/NPC/npc_intro_10.wav")
const VO_INTRO_11 = preload("res://dialogues/NPC/npc_intro_11.wav")
const VO_INTRO_12 = preload("res://dialogues/NPC/npc_intro_12.wav")
const VO_INTRO_13 = preload("res://dialogues/NPC/npc_intro_13.wav")

func _ready():
	print("DEBUG: Scene 2-3 Initializing...")
	
	# 1. Find Player, Dog, Camera
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
			
	# 2. Find UI
	dialogue_ui = find_child("DialogueUI", true, false)

	# 3. Find Audio Player
	voice_player = find_child("VoicePlayer", true, false)
	if not voice_player:
		voice_player = AudioStreamPlayer.new()
		voice_player.name = "VoicePlayer"
		add_child(voice_player)
	
	# 4. Find Triggers & NPC
	pan_trigger = get_node_or_null("PanTrigger")
	pan_trigger_2 = get_node_or_null("PanTrigger2")
	story_area = find_child("StoryArea", true, false)
	npc_node = find_child("NPC", true, false)
	npc_trigger_area = find_child("NPCTriggerArea", true, false)
	
	# 5. Find Objective Visuals
	objective_arrow = find_child("ObjectiveArrow", true, false)
	
	if objective_arrow:
		arrow_mesh = objective_arrow.find_child("MeshInstance3D", true, false)
		if arrow_mesh: arrow_mesh.visible = false 
		# Parent must be visible for children markers to show
		objective_arrow.visible = true 
	
	# [cite_start]Using names from Scene File [cite: 232, 236]
	objective_marker_1 = find_child("objective_marker_1", true, false)
	objective_marker_2 = find_child("objective_marker_2", true, false) 
	
	# [cite_start]Find Labels inside Marker 1 [cite: 232]
	if objective_marker_1:
		lbl_investigate = objective_marker_1.find_child("Investigate", true, false)
		lbl_get_medkit = objective_marker_1.find_child("GetMedkit", true, false)
		lbl_bring_medkit = objective_marker_1.find_child("BringMedkit", true, false)
		
		# Reset Labels
		if lbl_investigate: lbl_investigate.visible = false
		if lbl_get_medkit: lbl_get_medkit.visible = false
		if lbl_bring_medkit: lbl_bring_medkit.visible = false
	
	# FORCE HIDE ALL MARKERS AT START
	if objective_marker_1: objective_marker_1.visible = false
	if objective_marker_2: objective_marker_2.visible = false
	
	# 6. Find Blockers & Minimap
	blocker_trigger = find_child("BlockerTrigger", true, false)
	invisible_wall = find_child("InvisibleWall", true, false)
	minimap_cam = find_child("MinimapCamera", true, false)
	
	# 7. Find Pathing Nodes
	gate_node = find_child("SceneTransferScene5", true, false) 
	guide_target = find_child("GuideTarget", true, false) 
	guide_waypoints = find_child("GuideWaypoints", true, false) 
	
	# Connect Medkit signals to detect pickup
	for kit_name in ["Medkit", "Medkit2", "Medkit3"]:
		var kit_node = find_child(kit_name, true, false)
		if kit_node:
			kit_node.tree_exited.connect(_on_quest_item_picked_up)
	
	# 8. Connect Signals
	if pan_trigger: 
		pan_trigger.triggered.connect(_on_pan_trigger_activated)
	if pan_trigger_2: 
		pan_trigger_2.triggered.connect(_on_pan_trigger_2_activated)
	
	if npc_trigger_area:
		if not npc_trigger_area.body_entered.is_connected(_on_npc_area_entered):
			npc_trigger_area.body_entered.connect(_on_npc_area_entered)

	if blocker_trigger:
		if not blocker_trigger.body_entered.is_connected(_on_blocker_trigger_entered):
			blocker_trigger.body_entered.connect(_on_blocker_trigger_entered)

	if story_area:
		if not story_area.body_entered.is_connected(_on_story_area_entered):
			story_area.body_entered.connect(_on_story_area_entered)

	if player:
		if player.has_signal("player_health_low"):
			if not player.player_health_low.is_connected(_on_player_low_health):
				player.player_health_low.connect(_on_player_low_health)
		if player.has_signal("dog_health_low"):
			if not player.dog_health_low.is_connected(_on_dog_low_health):
				player.dog_health_low.connect(_on_dog_low_health)

	await get_tree().create_timer(1.0).timeout
	start_level_intro()

func _process(_delta):
	if player and minimap_cam:
		minimap_cam.global_position.x = player.global_position.x
		minimap_cam.global_position.z = player.global_position.z
	
	# --- QUEST MARKER STATE MACHINE ---
	if quest_started and not quest_completed:
		if medkit_acquired_in_scene:
			# --- STATE: Got Medkit -> Show "?" + "Bring Medkit" ---
			if objective_marker_2: objective_marker_2.visible = false
			if objective_marker_1: 
				objective_marker_1.visible = true
				if lbl_get_medkit: lbl_get_medkit.visible = false
				if lbl_investigate: lbl_investigate.visible = false
				if lbl_bring_medkit: lbl_bring_medkit.visible = true
		else:
			# --- STATE: Quest Start -> Show "!" + "Get Medkit" + Hide "?" ---
			if objective_marker_2: objective_marker_2.visible = true
			if objective_marker_1: 
				objective_marker_1.visible = false # Hides (?)
				# We enable the label so it's ready, but parent visibility rules apply
				if lbl_get_medkit: lbl_get_medkit.visible = true
				if lbl_investigate: lbl_investigate.visible = false
				if lbl_bring_medkit: lbl_bring_medkit.visible = false

# Called when any Medkit node is removed from the tree
func _on_quest_item_picked_up():
	print("DEBUG: Quest Medkit collected!")
	medkit_acquired_in_scene = true

func start_level_intro():
	var p_name = "Player"
	if GameManager.get("player_name"): p_name = GameManager.player_name
	
	if dialogue_ui:
		dialogue_ui.show_text("Objective: Investigate the survivor", 5.0, false)
		
		await run_dialogue_step(p_name + ": We made it past the blockade... but it's quiet here.", 4.0, true)
		await get_tree().create_timer(0.5).timeout
		await run_dialogue_step(p_name + ": Someone's up ahead. Keep your guard up.", 4.0, true)

# ==========================================
#             NPC INTERACTION LOGIC
# ==========================================

func _on_npc_area_entered(body):
	if body != player or is_interacting: return
	
	is_interacting = true 
	
	if not npc_cutscene_played:
		await run_intro_dialogue()
		npc_cutscene_played = true
		quest_started = true # _process takes over marker logic here
		
	elif quest_started and not quest_completed:
		if medkit_acquired_in_scene:
			await run_quest_completion_dialogue()
		else:
			await run_reminder_dialogue()
			
	elif quest_completed:
		if npc_node and npc_node.has_method("play_talk"): npc_node.play_talk()
		dialogue_ui.show_text("Survivor: Be careful out there.", 3.0, false)
		await get_tree().create_timer(3.0).timeout
		if npc_node and npc_node.has_method("play_idle"): npc_node.play_idle()

	is_interacting = false 

func run_intro_dialogue():
	print("--- STARTING SURVIVOR INTRO ---")
	
	if arrow_mesh: arrow_mesh.visible = false
	
	# Hide the "?" marker during dialogue
	if objective_marker_1: objective_marker_1.visible = false
	
	lock_controls()
	
	await move_camera_to_npc()

	var p_name = "Player"
	var d_name = "Dog"
	if GameManager.get("player_name"): p_name = GameManager.player_name
	if GameManager.get("dog_name"): d_name = GameManager.dog_name
	
	if npc_node and npc_node.has_method("play_talk"): npc_node.play_talk()
	
	await run_dialogue_step("Survivor: Wait! Don't shoot! I'm... I'm human.", 2.5, true, VO_INTRO_1)
	await run_dialogue_step("Survivor: That dog... is it turned? Keep it back!", 3.5, true, VO_INTRO_2)
	await run_dialogue_step(p_name + ": " + d_name + " is safe. He's with me.", 3.0, true)
	await run_dialogue_step("Survivor: Okay... sorry. I've been stranded here since the horde broke the blockade.", 4.5, true, VO_INTRO_3)
	await run_dialogue_step("Survivor: I... I took a bad hit during the scramble. My leg's bleeding out.", 3.8, true, VO_INTRO_4)
	await run_dialogue_step("Survivor: I can't move like this. Please, there's a public market down the road.", 3.5, true, VO_INTRO_5)
	await run_dialogue_step("Survivor: If you can find me a Medkit, I can patch this up. I'll make it worth your while.", 3.5, true, VO_INTRO_6)
	
	await run_dialogue_step("System: Quest Started - Find a Medkit for the Survivor.", 3.0, false)
	
	# Markers update automatically via _process now that quest_started = true

	if npc_node and npc_node.has_method("play_idle"): npc_node.play_idle()

	if invisible_wall:
		invisible_wall.process_mode = Node.PROCESS_MODE_DISABLED
		invisible_wall.visible = false

	unlock_controls()

func run_reminder_dialogue():
	lock_controls()
	if npc_node and npc_node.has_method("play_talk"): npc_node.play_talk()
	
	await run_dialogue_step("Survivor: Please... the pain is getting worse. Did you find a Medkit yet?", 3.5, true, VO_INTRO_7)
	var p_name = "Player"
	if GameManager.get("player_name"): p_name = GameManager.player_name
	await run_dialogue_step(p_name + ": Not yet. I'm looking.", 2.5, true)
	
	if npc_node and npc_node.has_method("play_idle"): npc_node.play_idle()
	unlock_controls()

func run_quest_completion_dialogue():
	lock_controls()
	var p_name = "Player"
	var d_name = "Dog"
	if GameManager.get("player_name"): p_name = GameManager.player_name
	if GameManager.get("dog_name"): d_name = GameManager.dog_name

	if Inventory and Inventory.has_method("remove_item"):
		Inventory.remove_item("medkit", 1)

	if npc_node and npc_node.has_method("play_talk"): npc_node.play_talk()

	await run_dialogue_step(p_name + ": Here. Found this in the rubble.", 3.0, true)
	await run_dialogue_step("Survivor: Thank god... thank you.", 3.0, true, VO_INTRO_8)
	await run_dialogue_step("System: Survivor uses the Medkit.", 2.0, false)
	await run_dialogue_step("Survivor: That feels better already. You saved my life.", 3.5, true, VO_INTRO_9)
	await run_dialogue_step("Survivor: I don't have much, but I used to train K9 units before... this.", 4.0, true, VO_INTRO_10)
	await run_dialogue_step("Survivor: Let me show you a trick with " + d_name + ".", 3.0, true, VO_INTRO_11)
	await run_dialogue_step("Survivor: [Whistles] See? He knows the scent of supplies now.", 3.5, true, VO_INTRO_12)
	
	if dog:
		dog.can_scavenge = true
	
	if dialogue_ui:
		dialogue_ui.show_text("System: [Q] Ability Unlocked - Dog can now find Items", 4.0, false)
	
	await get_tree().create_timer(4.0).timeout
	await run_dialogue_step("Survivor: Good luck out there. Stay safe.", 3.0, true, VO_INTRO_13)
	
	# --- HIDE ALL MARKERS & LABELS ---
	quest_completed = true  # Stop _process loop
	
	if objective_marker_1: objective_marker_1.visible = false
	if objective_marker_2: objective_marker_2.visible = false
	
	# Explicitly hide all sub-labels
	if lbl_investigate: lbl_investigate.visible = false
	if lbl_get_medkit: lbl_get_medkit.visible = false
	if lbl_bring_medkit: lbl_bring_medkit.visible = false
	
	perform_save()
	await run_dialogue_step("System: Game Saved.", 2.0, false)
		
	if npc_node and npc_node.has_method("play_idle"): npc_node.play_idle()
	
	spawn_guide_path()
		
	unlock_controls()

# --- Perform Save Function ---
func perform_save():
	if GameManager.has_method("save_game") and player:
		GameManager.save_game(player)
		print("[Scene 2-3] Game Saved via GameManager.")
	else:
		print("[Scene 2-3] Error: GameManager save_game method not found.")

# ==========================================
#             STORY AREA TRIGGER
# ==========================================
func _on_story_area_entered(body):
	if body == player and not story_triggered:
		story_triggered = true
		
		var p_name = "Player"
		if GameManager.get("player_name"): p_name = GameManager.player_name
		
		await run_dialogue_step(p_name + ": Good job, boy. Oh look, I can see the way out.", 4.0, true)
		await get_tree().create_timer(0.5).timeout
		await run_dialogue_step(p_name + ": I hope we're close to the end.", 3.0, true)

# ==========================================
#       SPAWN MULTI-POINT GUIDE PATH
# ==========================================
func spawn_guide_path():
	if not player: return
	
	var end_pos = Vector3.ZERO
	if gate_node:
		end_pos = gate_node.global_position
	elif guide_target:
		end_pos = guide_target.global_position
	else:
		return
	
	if dialogue_ui:
		dialogue_ui.show_text("Objective: Follow the arrows to the Gate", 5.0, false)
	
	var container = Node3D.new()
	container.name = "GuidePathContainer"
	add_child(container)
	
	var points_list = []
	points_list.append(player.global_position)
	
	if guide_waypoints:
		for child in guide_waypoints.get_children():
			points_list.append(child.global_position)
	
	points_list.append(end_pos)
	
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
		mat.emission_energy_multiplier = 3.0
		arrow.material_override = mat
		
		var tween = create_tween().set_loops()
		tween.tween_interval((start_index + i) * 0.1) 
		tween.tween_property(mat, "albedo_color:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
		
	return start_index + count

# ==========================================
#             UTILITY FUNCTIONS
# ==========================================

func lock_controls():
	if player:
		player.set_physics_process(false)
		player.velocity = Vector3.ZERO
		var pivot = player.get_node_or_null("CameraPivot")
		if pivot: pivot.set_process_input(false)
	if dog:
		dog.set_physics_process(false)
		dog.velocity = Vector3.ZERO

func unlock_controls():
	if player:
		player.set_physics_process(true)
		var pivot = player.get_node_or_null("CameraPivot")
		if pivot: pivot.set_process_input(true)
	if dog:
		dog.set_physics_process(true)

func move_camera_to_npc():
	if player and npc_node:
		var target_pos = npc_node.global_position + Vector3(12, 0, 12) 
		target_pos.y = player.global_position.y 
		
		var tween = create_tween()
		tween.tween_property(player, "global_position", target_pos, 1.5).set_trans(Tween.TRANS_SINE)
		
		if dog:
			var dog_target = target_pos + Vector3(2, 0, -2)
			dog_target.y = dog.global_position.y
			tween.parallel().tween_property(dog, "global_position", dog_target, 1.5)

		if cam:
			var cam_target_pos = target_pos + Vector3(5, 4, 8)
			tween.parallel().tween_property(cam, "global_position", cam_target_pos, 1.5)
			var look_at_target = npc_node.global_position + Vector3(0, 1.5, 0)
			tween.parallel().tween_method(func(_val): cam.look_at(look_at_target), 0.0, 1.0, 1.5)
		
		await tween.finished

func run_dialogue_step(text, time, is_cinematic = false, audio_stream: AudioStream = null):
	if voice_player and audio_stream:
		voice_player.stream = audio_stream
		voice_player.play()

	if dialogue_ui and dialogue_ui.has_method("show_text"):
		dialogue_ui.show_text(text, time, is_cinematic)
		await dialogue_ui.finished
	else:
		await get_tree().create_timer(time).timeout
	
	if voice_player and voice_player.playing:
		voice_player.stop()

func apply_camera_shake(duration: float, intensity: float):
	if not cam: return
	var original_h = cam.h_offset
	var original_v = cam.v_offset
	var elapsed = 0.0
	
	while elapsed < duration:
		if not is_inside_tree() or not get_tree():
			return
			
		cam.h_offset = original_h + randf_range(-intensity, intensity)
		cam.v_offset = original_v + randf_range(-intensity, intensity)
		elapsed += get_process_delta_time()
		
		await get_tree().process_frame
		
	cam.h_offset = original_h
	cam.v_offset = original_v

func _on_blocker_trigger_entered(body):
	if body == player and not npc_cutscene_played:
		if dialogue_ui and not dialogue_ui.visible:
			var p_name = "Player"
			if GameManager.get("player_name"): p_name = GameManager.player_name
			run_dialogue_step(p_name + ": I should check that person over there first.", 3.5, true)

func _on_pan_trigger_activated():
	var p_name = "Player"
	if GameManager.get("player_name"): p_name = GameManager.player_name
	await run_dialogue_step(p_name + ": Look at that... nature is taking back the city.", 4.0, true)

func _on_pan_trigger_2_activated():
	var p_name = "Player"
	if GameManager.get("player_name"): p_name = GameManager.player_name
	
	if not quest_completed and not npc_cutscene_played:
		if arrow_mesh: arrow_mesh.visible = true
		if objective_arrow: start_arrow_bounce()
		
		# --- Heard Help: Show "?" and "Investigate" label ---
		if objective_marker_1:
			objective_marker_1.visible = true
			if lbl_investigate: lbl_investigate.visible = true
			if lbl_get_medkit: lbl_get_medkit.visible = false
			if lbl_bring_medkit: lbl_bring_medkit.visible = false
			
	await run_dialogue_step("Unknown: HELP!", 2.0, true, VO_INTRO_0)
	apply_camera_shake(0.5, 0.2)
	await run_dialogue_step(p_name + ": Oh no I think I heard it there!", 3.0, true)

func start_arrow_bounce():
	if not objective_arrow: return
	var tween = create_tween().set_loops()
	var start_y = objective_arrow.position.y
	var end_y = start_y + 1.5
	tween.tween_property(objective_arrow, "position:y", end_y, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(objective_arrow, "position:y", start_y, 0.5).set_trans(Tween.TRANS_SINE)

func _on_player_low_health():
	if dialogue_ui and not dialogue_ui.visible:
		var p_name = "Player"
		if GameManager.get("player_name"): p_name = GameManager.player_name
		dialogue_ui.show_text(p_name + ": My vision is blurring... I need to heal.", 3.0, true)

func _on_dog_low_health():
	if dialogue_ui and not dialogue_ui.visible:
		var p_name = "Player"
		var d_name = "Dog"
		if GameManager.get("player_name"): p_name = GameManager.player_name
		if GameManager.get("dog_name"): d_name = GameManager.dog_name
		dialogue_ui.show_text(p_name + ": Hold on " + d_name + "! I've got you!", 3.0, true)
