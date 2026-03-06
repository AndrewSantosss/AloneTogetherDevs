extends Node3D

# --- VARIABLES ---
@export var dialogue_ui: CanvasLayer 
@export_file("*.tscn") var main_menu_scene: String 

# References base sa Scene Tree mo
@onready var player = $PlayerPackage/Player 
@onready var canvas_layer = $CanvasLayer
@onready var end_screen_label = $CanvasLayer/EndScreenLabel
@onready var fade_rect = $CanvasLayer/ColorRect 

func _ready():
	# 1. INITIAL SETUP
	if end_screen_label:
		end_screen_label.visible = false
		end_screen_label.modulate.a = 0.0
		
	if fade_rect:
		fade_rect.visible = false
		fade_rect.modulate.a = 0.0
		# Siguraduhin na itim ang kulay sa Inspector!

	# --- DISABLE CONTROLS IMMEDIATELY ---
	if player:
		player.set_physics_process(false)
		player.set_process_input(false)
		player.velocity = Vector3.ZERO
		
		# I-lock din ang camera pivot para hindi maikot ang view
		var pivot = player.get_node_or_null("CameraPivot")
		if pivot: pivot.set_process_input(false)
	
	# Simulan ang sequence pagka-spawn
	start_ending_sequence()

func start_ending_sequence():
	# 2. FORCE IDLE ANIMATION
	force_player_idle()
	
	# 3. DIALOGUE SEQUENCE
	if dialogue_ui:
		dialogue_ui.show_text("The Chopper! It's here! \n (Press Enter to Continue)", 1.0, true)
		await dialogue_ui.finished 
		
		force_player_idle()
		dialogue_ui.show_text("We are safe now... we finally made it. \n (Press Enter to Continue)", 1.0, true)
		await dialogue_ui.finished
		
		force_player_idle()
		dialogue_ui.show_text("Let's get out of here. \n (Press Enter to Continue)", 2, true)
		await dialogue_ui.finished # <--- HIHINTO DITO HANGGAT DI TAPOS ANG SALITA
	else:
		await get_tree().create_timer(1.0).timeout 

	# 4. THE 5-SECOND FADE IN (HIHINTO ANG CODE DITO HANGGAT DI TAPOS ANG 5 SECONDS)
	if fade_rect and end_screen_label:
		# I-setup ang visuals
		fade_rect.visible = true
		end_screen_label.text = "To Be Continued"
		end_screen_label.visible = true
		
		# Gumamit ng Tween para sa 5-second transition
		var fade_tween = create_tween().set_parallel(true)
		
		# Fade in ang Black Rect (5 SECONDS)
		fade_tween.tween_property(fade_rect, "modulate:a", 1.0, 5.0) 
		# Fade in ang Text (5 SECONDS)
		fade_tween.tween_property(end_screen_label, "modulate:a", 1.0, 5.0)
		
		# !!! PINAKA-IMPORTANTENG LINE: Hihintayin muna matapos ang 5 seconds bago tumuloy sa baba
		await fade_tween.finished

		# 5. HOLD THE BLACK SCREEN (Extra 4 seconds para mabasa ang text)
		await get_tree().create_timer(4.0).timeout
		
		# 6. FINAL FADE OUT BAGO LUMIPAT
		var final_fade = create_tween().set_parallel(true)
		final_fade.tween_property(canvas_layer, "modulate:a", 0.0, 1.5)
		await final_fade.finished
	
	# 7. CHANGE SCENE (Dito lang siya makakalipat kapag tapos na lahat ng await sa itaas)
	if main_menu_scene:
		get_tree().change_scene_to_file(main_menu_scene)
	else:
		print("Error: Main Menu scene path is missing sa Inspector!")

func force_player_idle():
	if player:
		# Hanapin ang Sprite3D para i-force ang idle animation
		var sprite = player.find_child("Sprite3D", true, false)
		if sprite and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
