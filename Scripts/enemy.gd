extends CharacterBody2D

signal enemy_died

@export var speed: float = 70.0
@export var health: int = 1
@export var attack_range: float = 50.0
@export var attack_damage: int = 1

var target: CharacterBody2D
var main_game: Node2D
var attack_cooldown: float = 0.0
var attack_cooldown_time: float = 2.0

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D

func _ready():
	add_to_group("enemies")
	
	collision_layer = 5
	collision_mask = 1
	
	main_game = get_node("/root/Game")
	if not main_game:
		main_game = get_tree().get_first_node_in_group("game")
	
	await get_tree().process_frame
	target = get_tree().get_first_node_in_group("player")
	
	if sprite:
		sprite.modulate = Color.WHITE

func _physics_process(delta):
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	if not target:
		target = get_tree().get_first_node_in_group("player")
		return
	
	var distance_to_player = global_position.distance_to(target.global_position)
	
	if distance_to_player <= attack_range and attack_cooldown <= 0:
		attack_player()
		attack_cooldown = attack_cooldown_time
	else:
		chase_player(delta)

func chase_player(delta: float):
	if not target:
		return
	
	var direction = (target.global_position - global_position).normalized()
	velocity = direction * speed
	
	if target.global_position.x > global_position.x:
		if sprite:
			sprite.flip_h = false
	else:
		if sprite:
			sprite.flip_h = true
	
	move_and_slide()

func attack_player():
	if not target:
		return
	
	if target.has_method("take_hit"):
		target.take_hit("enemy")
	
	flash_white()

func take_damage(amount: int = 1):
	health -= amount
	flash_red()
	
	if health <= 0:
		die()

func die():
	enemy_died.emit()
	
	if main_game and main_game.has_method("on_enemy_defeated"):
		main_game.on_enemy_defeated()
	
	death_effect()
	queue_free()

func flash_white():
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func flash_red():
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)

func death_effect():
	if sprite:
		var tween = create_tween()
		tween.parallel().tween_property(sprite, "scale", Vector2.ZERO, 0.3)
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)
