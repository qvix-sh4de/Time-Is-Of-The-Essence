# enemy.gd - Complete Fixed Enemy Script
extends CharacterBody2D

signal enemy_died

# Enemy stats
@export var speed: float = 70.0
@export var health: int = 1  # Dies in one hit
@export var attack_range: float = 50.0
@export var attack_damage: int = 1

# AI behavior
var target: CharacterBody2D
var main_game: Node2D
var attack_cooldown: float = 0.0
var attack_cooldown_time: float = 2.0  # FIXED: Proper 2-second cooldown

# References
@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D

func _ready():
	add_to_group("enemies")
	
	# FIXED: Enemies on layer 5 to prevent pushing player
	collision_layer = 5  # Enemies on layer 5 (as requested)
	collision_mask = 1   # Enemies collide with platforms on layer 1
	
	# Find main game reference
	main_game = get_node("/root/Game")
	if not main_game:
		main_game = get_tree().get_first_node_in_group("game")
	
	# Find player target
	await get_tree().process_frame  # Wait one frame for everything to load
	target = get_tree().get_first_node_in_group("player")
	
	if target:
		print("Enemy ready, targeting: ", target.name)
	else:
		print("Enemy warning: No player found!")
	
	# Set up visual appearance if sprite exists
	if sprite:
		sprite.modulate = Color.WHITE  # FIXED: Start with normal color, not red
		# Load your enemy texture here: sprite.texture = load("res://enemy_sprite.png")

func _physics_process(delta):
	# FIXED: Proper attack cooldown timing
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	# Find target if we don't have one
	if not target:
		target = get_tree().get_first_node_in_group("player")
		return
	
	# Calculate distance to player
	var distance_to_player = global_position.distance_to(target.global_position)
	
	# Attack if in range and cooldown is ready
	if distance_to_player <= attack_range and attack_cooldown <= 0:
		attack_player()
		attack_cooldown = attack_cooldown_time  # Reset cooldown
	else:
		# Move toward player
		chase_player(delta)

func chase_player(delta: float):
	if not target:
		return
	
	# Calculate direction to player
	var direction = (target.global_position - global_position).normalized()
	
	# Set velocity and move
	velocity = direction * speed
	
	# FIXED: Proper sprite flipping (no scale manipulation)
	if target.global_position.x > global_position.x:
		if sprite:
			sprite.flip_h = false  # Face right
	else:
		if sprite:
			sprite.flip_h = true   # Face left
	
	# Apply movement
	move_and_slide()

func attack_player():
	if not target:
		return
	
	print("Enemy attacks player!")
	
	# Call take_hit on player
	if target.has_method("take_hit"):
		target.take_hit("enemy")
	
	# Visual feedback for attack
	flash_white()

func take_damage(amount: int = 1):
	health -= amount
	print("Enemy takes ", amount, " damage! Health remaining: ", health)
	
	# Visual feedback for taking damage
	flash_red()
	
	if health <= 0:
		die()

func die():
	print("Enemy defeated!")
	
	# Emit death signal for enemy manager
	enemy_died.emit()
	
	# Report death to main game
	if main_game and main_game.has_method("on_enemy_defeated"):
		main_game.on_enemy_defeated()
	
	# Death effect
	death_effect()
	
	# Remove enemy
	queue_free()

func flash_white():
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)  # Return to normal white

func flash_red():
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)  # Return to normal white

func death_effect():
	# Simple death effect - scale down and fade
	if sprite:
		var tween = create_tween()
		tween.parallel().tween_property(sprite, "scale", Vector2.ZERO, 0.3)
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)
