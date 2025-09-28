extends CharacterBody2D
@export var terget : CharacterBody2D
var speed = 170
func _physics_process(delta):
	var direction=(terget.position-position). normalized()
	velocity = direction * speed
	look_at(terget.position)
	move_and_slide()
