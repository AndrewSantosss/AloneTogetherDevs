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
	# Kukunin natin ang naka-save na settings mula sa Autoload
	if SettingsManager:
		if grass_check: grass_check.button_pressed = SettingsManager.show_grass
		if trees_check: trees_check.button_pressed = SettingsManager.show_vegetation
		if shadows_check: shadows_check.button_pressed = SettingsManager.shadows_enabled
		if glow_check: glow_check.button_pressed = SettingsManager.glow_enabled
		if fog_check: fog_check.button_pressed = SettingsManager.fog_enabled
		
		if master_slider: master_slider.value = SettingsManager.master_volume
		if sfx_slider: sfx_slider.value = SettingsManager.sfx_volume
	else:
		print("Error: SettingsManager Autoload not found! Make sure to add it in Project Settings.")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause():
	is_paused = !is_paused
	get_tree().paused = is_paused
	visible = is_paused
	
	if is_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		show_main_menu()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		settings_menu.visible = false 
		main_menu.visible = true

# --- BUTTON SIGNALS ---

func _on_resume_button_pressed():
	is_paused = false
	get_tree().paused = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_settings_button_pressed():
	main_menu.visible = false
	settings_menu.visible = true

func _on_back_button_pressed():
	show_main_menu()

func _on_quit_button_pressed():
	get_tree().quit()

# --- GRAPHICS TOGGLES (Connected to Signals) ---

func _on_grass_check_pressed():
	SettingsManager.update_grass(grass_check.button_pressed)

func _on_trees_check_pressed():
	SettingsManager.update_vegetation(trees_check.button_pressed)

func _on_shadows_check_pressed():
	SettingsManager.update_shadows(shadows_check.button_pressed)

func _on_glow_check_pressed():
	SettingsManager.update_glow(glow_check.button_pressed)

func _on_fog_check_pressed():
	SettingsManager.update_fog(fog_check.button_pressed)

# --- VOLUME ---

func _on_master_volume_changed(value):
	SettingsManager.update_master_volume(value)

func _on_sfx_volume_changed(value):
	SettingsManager.update_sfx_volume(value)

func show_main_menu():
	settings_menu.visible = false
	main_menu.visible = true
