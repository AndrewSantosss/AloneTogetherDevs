extends Node3D

@onready var anim_player = $AnimationPlayer

func _ready():
	# Start cinematic sequence on load
	if anim_player:
		if anim_player.has_animation("wakeup"):
			anim_player.play("wakeup")
		else:
			print("ERROR: Animation 'wakeup' not found in IntroSequence!")
			# Fallback if animation is missing: go straight to game
			start_gameplay()

# Called by AnimationPlayer at the end of the timeline
func start_gameplay():
	print("Cinematic finished. Loading Scene 1...")
	
	# Use standard Godot function instead of custom SceneLoader
	# Make sure Scene1.tscn exists in your file system!
	get_tree().change_scene_to_file("res://Scene1.tscn")
