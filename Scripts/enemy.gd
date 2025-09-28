# enemy.gd
# Complete enemy AI with player tracking, combat, and game integration
extends CharacterBody2D

@export var speed: float = 70.0
@export var health: int = 1
@export var attack_damage: float = 1.0
@export var attack_range: float = 50.0

var target: CharacterBody2D
var main_game: Node2D
var can_attack: bool = true
var attack_cooldown: float = 2.0

@onready var attack_timer = Timer.new()

func _ready():
	add_to_group("enemies")
	
	# Find main game for enemy defeat reporting
	main_game = get_node("/root/Game")
	if not main_game:
		main_game = get_parent()
	
	# Auto-find player
	await get_tree().process_frame  # Wait one frame for everything to load
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
		
		# Face the player WITHOUT using look_at() or scale flipping
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
	if not can_attack:
		return
	
	print("Enemy attacks player!")
	can_attack = false
	attack_timer.start()
	
	# Make player take hit
	if target.has_method("take_hit"):
		target.take_hit("enemy")

func take_damage(amount: int = 1):
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
	
	# Death effect
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
	tween.tween_callback(queue_free)

func _on_attack_ready():
	can_attack = true
