extends Area3D

# --- VARIABLES ---
@export var dialogue_ui: CanvasLayer 
@export var helicopter: Node3D
# I-drag ang Main Menu scene dito sa Inspector
@export_file("*.tscn") var main_menu_scene: String 

# References base sa Scene Tree mo
@onready var canvas_layer = $CanvasLayer
@onready var end_screen_label = $CanvasLayer/EndScreenLabel
@onready var fade_rect = $CanvasLayer/ColorRect 

var ending_triggered = false

func _ready():
	# Siguraduhing invisible ang ending elements sa simula
	if fade_rect:
		fade_rect.visible = false
		fade_rect.modulate.a = 0.0
	if end_screen_label:
		end_screen_label.visible = false
		end_screen_label.modulate.a = 0.0

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Detection para kay John Andrew (player)
	if not ending_triggered and (body.name == "PlayerPackage" or body.is_in_group("player")):
		start_ending_sequence(body)

func start_ending_sequence(player_body):
	ending_triggered = true
	
	# 1. STOP PLAYER & FORCE IDLE
	if player_body.has_method("set_physics_process"):
		player_body.set_physics_process(false)
		player_body.velocity = Vector3.ZERO
	
	# Hanapin ang Sprite3D para i-force ang idle animation
	var sprite = player_body.find_child("Sprite3D", true, false)
	
	# 2. DIALOGUE SEQUENCE
	if dialogue_ui:
		if sprite: sprite.play("idle")
		dialogue_ui.show_text("The Chopper! It's here!", 3.0, true)
		await dialogue_ui.finished 
		
		if sprite: sprite.play("idle")
		dialogue_ui.show_text("We are safe now... we finally made it.", 3.0, true)
		await dialogue_ui.finished
		
		if sprite: sprite.play("idle")
		dialogue_ui.show_text("Let's get out of here.", 2.5, true)
		await dialogue_ui.finished
	else:
		await get_tree().create_timer(3.0).timeout 

	# 3. THE 5-SECOND FADE IN (Direct Modulate Approach)
	if fade_rect and end_screen_label:
		# Gawing visible pero transparent
		fade_rect.visible = true
		end_screen_label.text = "To Be Continued"
		end_screen_label.visible = true
		
		# Sabay na i-fade ang Itim na Background at ang Text
		var fade_tween = create_tween().set_parallel(true)
		
		# Fade in ang Black Rect (5 Seconds)
		fade_tween.tween_property(fade_rect, "modulate:a", 1.0, 5.0)
		# Fade in ang "To Be Continued" (5 Seconds)
		fade_tween.tween_property(end_screen_label, "modulate:a", 1.0, 5.0)
		
		# Hintayin matapos ang parallel tween
		await fade_tween.finished

		# 4. HOLD THE SCREEN (Reading time)
		await get_tree().create_timer(4.0).timeout
		
		# 5. FINAL FADE OUT BAGO LUMIPAT NG SCENE
		var final_tween = create_tween().set_parallel(true)
		final_tween.tween_property(fade_rect, "modulate:a", 0.0, 1.5)
		final_tween.tween_property(end_screen_label, "modulate:a", 0.0, 1.5)
		await final_tween.finished
	
	# 6. SCENE CHANGE
	if main_menu_scene:
		get_tree().change_scene_to_file(main_menu_scene)
	else:
		print("Error: Main Menu scene path is missing!")
