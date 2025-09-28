# SimplifiedRobotPlayer.gd
# This version works with your existing attack animation script
extends CharacterBody2D

# Movement settings
@export var speed: float = 200.0
@export var jump_velocity: float = -300.0
@export var acceleration: float = 800.0
@export var friction: float = 1000.0

# Combat settings
var is_invincible: bool = false
var invincibility_time: float = 1.0

# Node references
@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var hit_timer = Timer.new()

# Reference to main game
var main_game: Node2D

func _ready():
	add_to_group("player")
	
	# Try multiple ways to find the main game node
	print("🔍 Searching for main game node...")
	
	# Method 1: Direct path
	if get_node_or_null("/root/Main"):
		main_game = get_node("/root/Main")
		print("✅ Found main game at /root/Main")
	
	# Method 2: Parent node
	elif get_parent():
		main_game = get_parent()
		print("✅ Found main game as parent: ", main_game.name)
	
	# Method 3: Look for node with apply_time_penalty method
	else:
		var current_node = self
		while current_node.get_parent():
			current_node = current_node.get_parent()
			if current_node.has_method("apply_time_penalty"):
				main_game = current_node
				print("✅ Found main game with apply_time_penalty: ", current_node.name)
				break
	
	# Final check
	if not main_game:
		print("❌ Could not find main game node")
	else:
		print("✅ Main game connected: ", main_game.name)
	
	# Setup invincibility timer
	add_child(hit_timer)
	hit_timer.wait_time = invincibility_time
	hit_timer.one_shot = true
	hit_timer.timeout.connect(_on_invincibility_end)
	
	# Debug: Check what's on the AnimatedSprite2D
	print("🤖 Robot player ready!")
	print("🔍 Checking AnimatedSprite2D setup...")
	if animated_sprite:
		print("  - AnimatedSprite2D found: ", animated_sprite.name)
		print("  - Available animations: ", animated_sprite.sprite_frames.get_animation_names() if animated_sprite.sprite_frames else "No sprite frames")
		
		# Check if player_animation.gd script is attached
		var script_on_sprite = animated_sprite.get_script()
		if script_on_sprite:
			print("  - Script attached to AnimatedSprite2D: ", script_on_sprite.resource_path)
		else:
			print("  - No script on AnimatedSprite2D")
	else:
		print("  - ❌ AnimatedSprite2D not found!")

func _physics_process(delta):
	# Handle gravity
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	
	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
		print("🚀 Robot jumps!")
	
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
				attack()  # Handle F key for attack
			KEY_E:
				special_action()
			KEY_H:
				# Test hit function
				take_hit("test")
				print("🧪 Testing robot hit function!")
			KEY_T:
				# Test connection to main game
				test_main_connection()

func attack():
	print("⚔️ Robot attacks!")
	
	# Apply time penalty for attacking (optional - you can adjust this)
	if main_game and main_game.has_method("apply_time_penalty"):
		main_game.apply_time_penalty("hit")  # Use "hit" penalty (5 seconds)
		print("⏰ Attack cost time penalty!")
	
	# Trigger your existing attack animation
	var animation_node = animated_sprite
	
	# Method 1: If your player_animation.gd has a trigger_attack function
	if animation_node.has_method("trigger_attack"):
		animation_node.trigger_attack()
		print("✅ Triggered attack via trigger_attack()")
	
	# Method 2: If your player_animation.gd responds to signals
	elif animation_node.has_signal("attack_requested"):
		animation_node.emit_signal("attack_requested")
		print("✅ Triggered attack via signal")
	
	# Method 3: Try to play attack animation directly
	elif animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("attack"):
		animated_sprite.play("attack")
		print("✅ Playing attack animation directly")
	
	# Method 4: If none of the above work, we'll need to check your script
	else:
		print("❌ Could not trigger attack animation - need to check player_animation.gd")
		# Let's see what methods are available
		print("Available methods on AnimatedSprite2D:")
		var methods = animation_node.get_method_list()
		for method in methods:
			if "attack" in method.name.to_lower():
				print("  - ", method.name)

func special_action():
	print("⚡ Robot special action!")
	
	# Apply time penalty to main game
	if main_game and main_game.has_method("apply_time_penalty"):
		main_game.apply_time_penalty("special")
		print("🔋 Special action used - time penalty applied!")
	else:
		print("❌ Main game not found or no apply_time_penalty method")

func take_hit(damage_source: String = "enemy"):
	if is_invincible:
		return
	
	print("💢 Robot takes hit from: ", damage_source)
	
	# Apply time penalty to main game
	if main_game and main_game.has_method("apply_time_penalty"):
		main_game.apply_time_penalty("hit")
		print("🕐 Hit penalty applied to timer!")
	else:
		print("❌ Main game not found or no apply_time_penalty method")
	
	# Start invincibility
	is_invincible = true
	hit_timer.start()
	
	# Visual feedback
	_show_hit_effect()

func _show_hit_effect():
	# Flash red
	animated_sprite.modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)

func _flip_sprite(direction: float):
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true

func _on_invincibility_end():
	is_invincible = false
	print("🛡️ Robot invincibility ended")

func test_main_connection():
	print("🔍 Testing connection to main game...")
	print("Main game reference: ", main_game)
	if main_game:
		print("✅ Main game found!")
		if main_game.has_method("apply_time_penalty"):
			print("✅ apply_time_penalty method exists!")
		else:
			print("❌ apply_time_penalty method NOT found!")
	else:
		print("❌ Main game reference is null!")
