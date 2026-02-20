extends Area3D

# --- ADD THIS SIGNAL ---
signal triggered 

@export var duration: float = 2.0
@export var hold_time: float = 1.5
@export var one_shot: bool = true 

@onready var camera_target = $CameraTarget

var has_triggered = false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if one_shot and has_triggered:
		return
		
	if body.is_in_group("player"):
		# --- EMIT THE SIGNAL HERE ---
		triggered.emit()
		
		if body.camera_pivot:
			has_triggered = true
			body.camera_pivot.pan_to_position(
				camera_target.global_position, 
				camera_target.global_rotation.y, 
				duration, 
				hold_time
			)
