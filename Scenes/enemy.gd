extends CharacterBody2D
@export var terget : CharacterBody2D
var speed = 70
func _physics_process(delta):
	var direction=(terget.position-position). normalized()
	var distance=(terget.position-position). length()
	if distance < 75  and distance > 5:
		velocity = direction * speed
		#look_at(terget.position)
	else : 
		velocity = Vector2.ZERO

	# Handle gravity
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	move_and_slide()
