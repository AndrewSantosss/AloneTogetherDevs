extends Control

# --- STATUS FLAG ---
var is_starting: bool = false

# Target background (TextureRect)
@onready var bg_texture: TextureRect = $CanvasLayer/TextureRect # Updated path base sa tscn
# Gaano kalayo ang galaw
@export var parallax_strength: float = 20.0

# --- UI ELEMENTS ---
@onready var fade: ColorRect = $TransitionLayer/Fade
@onready var margin_container: Control = $CanvasLayer/MarginContainer
@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer

# --- AUDIO ---
@onready var menu_music: AudioStreamPlayer = get_node_or_null("MenuMusic")

func _ready() -> void:
	# Ibalik ang pulsing animation
	setup_pulsing_label()
	
	process_mode = PROCESS_MODE_ALWAYS
	set_process_input(true)
	
	if video_player:
		if not video_player.finished.is_connected(_on_video_finished):
			video_player.finished.connect(_on_video_finished)
		video_player.play()
	
	if menu_music and not menu_music.playing:
		menu_music.play()
	
	cinematic_fade_in()

func setup_pulsing_label() -> void:
	# Hanapin ang Label sa loob ng CanvasLayer base sa tscn mo
	var label = get_node_or_null("CanvasLayer/Label")
	if label:
		var tween = create_tween().set_loops()
		tween.tween_property(label, "modulate:a", 0.3, 1.5).set_trans(Tween.TRANS_SINE)
		tween.tween_property(label, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	# Fish Eye / Distortion Shader Logic
	if bg_texture and bg_texture.material:
		var screen_size = get_viewport().get_visible_rect().size
		var mouse_pos = get_viewport().get_mouse_position()
		
		# I-normalize ang mouse position (0.0 to 1.0)
		var target_mouse_uv = Vector2(
			mouse_pos.x / screen_size.x,
			mouse_pos.y / screen_size.y
		)
		
		var current_mouse_uv = bg_texture.material.get_shader_parameter("mouse_pos")
		if current_mouse_uv == null: current_mouse_uv = Vector2(0.5, 0.5)
		
		# Smooth interpolation para sa shader
		var smooth_uv = current_mouse_uv.lerp(target_mouse_uv, 1.0 - exp(-5.0 * delta))
		bg_texture.material.set_shader_parameter("mouse_pos", smooth_uv)

# --- INPUT HANDLING ---
func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton):
		if event.pressed and not event.is_echo() and not is_starting:
			start_game_sequence()

# --- THE TRANSITION (1s Fade + 2s Dark + Volume Out) ---
func start_game_sequence() -> void:
	is_starting = true
	set_process_input(false)
	
	print("--- STARTING TRANSITION (1s Fade + 2s Dark) ---")
	
	# 1. GUMAWA NG CANVASLAYER PARA SA FADE
	var fade_layer = CanvasLayer.new()
	fade_layer.layer = 128 
	get_tree().root.add_child(fade_layer)
	
	# 2. GUMAWA NG COLORRECT
	var pure_fade = ColorRect.new()
	pure_fade.color = Color(0, 0, 0, 0)
	pure_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pure_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(pure_fade)
	
	# 3. ANIMATION: 1 SECOND FADE + VOLUME DOWN
	var tween = create_tween()
	
	# Screen fade to black (1s)
	tween.tween_property(pure_fade, "color:a", 1.0, 1.0).set_trans(Tween.TRANS_LINEAR)
	
	# Music volume fade out (1s)
	if menu_music:
		tween.parallel().tween_property(menu_music, "volume_db", -80.0, 1.0).set_trans(Tween.TRANS_SINE)
	
	# 4. STAY DARK FOR 2 SECONDS
	tween.tween_interval(2.0)
	
	# Hintayin matapos ang buong 3 seconds
	await tween.finished
	
	print("--- 3s PASSED, CHANGING SCENE ---")
	
	# 5. DIREKTANG LIPAT
	get_tree().change_scene_to_file("res://NameSelectionUI.tscn")
	
	# Linisin ang nodes
	fade_layer.queue_free()

func _on_video_finished() -> void:
	if video_player:
		video_player.play()

func cinematic_fade_in(duration: float = 1.2) -> void:
	# Hanapin ang fade node sa tamang path
	var initial_fade = get_node_or_null("TransitionLayer/Fade")
	if not initial_fade: return
	
	initial_fade.visible = true
	initial_fade.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(initial_fade, "color:a", 0.0, duration)
