# player.gd - Complete Player Script with New Combat System
extends CharacterBody2D

# Movement settings
@export var speed: float = 200.0
@export var jump_velocity: float = -300.0
@export var acceleration: float = 800.0
@export var friction: float = 1000.0

# Combat settings  
@export var attack_range: float = 50.0  # Same as enemy attack range
var is_invincible: bool = false
var invincibility_time: float = 1.0
var attack_cooldown: float = 0.0
var attack_cooldown_time: float = 2.0  # 2 second attack cooldown
var shield_active: bool = false
var shield_time_remaining: float = 0.0
var next_attack_multiplier: int = 1  # For G ability (3x damage)

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
	
	# Set collision layers
	collision_layer = 1  # Player is on layer 1  
	collision_mask = 1   # Player only collides with layer 1 (platforms), NOT layer 5 (enemies)
	
	print("Robot player ready with new combat system!")

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
	# Update cooldowns
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	if shield_time_remaining > 0:
		shield_time_remaining -= delta
		if shield_time_remaining <= 0:
			shield_active = false
			print("🛡️ Shield deactivated")
			# Reset sprite color when shield ends
			if animated_sprite:
				animated_sprite.modulate = Color.WHITE
	
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
			KEY_E:
				activate_shield()
			KEY_G:
				power_up_next_attack()
			KEY_A:
				area_attack()

func attack():
	# Check if attack ability is available (battery > 10%)
	if main_game and main_game.has_method("is_ability_available"):
		if not main_game.is_ability_available("attack"):
			print("❌ Attack disabled - battery too low (need >10%)")
			return
	
	# Check attack cooldown
	if attack_cooldown > 0:
		print("Attack on cooldown! Wait %.1f seconds" % attack_cooldown)
		return
	
	print("Robot attacks!")
	
	# Apply attack time penalty
	if main_game and main_game.has_method("apply_time_penalty"):
		main_game.apply_time_penalty("attack")
		print("Attack cost 5 seconds!")
	
	# Start attack cooldown
	attack_cooldown = attack_cooldown_time
	
	# Find and damage ONE enemy in range (closest first)
	var enemies = get_tree().get_nodes_in_group("enemies")
	var enemies_in_range = []
	
	# Collect all enemies in range
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			var distance = global_position.distance_to(enemy.global_position)
			if distance <= attack_range:
				enemies_in_range.append({"enemy": enemy, "distance": distance})
	
	if enemies_in_range.size() == 0:
		print("No enemies in range")
		return
	
	# Sort by distance (closest first)
	enemies_in_range.sort_custom(func(a, b): return a.distance < b.distance)
	
	# Attack only the closest enemy
	var target_enemy = enemies_in_range[0].enemy
	var damage = next_attack_multiplier  # Use multiplier for damage
	
	print("Hit closest enemy at distance: %.1f with %dx damage" % [enemies_in_range[0].distance, damage])
	
	if target_enemy.has_method("take_damage"):
		target_enemy.take_damage(damage)
	
	# Reset attack multiplier after use
	if next_attack_multiplier > 1:
		print("💥 Power attack used! (%dx damage)" % next_attack_multiplier)
		next_attack_multiplier = 1
	
	# Attack visual effect
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)

func activate_shield():
	# Check if shield ability is available (battery > 25%)
	if main_game and main_game.has_method("is_ability_available"):
		if not main_game.is_ability_available("shield"):
			print("❌ Shield disabled - battery too low (need >25%)")
			return
	
	print("🛡️ Robot activates energy shield!")
	
	# Apply shield time penalty (10 seconds)
	if main_game and main_game.has_method("apply_time_penalty"):
		main_game.apply_time_penalty("shield")
		print("Shield cost 10 seconds!")
	
	# Activate shield for 5 seconds
	shield_active = true
	shield_time_remaining = 5.0
	print("🛡️ Shield active for 5 seconds - immune to damage!")
	
	# Visual effect - cyan glow while shield is active
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.CYAN, 0.3)

func area_attack():
	# Check if area attack ability is available (battery > 10%)
	if main_game and main_game.has_method("is_ability_available"):
		if not main_game.is_ability_available("area_attack"):
			print("❌ Area attack disabled - battery too low (need >10%)")
			return
	
	# Check attack cooldown
	if attack_cooldown > 0:
		print("Area attack on cooldown! Wait %.1f seconds" % attack_cooldown)
		return
	
	print("💥 Robot unleashes AREA ATTACK!")
	
	# Apply area attack time penalty (15 seconds)
	if main_game and main_game.has_method("apply_time_penalty"):
		main_game.apply_time_penalty("area_attack")
		print("Area attack cost 15 seconds!")
	
	# Start attack cooldown
	attack_cooldown = attack_cooldown_time
	
	# Find ALL enemies within 100 pixels
	var enemies = get_tree().get_nodes_in_group("enemies")
	var enemies_hit = 0
	var area_range = 100.0
	
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			var distance = global_position.distance_to(enemy.global_position)
			if distance <= area_range:
				print("Area attack hit enemy at distance: %.1f" % distance)
				if enemy.has_method("take_damage"):
					enemy.take_damage(1)  # Always 1 HP damage
					enemies_hit += 1
	
	if enemies_hit == 0:
		print("No enemies in area attack range (100px)")
	else:
		print("💥 Area attack hit %d enemies!" % enemies_hit)
	
	# Dramatic visual effect for area attack
	if animated_sprite:
		var tween = create_tween()
		# Flash bright white then fade to normal
		tween.tween_property(animated_sprite, "modulate", Color.WHITE * 2.0, 0.1)
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)

func power_up_next_attack():
	# Check if power-up ability is available (battery > 50%)
	if main_game and main_game.has_method("is_ability_available"):
		if not main_game.is_ability_available("powerup"):
			print("❌ Power-up disabled - battery too low (need >50%)")
			return
	
	print("⚡ Robot charges up next attack!")
	
	# Apply power-up time penalty (5 seconds)
	if main_game and main_game.has_method("apply_time_penalty"):
		main_game.apply_time_penalty("powerup")
		print("Power-up cost 5 seconds!")
	
	# Set next attack to do 3x damage
	next_attack_multiplier = 3
	print("💪 Next attack will do 3x damage!")
	
	# Visual effect - yellow flash
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.YELLOW, 0.2)
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)

func take_hit(source: String):
	# Check if shield is active
	if shield_active:
		print("🛡️ Shield blocked attack from: %s" % source)
		# Visual shield effect
		if animated_sprite:
			var tween = create_tween()
			tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.1)
			tween.tween_property(animated_sprite, "modulate", Color.CYAN, 0.1)
		return
	
	if is_invincible:
		return
	
	print("Robot takes hit from: %s" % source)
	
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
	# Sprite flipping - no more mirror glitch
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
	print("Player teleported to: %s" % new_position)

func reset_player_state():
	# Reset player state when entering new room
	velocity = Vector2.ZERO
	is_invincible = false
	attack_cooldown = 0.0
	shield_active = false
	shield_time_remaining = 0.0
	next_attack_multiplier = 1
	
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

# Legacy function for compatibility
func special_action():
	print("Robot special action!")
	if main_game and main_game.has_method("apply_time_penalty"):
		main_game.apply_time_penalty("special")
		print("Special action cost 3 seconds!")
