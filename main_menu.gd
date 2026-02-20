class_name MainMenu
extends Control

# --- STATUS FLAG ---
var is_starting: bool = false

# --- UI ELEMENTS ---
@onready var fade: ColorRect = $TransitionLayer/Fade
@onready var margin_container: Control = $CanvasLayer/MarginContainer # Kung nasaan ang "Press Any Key" label
@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer

# --- AUDIO ---
@onready var menu_music: AudioStreamPlayer = get_node_or_null("MenuMusic")

func _ready() -> void:
	# 1. Setup Video Loop
	if video_player:
		if not video_player.finished.is_connected(_on_video_finished):
			video_player.finished.connect(_on_video_finished)
		video_player.play()
	
	# 2. Play Music
	if menu_music and not menu_music.playing:
		menu_music.play()
	
	# 3. Intro Animation (Fade In)
	cinematic_fade_in()

# --- INPUT HANDLING (ANY KEY) ---
func _input(event: InputEvent) -> void:
	# Kung nag-start na, ignore inputs
	if is_starting:
		return
		
	# Check kung keyboard press or mouse click
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		start_game_sequence()

# --- MAIN LOGIC ---
func start_game_sequence() -> void:
	is_starting = true
	
	# Optional: Sound effect pag pumindot (Start Sound)
	# if has_node("StartSound"): $StartSound.play()
	
	print("Input detected! Starting game...")
	
	# 1. Start Fade Out
	await cinematic_fade_out()
	
	# 2. Reset Game Data (Optional)
	if GameManager.has_method("start_new_game"):
		GameManager.start_new_game()
	
	# 3. Load Name Selection (SceneLoader handles the Loading Screen)
	SceneLoader.load_scene("res://NameSelectionUI.tscn")

# --- VIDEO LOOP ---
func _on_video_finished() -> void:
	if video_player:
		video_player.play()

# --- ANIMATIONS ---
func cinematic_fade_in(duration: float = 1.2) -> void:
	if not fade: return
	fade.visible = true
	fade.color.a = 1.0 # Start Black
	
	if margin_container: 
		margin_container.modulate.a = 0.0
	
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, duration)
	
	if margin_container: 
		tween.parallel().tween_property(margin_container, "modulate:a", 1.0, duration * 0.75)

func cinematic_fade_out(duration: float = 0.9) -> void:
	var tween := create_tween()
	
	# Fade Visuals (Black Screen)
	if fade:
		fade.visible = true
		tween.tween_property(fade, "color:a", 1.0, duration)
	
	# Fade Music
	if menu_music:
		tween.parallel().tween_property(menu_music, "volume_db", -80.0, duration)
		
	await tween.finished
