extends Area3D

# Siguraduhing i-drag mo ang Scene5.tscn dito sa Inspector slot na 'Next Scene Path'
@export_file("*.tscn") var next_scene_path: String 

@onready var interact_label = $CanvasLayer/InteractLabel

var player_in_range = false

func _ready():
	# Setup signals
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	# Hide label at start
	if interact_label:
		interact_label.visible = false

func _process(_delta):
	if player_in_range:
		# Pagkapindot ng E, lipat agad
		if Input.is_action_just_pressed("interact") or Input.is_key_pressed(KEY_E):
			transfer_now()

func transfer_now():
	if next_scene_path:
		print("Transerring immediately to: ", next_scene_path)
		# DIRECT LOAD: Walang loading screen, walang art, lipat agad.
		get_tree().change_scene_to_file(next_scene_path)
	else:
		print("CRITICAL ERROR: Nakalimutan mong ilagay ang Scene5.tscn sa Inspector!")

# --- DETECT PLAYER ONLY ---

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		if interact_label:
			interact_label.text = "Press [ E ] to Enter Safe Haven"
			interact_label.visible = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		if interact_label:
			interact_label.visible = false
