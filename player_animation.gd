extends AnimatedSprite2D

func _ready() -> void:
	autoplay = "Idle"
	animation_looped.connect(_animation_completed)
	
func _animation_completed() -> void:
	play("Idle")
