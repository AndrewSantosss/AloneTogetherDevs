extends Control

# --- NODES ---
@onready var grid_container = $Panel/MarginContainer/GridContainer
@onready var panel = $Panel
@onready var animated_sprite = $AnimatedSprite2D

# --- SETTINGS ---
@export var auto_close_time: float = 5.0 # Seconds before auto-closing

# --- STATE ---
var is_open: bool = false
var close_timer: Timer

# --- ICON DATABASE ---
# Ensure you have these images in your res://misc/ folder
var item_icons = {
	"medkit": preload("res://misc/medkit.png"),
	"candy": preload("res://misc/candy.png"),
	"ammo": preload("res://misc/candy.png")

}

func _ready():
	# 1. Setup Initial State
	panel.visible = false 
	
	# Set Pivot for Smooth Expansion
	panel.pivot_offset = Vector2(0, panel.size.y / 2)
	
	# Start with the looping "Closed" animation if it exists
	if animated_sprite:
		if animated_sprite.sprite_frames.has_animation("Closed"):
			animated_sprite.play("Closed")
		elif animated_sprite.sprite_frames.has_animation("Close"):
			animated_sprite.play("Close")
			animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("Close") - 1
			animated_sprite.stop()

	# 2. Timer Setup
	close_timer = Timer.new()
	close_timer.wait_time = auto_close_time
	close_timer.one_shot = true
	close_timer.timeout.connect(close_inventory)
	add_child(close_timer)

	# 3. Inventory Signal
	if Inventory:
		if not Inventory.inventory_updated.is_connected(_on_inventory_updated):
			Inventory.inventory_updated.connect(_on_inventory_updated)
		update_display() 

func _input(event):
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory()
	
	# Reset timer on activity
	if is_open and event.is_pressed():
		close_timer.start()

# ========================================================
#                 OPEN / CLOSE LOGIC
# ========================================================

func toggle_inventory():
	if is_open:
		close_inventory()
	else:
		open_inventory()

func open_inventory():
	if is_open: return
	is_open = true
	
	# 1. Play Bag Open Animation
	if animated_sprite:
		animated_sprite.play("Open")
		await animated_sprite.animation_finished
	
	# 2. Animate Panel Expanding (Left to Right)
	if is_open:
		panel.visible = true
		panel.scale = Vector2(0, 1) # Start with width 0
		
		# Create Tween for smooth expansion
		var tween = create_tween()
		tween.tween_property(panel, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		update_display()
		close_timer.start() 

func close_inventory():
	if not is_open: return
	is_open = false
	
	# 1. Animate Panel Shrinking (Right to Left)
	var tween = create_tween()
	tween.tween_property(panel, "scale", Vector2(0, 1), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	panel.visible = false
	
	# 2. Play Close Animation
	if animated_sprite:
		animated_sprite.play("Close")
		await animated_sprite.animation_finished
		
		# 3. Play Idle Loop
		if not is_open and animated_sprite.sprite_frames.has_animation("Closed"):
			animated_sprite.play("Closed")

# ========================================================
#                 DISPLAY / RENDER LOGIC
# ========================================================

func _on_inventory_updated(_item_name, _quantity):
	if is_open:
		update_display()

func update_display():
	for child in grid_container.get_children():
		child.queue_free()
	
	if not Inventory: return

	for item_name in Inventory.inventory:
		var count = Inventory.inventory[item_name]
		if count > 0:
			create_slot(item_name, count)

func create_slot(item_name: String, count: int):
	# A. Slot Container
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(64, 64)
	
	# --- ADD GRID STYLE ---
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.5) 
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.5, 0.5, 0.5)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	
	slot.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	slot.add_child(vbox)
	
	# B. Icon
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	if item_name in item_icons:
		icon.texture = item_icons[item_name]
		icon.modulate = Color.WHITE
	else:
		# Fallback colors if image missing
		if item_name == "candy":
			icon.modulate = Color.CYAN
		else:
			icon.modulate = Color.RED 
	
	vbox.add_child(icon)
	
	# C. Count Label
	var label = Label.new()
	label.text = "x" + str(count)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 14)
	
	vbox.add_child(label)
	grid_container.add_child(slot)
