extends CharacterBody2D

@export var speed: float = 200.0
@export var jump_velocity: float = -300.0
@export var acceleration: float = 800.0
@export var friction: float = 1000.0
@export var attack_range: float = 50.0

var is_invincible: bool = false
var invincibility_time: float = 1.0
var attack_cooldown: float = 0.0
var attack_cooldown_time: float = 2.0
var shield_active: bool = false
var shield_time_remaining: float = 0.0
var next_attack_multiplier: int = 1

var camera: Camera2D
var main_game: Node2D
@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var hit_timer = Timer.new()

func _ready():
	add_to_group("player")
	setup_camera()
	main_game = get_node("/root/Game")
	if not main_game:
		main_game = get_parent()
	
	add_child(hit_timer)
	hit_timer.wait_time = invincibility_time
	hit_timer.one_shot = true
	hit_timer.timeout.connect(_on_invincibility_end)
	
	collision_layer = 1
	collision_mask = 1

func setup_camera():
	camera = Camera2D.new()
	camera.name = "PlayerCamera"
	camera.enabled = true
	camera.zoom = Vector2(3.0, 3.0)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	add_child(camera)
	camera.make_current()

func _physics_process(delta):
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	if shield_time_remaining > 0:
		shield_time_remaining -= delta
		if shield_time_remaining <= 0:
			shield_active = false
			if animated_sprite:
				animated_sprite.modulate = Color.WHITE
	
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

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
			KEY_R:
				area_attack()

func attack():
	if attack_cooldown > 0:
		return
	
	if main_game and main_game.has_method("apply_time_penalty"):
		main_game.apply_time_penalty("attack")
	
	attack_cooldown = attack_cooldown_time
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	var enemies_in_range = []
	
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			var distance = global_position.distance_to(enemy.global_position)
			if distance <= attack_range:
				enemies_in_range.append({"enemy": enemy, "distance": distance})
	
	if enemies_in_range.size() == 0:
		return
	
	enemies_in_range.sort_custom(func(a, b): return a.distance < b.distance)
	
	var target_enemy = enemies_in_range[0].enemy
	var damage = next_attack_multiplier
	
	if target_enemy.has_method("take_damage"):
		target_enemy.take_damage(damage)
	
	if next_attack_multiplier > 1:
		next_attack_multiplier = 1
	
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)

func activate_shield():
	if main_game and main_game.has_method("is_ability_available"):
		if not main_game.is_ability_available("shield"):
			return
	
	if main_game and main_game.has_method("apply_time_penalty"):
		main_game.apply_time_penalty("shield")
	
	shield_active = true
	shield_time_remaining = 5.0
	
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.CYAN, 0.3)

func power_up_next_attack():
	if main_game and main_game.has_method("is_ability_available"):
		if not main_game.is_ability_available("powerup"):
			return
	
	if main_game and main_game.has_method("apply_time_penalty"):
		main_game.apply_time_penalty("powerup")
	
	next_attack_multiplier = 3
	
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.YELLOW, 0.2)
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)

func area_attack():
	if main_game and main_game.has_method("is_ability_available"):
		if not main_game.is_ability_available("area_attack"):
			return
	
	if attack_cooldown > 0:
		return
	
	if main_game and main_game.has_method("apply_time_penalty"):
		main_game.apply_time_penalty("area_attack")
	
	attack_cooldown = attack_cooldown_time
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	var area_range = 100.0
	
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			var distance = global_position.distance_to(enemy.global_position)
			if distance <= area_range:
				if enemy.has_method("take_damage"):
					enemy.take_damage(1)
	
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.WHITE * 2.0, 0.1)
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.3)

func take_hit(source: String):
	if shield_active:
		if animated_sprite:
			var tween = create_tween()
			tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.1)
			tween.tween_property(animated_sprite, "modulate", Color.CYAN, 0.1)
		return
	
	if is_invincible:
		return
	
	if main_game and main_game.has_method("apply_time_penalty"):
		main_game.apply_time_penalty("hit")
	
	is_invincible = true
	hit_timer.start()
	_flash_red()

func _on_invincibility_end():
	is_invincible = false

func _flash_red():
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.4)

func _flip_sprite(direction: float):
	if animated_sprite:
		if direction > 0:
			animated_sprite.flip_h = false
		elif direction < 0:
			animated_sprite.flip_h = true

func teleport_to_position(new_position: Vector2):
	global_position = new_position
	velocity = Vector2.ZERO
	if camera:
		camera.force_update_scroll()

func reset_player_state():
	velocity = Vector2.ZERO
	is_invincible = false
	attack_cooldown = 0.0
	shield_active = false
	shield_time_remaining = 0.0
	next_attack_multiplier = 1
	
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE
		animated_sprite.flip_h = false
	
	if hit_timer:
		hit_timer.stop()
	
	if camera:
		camera.force_update_scroll()
		camera.position_smoothing_enabled = false
		await get_tree().process_frame
		camera.position_smoothing_enabled = true

func special_action():
	if main_game and main_game.has_method("apply_time_penalty"):
		main_game.apply_time_penalty("special")
