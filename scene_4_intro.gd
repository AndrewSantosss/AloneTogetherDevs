extends Node3D

@onready var anim_player = $AnimationPlayer
@onready var skip_label = $CanvasLayer/SkipLabel # Ang pulsing text (e.g., "Hold E to Skip")
@onready var progress_label = $CanvasLayer/ProgressLabel # Ang progress text (e.g., "Skipping... 0%")

# --- SKIP SETTINGS ---
var skip_hold_time: float = 0.0
var required_skip_time: float = 2.0 # Kailangan i-hold ng 2 seconds
var is_skipping: bool = false

func _ready():
	# FIX: I-force ang camera na gamitin ang tamang environment ng scene na ito
	var cam = get_viewport().get_camera_3d()
	if cam:
		cam.environment = null 
	
	# Start cinematic sequence on load
	if anim_player:
		if anim_player.has_animation("night"):
			anim_player.play("night")
			anim_player.seek(0.1, true)
		else:
			print("ERROR: Animation 'wakeup' not found!")
			start_gameplay()
	
	# Setup initial states
	if skip_label:
		skip_label.modulate.a = 0.0
		setup_pulsing_skip_label()
	
	if progress_label:
		progress_label.visible = false # Itago muna ang progress label

func _process(delta):
	# HOLD E TO SKIP LOGIC
	if Input.is_key_pressed(KEY_E):
		skip_hold_time += delta
		
		# Ipakita ang progress
		if progress_label:
			progress_label.visible = true
			var percentage = int((skip_hold_time / required_skip_time) * 100)
			progress_label.text = "Skipping... " + str(clamp(percentage, 0, 100)) + "%"
		
		# Fade in ang skip label habang pinipindot
		if skip_label:
			skip_label.modulate.a = lerp(skip_label.modulate.a, 1.0, delta * 5.0)
		
		if skip_hold_time >= required_skip_time and not is_skipping:
			is_skipping = true
			start_gameplay()
	else:
		# I-reset ang timer at itago ang progress kapag binitawan ang E
		skip_hold_time = move_toward(skip_hold_time, 0.0, delta * 2.0)
		
		if progress_label:
			progress_label.visible = false
			
		if skip_label:
			# Fade out ang skip label kapag walang input
			skip_label.modulate.a = lerp(skip_label.modulate.a, 0.0, delta * 2.0)

func setup_pulsing_skip_label():
	# Pulse effect (Fade in and out) gamit ang Alpha
	var tween = create_tween().set_loops()
	tween.tween_property(skip_label, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(skip_label, "modulate:a", 0.3, 1.0).set_trans(Tween.TRANS_SINE)

func start_gameplay():
	print("Proceeding to Loading Screen...")
	
	# Pagtatago ng UI elements para hindi sila sumama sa Loading Screen 
	if skip_label:
		skip_label.visible = false
	if progress_label:
		progress_label.visible = false 
	
	# Kung gumagamit ka ng CanvasLayer, maaari mong itago ang buong layer [cite: 56]
	var ui_layer = get_node_or_null("CanvasLayer")
	if ui_layer:
		ui_layer.visible = false 
	
	# Gamitin ang SceneLoader para lumitaw ang LoadingScreen.tscn [cite: 54]
	if get_node_or_null("/root/SceneLoader"):
		SceneLoader.load_scene("res://Scene4.tscn")
	else:
		# Fallback kung hindi naka-autoload ang SceneLoader [cite: 9]
		get_tree().change_scene_to_file("res://Scene4.tscn")
