extends OmniLight3D

@export var min_attenuation: float = 0.5   # Pinaka-maliwanag
@export var max_attenuation: float = 8.0   # Pinaka-madilim
@export var blink_speed: float = 0.6       # Bilis ng pag-blink (seconds)

func _ready():
	start_blinking()

func start_blinking():
	# Gumawa ng Tween na naka-infinite loop
	var tween = create_tween().set_loops()
	
	# 1. Transition papuntang Madilim
	# Kailangan ang set_trans ay nakadugtong mismo sa tween_property call
	tween.tween_property(self, "light_attenuation", max_attenuation, blink_speed).set_trans(Tween.TRANS_SINE)
	
	# 2. Transition papuntang Maliwanag
	tween.tween_property(self, "light_attenuation", min_attenuation, blink_speed).set_trans(Tween.TRANS_SINE)
