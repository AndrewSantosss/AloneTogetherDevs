extends CanvasLayer

# --- References ---
@onready var main_menu = $MenuContainer/MainMenu
@onready var settings_menu = $SettingsMenu

# --- Toggles ---
@onready var grass_check = $SettingsMenu/SettingsMenu2/GrassCheck
@onready var trees_check = $SettingsMenu/SettingsMenu3/TreesCheck
@onready var shadows_check = $SettingsMenu/SettingsMenu4/ShadowsCheck
@onready var glow_check = $SettingsMenu/SettingsMenu5/GlowCheck
@onready var fog_check = $SettingsMenu/SettingsMenu6/FogCheck

# --- Sliders ---
@onready var master_slider = $SettingsMenu/MasterSlider 
@onready var sfx_slider = $SettingsMenu/SFXSlider

var is_paused = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	visible = false 
	settings_menu.visible = false 
	main_menu.visible = true
	
	# --- SYNC UI WITH SETTINGS MANAGER ---
	if SettingsManager:
		if grass_check: grass_check.button_pressed = SettingsManager.show_grass
		if trees_check: trees_check.button_pressed = SettingsManager.show_vegetation
		if shadows_check: shadows_check.button_pressed = SettingsManager.shadows_enabled
		if glow_check: glow_check.button_pressed = SettingsManager.glow_enabled
		if fog_check: fog_check.button_pressed = SettingsManager.fog_enabled

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause():
	is_paused = !is_paused
	get_tree().paused = is_paused
	visible = is_paused
	
	# --- FIX: Itago ang Gameplay UI ---
	# Tatawagin nito ang lahat ng nodes sa group na "gameplay_ui"
	get_tree().call_group("gameplay_ui", "set_visible", !is_paused)

	if is_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		show_main_menu()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		settings_menu.visible = false 
		main_menu.visible = true

func show_main_menu():
	main_menu.visible = true
	settings_menu.visible = false

# --- BUTTON SIGNALS ---

func _on_resume_button_pressed():
	toggle_pause() # Mas malinis na gamitin ang toggle_pause para sa sync

func _on_settings_button_pressed():
	main_menu.visible = false
	settings_menu.visible = true

func _on_back_button_pressed():
	show_main_menu()

func _on_quit_button_pressed():
	get_tree().quit()

# --- GRAPHICS TOGGLES ---

func _on_grass_check_pressed():
	SettingsManager.update_grass(grass_check.button_pressed)

func _on_trees_check_pressed():
	SettingsManager.update_vegetation(trees_check.button_pressed)

func _on_shadows_check_pressed():
	SettingsManager.update_shadows(shadows_check.button_pressed)

func _on_glow_check_pressed():
	SettingsManager.update_glow(glow_check.button_pressed)
