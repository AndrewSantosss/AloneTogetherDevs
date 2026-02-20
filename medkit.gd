extends Area3D

@export var item_name: String = "medkit"
@export var quantity: int = 1
@export var rotate_speed: float = 1.0

@onready var visual_node = $Visuals

func _ready():
	# Add to loot group so Dog can find it
	add_to_group("loot")
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# Simple bobbing animation
	var tween = create_tween().set_loops()
	tween.tween_property(visual_node, "position:y", 0.2, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(visual_node, "position:y", -0.2, 1.0).set_trans(Tween.TRANS_SINE)

func _process(delta):
	visual_node.rotate_y(rotate_speed * delta)

func _on_body_entered(body):
	if body.name == "Player" or body.is_in_group("player"):
		if Inventory:
			Inventory.add_item(item_name, quantity)
			
			# --- DAGDAG MO 'TO ---
			if body.has_method("play_pickup_animation"):
				body.play_pickup_animation("Medkit")
			# --------------------

			print("Picked up Medkit!")
			queue_free()
		else:
			print("Error: Inventory Autoload not found! Check Project Settings.")
