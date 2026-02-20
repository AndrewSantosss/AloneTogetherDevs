extends Node

# --- Stored Settings (Default Values) ---
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var show_grass: bool = true
var show_vegetation: bool = true
var shadows_enabled: bool = true
var glow_enabled: bool = true
var fog_enabled: bool = true

func _ready():
	# Connect to signal para ma-detect kapag may bagong node/scene na pumasok
	# Ito ang sikreto para gumana siya "sa lahat ng scenes"
	get_tree().node_added.connect(_on_node_added)

# Awtomatikong ina-apply ang settings sa mga bagong object na pumapasok sa scene
func _on_node_added(node):
	if node.is_in_group("grass"):
		node.visible = show_grass
	elif node.is_in_group("vegetations"):
		node.visible = show_vegetation
	elif node is WorldEnvironment:
		apply_environment_settings(node)
	elif node is Light3D and node.is_in_group("lights"):
		if "shadow_enabled" in node:
			node.shadow_enabled = shadows_enabled

# --- Functions na tatawagin galing sa PauseMenu ---

func update_grass(value: bool):
	show_grass = value
	get_tree().call_group("grass", "set_visible", value)

func update_vegetation(value: bool):
	show_vegetation = value
	get_tree().call_group("vegetations", "set_visible", value)

func update_shadows(value: bool):
	shadows_enabled = value
	var lights = get_tree().get_nodes_in_group("lights")
	for light in lights:
		if "shadow_enabled" in light:
			light.shadow_enabled = value
	
	# Optional: I-off din ang shadow casting ng grass/trees para tipid sa performance
	var shadow_mode = 1 if value else 0 # 1 = ON, 0 = OFF
	get_tree().call_group("grass", "set_cast_shadows_setting", shadow_mode)
	get_tree().call_group("vegetations", "set_cast_shadows_setting", shadow_mode)

func update_glow(value: bool):
	glow_enabled = value
	apply_env_update()

func update_fog(value: bool):
	fog_enabled = value
	apply_env_update()

# Helper para hanapin ang WorldEnvironment at i-apply ang settings
func apply_env_update():
	var env = get_world_environment_node()
	if env:
		apply_environment_settings(env)

func apply_environment_settings(env_node: WorldEnvironment):
	if env_node.environment:
		env_node.environment.glow_enabled = glow_enabled
		env_node.environment.fog_enabled = fog_enabled
		env_node.environment.volumetric_fog_enabled = fog_enabled

func get_world_environment_node():
	var root = get_tree().current_scene
	if root:
		return root.find_child("WorldEnvironment", true, false)
	return null

# --- Audio ---
func update_master_volume(value: float):
	master_volume = value
	var idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(idx, linear_to_db(value))
	AudioServer.set_bus_mute(idx, value < 0.05)

func update_sfx_volume(value: float):
	sfx_volume = value
	var idx = AudioServer.get_bus_index("SFX")
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(value))
		AudioServer.set_bus_mute(idx, value < 0.05)
