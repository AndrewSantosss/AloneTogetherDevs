extends CanvasLayer

signal finished 
signal dialogue_finished

@onready var system_bg = get_node_or_null("SystemBackground")
@onready var system_label = get_node_or_null("SystemBackground/SystemLabel")
@onready var cinematic_label = get_node_or_null("CinematicLabel")
@onready var old_background = get_node_or_null("Background")

# Settings
@export var typing_speed: float = 0.04 # Seconds per character
var skip_requested = false
var active_node: Control 

func _ready():
	visible = false
	if old_background: old_background.visible = false
	setup_ui_styles()

func setup_ui_styles():
	# --- 1. SETUP SYSTEM INSTRUCTIONS (Green Box) ---
	if system_bg and system_label:
		system_bg.visible = false
		var box_style = StyleBoxFlat.new()
		box_style.bg_color = Color(0.0, 0.0, 0.0, 0.5) 
		box_style.set_corner_radius_all(0)
		box_style.content_margin_left = 15
		box_style.content_margin_right = 15
		box_style.content_margin_top = 8
		box_style.content_margin_bottom = 8
		
		if system_bg.has_method("add_theme_stylebox_override"):
			system_bg.add_theme_stylebox_override("panel", box_style)
		
		system_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT 
		system_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		var sys_style = LabelSettings.new()
		sys_style.font_color = Color.WHITE
		sys_style.font_size = 15
		sys_style.shadow_size = 2
		sys_style.shadow_color = Color(0,0,0,0.5)
		system_label.label_settings = sys_style
	
	# --- 2. SETUP HERO DIALOGUE (Bottom) ---
	if cinematic_label: 
		cinematic_label.visible = false
		cinematic_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		cinematic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cinematic_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		cinematic_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cinematic_label.position.y -= 20 
		
		var hero_style = LabelSettings.new()
		hero_style.font_color = Color.WHITE
		hero_style.outline_size = 4        
		hero_style.outline_color = Color.BLACK
		hero_style.font_size = 18          
		cinematic_label.label_settings = hero_style

func _input(event):
	if not visible: return
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		skip_requested = true

func start_dialogue(lines: Array):
	for line in lines:
		# Pass '0' as time so it auto-calculates based on length
		await show_text(line, 0) 
	emit_signal("dialogue_finished")

func show_text(_text: String, manual_time: float = 0.0, is_cinematic: bool = true):
	visible = true
	skip_requested = false
	if old_background: old_background.visible = false
	
	# 1. SELECT ACTIVE LABEL
	var target_label: Label
	if is_cinematic and cinematic_label:
		if system_bg: system_bg.visible = false 
		cinematic_label.visible = true
		active_node = cinematic_label 
		target_label = cinematic_label
	elif system_bg and system_label:
		if cinematic_label: cinematic_label.visible = false
		system_bg.visible = true
		active_node = system_bg 
		target_label = system_label
	else:
		finished.emit()
		return

	# 2. CALCULATE DURATION (Auto-Fix for "Too Fast")
	# If manual_time is 0 or too short, we calculate a safe reading time.
	# Formula: 0.05s per character + 2.0s base time
	var calculated_time = _text.length() * 0.08 + 2.5
	var final_duration = max(manual_time, calculated_time)

	# 3. TYPEWRITER EFFECT
	target_label.text = _text
	target_label.visible_ratio = 0.0 # Hide text initially
	active_node.modulate.a = 1.0     # Ensure box is visible
	
	var type_duration = _text.length() * typing_speed
	var tween = create_tween()
	tween.tween_property(target_label, "visible_ratio", 1.0, type_duration)
	
	# Wait for typing to finish
	while tween.is_running():
		if skip_requested:
			tween.kill()
			target_label.visible_ratio = 1.0
			break
		await get_tree().process_frame
	
	skip_requested = false # Reset skip so we don't skip the reading phase instantly

	# 4. READING PHASE (The "Stay" Time)
	var timer = 0.0 # FIXED: Starts at 0.0 now!
	while timer < final_duration:
		if skip_requested:
			break
		timer += get_process_delta_time()
		await get_tree().process_frame
	
	# 5. FADE OUT
	var fade_out = create_tween()
	fade_out.tween_property(active_node, "modulate:a", 0.0, 0.5)
	await fade_out.finished
	
	visible = false
	finished.emit()

func close_dialogue():
	visible = false
	emit_signal("dialogue_finished")
