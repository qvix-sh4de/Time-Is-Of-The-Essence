# player.gd - Complete Fixed Player Script
extends CharacterBody2D

# Movement settings
@export var speed: float = 200.0
@export var jump_velocity: float = -300.0
@export var acceleration: float = 800.0
@export var friction: float = 1000.0

# Combat settings  
@export var attack_range: float = 80.0
var is_invincible: bool = false
var invincibility_time: float = 1.0

# Camera and references
var camera: Camera2D
var main_game: Node2D
@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var hit_timer = Timer.new()

func _ready():
	add_to_group("player")
	
	# Setup camera
	setup_camera()
	
	# Find main game node
	main_game = get_node("/root/Game")
	if not main_game:
		main_game = get_parent()
	
	# Setup invincibility timer
	add_child(hit_timer)
	hit_timer.wait_time = invincibility_time
	hit_timer.one_shot = true
	hit_timer.timeout.connect(_on_invincibility_end)
	
	# FIXED: Collision system - enemies on layer 5 won't push player
	# Player stays on default layer 1, detects platforms on layer 1
	collision_layer = 1  # Player is on layer 1  
	collision_mask = 1   # Player only collides with layer 1 (platforms), NOT layer 5 (enemies)
	# This prevents enemies from pushing the player around
	
	print("Robot player ready with fixed collision!")

func setup_camera():
	# Create and configure camera
	camera = Camera2D.new()
	camera.name = "PlayerCamera"
	camera.enabled = true
	
	# Camera zoom - 3x zoom in
	camera.zoom = Vector2(3.0, 3.0)
	
	# Camera smoothing settings
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	
	# Add camera as child of player
	add_child(camera)
	camera.make_current()
	
	print("Player camera setup complete with 3x zoom")

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
	
	# Apply attack time penalty
	if main_game and main_game.has_method("apply_time_penalty"):
		main_game.apply_time_penalty("attack")
		print("Attack cost 5 seconds!")
	
	# Find and damage enemies in range
	var enemies = get_tree().get_nodes_in_group("enemies")
	var enemies_hit = 0
	
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			var distance = global_position.distance_to(enemy.global_position)
			if distance <= attack_range:
				print("Hit enemy at distance: ", distance)
				if enemy.has_method("take_damage"):
					enemy.take_damage(1)
					enemies_hit += 1
	
	if enemies_hit == 0:
		print("No enemies in range")

func special_action():
	print("Robot special action!")
	
	# Apply special action time penalty
	if main_game and main_game.has_method("apply_time_penalty"):
		main_game.apply_time_penalty("special")
		print("Special action cost 3 seconds!")

func take_hit(source: String):
	if is_invincible:
		return
	
	print("Robot takes hit from: ", source)
	
	# Apply hit penalty
	if main_game and main_game.has_method("apply_time_penalty"):
		main_game.apply_time_penalty("hit")
		print("Hit penalty - lost 5 seconds!")
	
	# Start invincibility
	is_invincible = true
	hit_timer.start()
	
	# Visual feedback
	_flash_red()

func _on_invincibility_end():
	is_invincible = false
	print("Invincibility ended")

func _flash_red():
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.4)

func _flip_sprite(direction: float):
	# FIXED sprite flipping - no more mirror glitch
	if animated_sprite:
		if direction > 0:
			animated_sprite.flip_h = false  # Face right
		elif direction < 0:
			animated_sprite.flip_h = true   # Face left

# Called by Game.gd when teleporting between rooms
func teleport_to_position(new_position: Vector2):
	global_position = new_position
	velocity = Vector2.ZERO  # Stop any movement
	if camera:
		camera.force_update_scroll()
	print("Player teleported to: ", new_position)

func reset_player_state():
	# Reset player state when entering new room
	velocity = Vector2.ZERO
	is_invincible = false
	
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE
		animated_sprite.flip_h = false  # Reset to facing right
	
	if hit_timer:
		hit_timer.stop()
	
	# Force camera to update position immediately
	if camera:
		camera.force_update_scroll()
		camera.position_smoothing_enabled = false
		await get_tree().process_frame
		camera.position_smoothing_enabled = true
	
	print("Player state reset for new room")
