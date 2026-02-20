extends Node

# Data to persist across scenes
var has_watched_intro: bool = false
var saved_position: Vector3 = Vector3.ZERO
var saved_health: float = 100.0

# The Names (Default values)
# These variables hold the data selected in NameSelectionUI
var player_name: String = "Hero"
var dog_name: String = "Dog"

const SAVE_PATH = "user://savegame.save"

# Signal to update UI whenever data changes
signal inventory_updated

func _ready():
	load_game()

func start_new_game():
	# Reset variables for a fresh run
	has_watched_intro = false
	saved_health = 100.0
	saved_position = Vector3.ZERO
	player_name = "Hero"
	dog_name = "Dog"
	
	if Inventory:
		Inventory.inventory["medkit"] = 0
		
	print("New Game Started. Data Reset.")

func save_game(player_node):
	has_watched_intro = true
	saved_position = player_node.global_position
	saved_health = player_node.health
	
	var current_medkits = 0
	if Inventory:
		current_medkits = Inventory.get_item_count("medkit")
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var data = {
		"intro": has_watched_intro,
		"pos_x": saved_position.x,
		"pos_y": saved_position.y,
		"pos_z": saved_position.z,
		"health": saved_health,
		"medkits": current_medkits,
		"player_name": player_name,
		"dog_name": dog_name
	}
	file.store_var(data)
	print("GAME SAVED.")

func load_game():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var data = file.get_var()
		
		has_watched_intro = data.get("intro", false)
		saved_health = data.get("health", 100.0)
		player_name = data.get("player_name", "Hero")
		dog_name = data.get("dog_name", "Dog")
		
		var x = data.get("pos_x", 0.0)
		var y = data.get("pos_y", 0.0)
		var z = data.get("pos_z", 0.0)
		saved_position = Vector3(x, y, z)
		
		if Inventory:
			Inventory.inventory["medkit"] = data.get("medkits", 0)
			
		print("Game Loaded. Player: ", player_name)
