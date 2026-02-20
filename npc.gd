extends CharacterBody3D

@export var prompt_text: String = "Talk to Survivor"

# --- NODES ---
@onready var animated_sprite = $Sprite3D

var dialogue_ui: CanvasLayer
var player: CharacterBody3D

func _ready():
	# 1. Start Idle Animation immediately
	play_idle()
	
	# 2. Find Player
	player = get_tree().get_first_node_in_group("player")
	
	# 3. Find Dialogue UI (Robust Search)
	dialogue_ui = get_tree().get_first_node_in_group("dialogue_ui")
	
	if not dialogue_ui:
		var current_scene = get_tree().current_scene
		if current_scene:
			dialogue_ui = current_scene.find_child("DialogueUI", true, false)

	if not dialogue_ui:
		print("WARNING: NPC could not find DialogueUI!")

# --- ANIMATION HELPER FUNCTIONS ---
func play_idle():
	if animated_sprite:
		animated_sprite.play("idle")

func play_talk():
	if animated_sprite:
		animated_sprite.play("talk")

func run_npc_dialogue():
	# 1. Lock Player
	if player:
		player.set_physics_process(false)
	
	# 2. Start Talking Animation
	play_talk()
	
	# 3. Play Dialogue Sequence
	await show_text("Wait! Don't shoot! I'm... I'm human.", 3.0)
	await show_text("I've been stranded here since the horde broke through the highway blockade.", 4.0)
	await show_text("If you're going out there, watch your back.", 3.0)
	
	# 4. Save Game (Connected to GameManager)
	if GameManager.has_method("save_game") and player:
		# This saves position, health, and current scene
		GameManager.save_game(player)
		await show_text("Game Saved.", 2.0)
	
	# 5. Return to Idle Animation
	play_idle()
	
	# 6. Unlock Player
	if player:
		player.set_physics_process(true)

# Helper to show text and wait for it to finish
func show_text(text, time):
	if dialogue_ui and dialogue_ui.has_method("show_text"):
		dialogue_ui.show_text(text, time)
		await dialogue_ui.finished
	else:
		print("[NPC]: ", text)
		await get_tree().create_timer(time).timeout
