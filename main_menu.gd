class_name MainMenu
extends Control

# --- STATUS FLAG ---
var is_starting: bool = false

# Target background (TextureRect)
@onready var bg_texture: TextureRect = $CanvasLayer/TextureRect 
# Gaano kalayo ang galaw
@export var parallax_strength: float = 20.0

# --- UI ELEMENTS ---
@onready var label_press_any = $CanvasLayer/Label
@onready var label_story = $CanvasLayer/Label2
@onready var fade: ColorRect = $TransitionLayer/FadeOverlay
@onready var margin_container: Control = $CanvasLayer/MarginContainer

# --- AUDIO ---
@onready var menu_music: AudioStreamPlayer = get_node_or_null("MenuMusic")

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	set_process_input(true)
	
	# 1. Setup Initial States
	if label_press_any:
		label_press_any.modulate.a = 0.0 # Start invisible
		setup_pulsing_label()
		
	if label_story:
		label_story.modulate.a = 0.0 # Start invisible
		fade_in_story()

	if menu_music and not menu_music.playing:
		menu_music.play()
	
	cinematic_fade_in()

func setup_pulsing_label() -> void:
	# Fade in and out just like in main menu
	if label_press_any:
		var tween = create_tween().set_loops()
		tween.tween_property(label_press_any, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)
		tween.tween_property(label_press_any, "modulate:a", 0.2, 1.5).set_trans(Tween.TRANS_SINE)

func fade_in_story() -> void:
	# Specific fade in for Label2 (the story text)
	if label_story:
		var tween = create_tween()
		tween.tween_property(label_story, "modulate:a", 1.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _process(delta: float) -> void:
	# Fish Eye / Distortion Shader Logic
	if bg_texture and bg_texture.material:
		var screen_size = get_viewport().get_visible_rect().size
		var mouse_pos = get_viewport().get_mouse_position()
		
		var target_mouse_uv = Vector2(
			mouse_pos.x / screen_size.x,
			mouse_pos.y / screen_size.y
		)
		
		var current_mouse_uv = bg_texture.material.get_shader_parameter("mouse_pos")
		if current_mouse_uv == null: current_mouse_uv = Vector2(0.5, 0.5)
		
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
	
	# Hide the labels immediately on transition start
	if label_press_any: label_press_any.visible = false
	if label_story: label_story.visible = false
	
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
	tween.tween_property(pure_fade, "color:a", 1.0, 1.0).set_trans(Tween.TRANS_LINEAR)
	
	if menu_music:
		tween.parallel().tween_property(menu_music, "volume_db", -80.0, 1.0).set_trans(Tween.TRANS_SINE)
	
	# 4. STAY DARK FOR 2 SECONDS
	tween.tween_interval(2.0)
	
	await tween.finished
	get_tree().change_scene_to_file("res://IntroSequence.tscn")
	fade_layer.queue_free()

func cinematic_fade_in(duration: float = 1.2) -> void:
	if not fade: return
	
	fade.visible = true
	fade.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, duration)
