# player.gd
# Complete robot player with combat, time penalties, and reset functionality
extends CharacterBody2D

# Movement settings
@export var speed: float = 200.0
@export var jump_velocity: float = -300.0
@export var acceleration: float = 800.0
@export var friction: float = 1000.0

# Combat settings
var is_invincible: bool = false
var invincibility_time: float = 1.0

# Reset functionality
var starting_position: Vector2

# References
var main_game: Node2D
@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var hit_timer = Timer.new()

func _ready():
	add_to_group("player")
	
	# Store starting position
	starting_position = global_position
	print("Player starting position stored: ", starting_position)
	
	# Find main game node
	main_game = get_node("/root/Game")
	if not main_game:
		main_game = get_parent()
	
	if main_game:
		print("Player connected to game manager")
	else:
		print("Could not find game manager")
	
	# Setup invincibility timer
	add_child(hit_timer)
	hit_timer.wait_time = invincibility_time
	hit_timer.one_shot = true
	hit_timer.timeout.connect(_on_invincibility_end)
	
	print("Robot player ready!")

func _physics_process(delta):
	# Handle gravity
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Handle horizontal movement
	var direction = Input.get_axis("ui_left", "ui_right")
	
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
		_flip_sprite(direction)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	move_and_slide()

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F:
				attack()
			KEY_G:
				special_action()

func attack():
	print("Robot attacks!")
	
	# Apply time penalty
	if main_game and main_game.has_method("apply_time_penalty"):
		main_game.apply_time_penalty("hit")
		print("Attack cost 5 seconds!")
	
	# Simple area-based attack - check all enemies in scene
	var enemies = get_tree().get_nodes_in_group("enemies")
	print("Checking ", enemies.size(), " enemies for hits")
	
	for enemy in enemies:
		var distance = global_position.distance_to(enemy.global_position)
		
		if distance < 80:  # Attack range
			print("ENEMY HIT!")
			if enemy.has_method("take_damage"):
				enemy.take_damage(1)

func special_action():
	print("Robot special action!")
	
	# Apply time penalty
	if main_game and main_game.has_method("apply_time_penalty"):
		main_game.apply_time_penalty("special")
		print("Special action cost 3 seconds!")

func take_hit(damage_source: String = "enemy"):
	if is_invincible:
		return
	
	print("Robot takes hit from: ", damage_source)
	
	# Apply time penalty
	if main_game and main_game.has_method("apply_time_penalty"):
		main_game.apply_time_penalty("hit")
		print("Hit penalty applied - lost 5 seconds!")
	
	# Start invincibility
	is_invincible = true
	hit_timer.start()
	
	# Visual feedback
	_show_hit_effect()

func reset_to_start():
	global_position = starting_position
	velocity = Vector2.ZERO
	is_invincible = false
	
	# Reset visual effects
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE
		animated_sprite.flip_h = false
	
	# Stop timers
	if hit_timer:
		hit_timer.stop()
	
	print("Player reset to starting position: ", starting_position)

func _show_hit_effect():
	# Flash red
	if animated_sprite:
		animated_sprite.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)

func _flip_sprite(direction: float):
	if animated_sprite:
		if direction > 0:
			animated_sprite.flip_h = false
		elif direction < 0:
			animated_sprite.flip_h = true

func _on_invincibility_end():
	is_invincible = false
	print("Robot invincibility ended")

# Called when player reaches level exit
func _on_level_exit_entered():
	if main_game and main_game.has_method("can_complete_level"):
		if main_game.can_complete_level():
			main_game.level_complete()
		else:
			print("Need to defeat more enemies before exiting!")
