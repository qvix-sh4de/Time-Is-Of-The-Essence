# enemy.gd
# Complete enemy AI with hide/show system for death and respawn
extends CharacterBody2D

@export var speed: float = 70.0
@export var health: int = 1
@export var attack_damage: float = 1.0
@export var attack_range: float = 50.0

var target: CharacterBody2D
var main_game: Node2D
var can_attack: bool = true
var attack_cooldown: float = 2.0
var starting_position: Vector2
var is_alive: bool = true  # Track if enemy is active

@onready var attack_timer = Timer.new()

func _ready():
	add_to_group("enemies")
	
	# Store starting position
	starting_position = global_position
	print("Enemy starting position stored: ", starting_position)
	
	# Find main game for enemy defeat reporting
	main_game = get_node("/root/Game")
	if not main_game:
		main_game = get_parent()
	
	# Auto-find player
	await get_tree().process_frame
	target = get_tree().get_first_node_in_group("player")
	
	if target:
		print("Enemy found player: ", target.name)
	else:
		print("ERROR: Enemy could not find player!")
	
	# Setup attack timer
	add_child(attack_timer)
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_ready)

func _physics_process(delta):
	# Don't do anything if dead/hidden
	if not is_alive:
		return
		
	if not target:
		return
	
	var distance_to_player = global_position.distance_to(target.global_position)
	
	# Attack if close enough
	if distance_to_player <= attack_range and can_attack:
		attack_player()
		return
	
	# Move toward player if too far
	if distance_to_player > attack_range:
		var direction = (target.global_position - global_position).normalized()
		velocity = direction * speed
		
		# Face the player without rotation glitches
		if has_node("Sprite2D"):
			var sprite = $Sprite2D
			if target.global_position.x > global_position.x:
				sprite.flip_h = false  # Face right
			else:
				sprite.flip_h = true   # Face left
		elif has_node("AnimatedSprite2D"):
			var sprite = $AnimatedSprite2D
			if target.global_position.x > global_position.x:
				sprite.flip_h = false  # Face right
			else:
				sprite.flip_h = true   # Face left
		
		move_and_slide()

func attack_player():
	# Don't attack if dead/hidden
	if not is_alive or not can_attack:
		return
	
	print("Enemy attacks player!")
	can_attack = false
	attack_timer.start()
	
	# Make player take hit
	if target.has_method("take_hit"):
		target.take_hit("enemy")

func take_damage(amount: int = 1):
	# Don't take damage if already dead/hidden
	if not is_alive:
		return
		
	health -= amount
	print("Enemy took damage! Health: ", health)
	
	# Visual feedback
	modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	
	if health <= 0:
		die()

func die():
	print("Enemy defeated!")
	
	# Report to main game
	if main_game and main_game.has_method("enemy_defeated"):
		main_game.enemy_defeated()
	
	# Hide enemy instead of destroying
	hide_enemy()

func hide_enemy():
	print("Enemy hiding...")
	is_alive = false
	visible = false
	
	# Stop all processing
	set_physics_process(false)
	set_process(false)
	
	# Clear velocity and move off-screen
	velocity = Vector2.ZERO
	global_position = Vector2(-1000, -1000)
	
	# Stop attack timer
	if attack_timer:
		attack_timer.stop()
	
	# Reset attack capability
	can_attack = true

func show_enemy():
	print("Enemy respawning...")
	is_alive = true
	visible = true
	
	# Resume processing
	set_physics_process(true)
	set_process(true)
	
	# Reset position and properties
	global_position = starting_position
	velocity = Vector2.ZERO
	health = 1
	can_attack = true
	modulate = Color.WHITE
	scale = Vector2.ONE
	
	# Reset sprite facing
	if has_node("Sprite2D"):
		$Sprite2D.flip_h = false
	elif has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.flip_h = false
	
	print("Enemy respawned at: ", starting_position)

func reset_to_start():
	# Always show and reset enemy when level restarts
	show_enemy()

func _on_attack_ready():
	# Only allow attacks if alive
	if is_alive:
		can_attack = true
