# Game.gd - Complete Final Game Manager with Working Teleportation
extends Node2D

var current_room: int = 1
var total_rooms: int = 20
var game_time: float = 600.0
var max_time: float = 600.0
var is_game_active: bool = false

var current_room_node: Node2D
var player: CharacterBody2D
var enemies_defeated_this_room: int = 0
var required_enemies_this_room: int = 0

var time_label: Label
var enemy_label: Label
var room_label: Label
var controls_label: Label
var battery_sprite: AnimatedSprite2D

var enemy_manager: Node

func _ready():
	if not GlobalVars.game_started:
		print("Game accessed without start menu - redirecting...")
		get_tree().change_scene_to_file("res://StartMenu.tscn")
		return
	
	setup_ui()
	setup_enemy_manager()
	start_game()

func setup_ui():
	var canvas = CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)
	
	time_label = Label.new()
	time_label.position = Vector2(50, 40)
	time_label.add_theme_font_size_override("font_size", 48)
	time_label.text = "Time: 10:00"
	canvas.add_child(time_label)
	
	enemy_label = Label.new()
	enemy_label.position = Vector2(50, 100)
	enemy_label.add_theme_font_size_override("font_size", 40)
	enemy_label.text = "Enemies: 0/0"
	canvas.add_child(enemy_label)
	
	controls_label = Label.new()
	controls_label.position = Vector2(50, 160)
	controls_label.add_theme_font_size_override("font_size", 28)
	controls_label.text = "F:Attack E:Shield G:Power R:Area"
	canvas.add_child(controls_label)
	
	room_label = Label.new()
	room_label.position = Vector2(600, 160)
	room_label.add_theme_font_size_override("font_size", 40)
	room_label.text = "Room: 1/20"
	canvas.add_child(room_label)
	
	battery_sprite = AnimatedSprite2D.new()
	battery_sprite.name = "BatterySprite"
	battery_sprite.position = Vector2(650, 80)
	battery_sprite.scale = Vector2(4, 4)
	canvas.add_child(battery_sprite)

func setup_enemy_manager():
	enemy_manager = Node.new()
	enemy_manager.name = "EnemyManager"
	add_child(enemy_manager)
	
	var enemy_manager_script = GDScript.new()
	enemy_manager_script.source_code = """
extends Node

signal all_enemies_defeated

var total_enemies: int = 0
var enemies_alive: int = 0

func count_enemies():
	var enemy_nodes = get_tree().get_nodes_in_group("enemies")
	total_enemies = enemy_nodes.size()
	enemies_alive = total_enemies
	
	for enemy in enemy_nodes:
		if enemy.has_signal("enemy_died"):
			if not enemy.enemy_died.is_connected(_on_enemy_died):
				enemy.connect("enemy_died", _on_enemy_died)

func _on_enemy_died():
	enemies_alive -= 1
	if enemies_alive <= 0:
		all_enemies_defeated.emit()

func are_all_enemies_dead():
	return enemies_alive <= 0
"""
	enemy_manager.set_script(enemy_manager_script)

func start_game():
	is_game_active = true
	current_room = 1
	game_time = max_time
	enemies_defeated_this_room = 0
	
	find_or_create_player()
	load_room(current_room)

func find_or_create_player():
	player = get_tree().get_first_node_in_group("player")
	if not player:
		print("No player found - game needs a Player scene in the scene tree")

func _process(delta):
	if is_game_active:
		game_time -= delta
		update_ui()
		
		if game_time <= 0:
			game_over()

func load_room(room_number: int):
	print("Loading room: ", room_number)
	
	if current_room_node:
		current_room_node.queue_free()
		await get_tree().process_frame
	
	current_room_node = Node2D.new()
	current_room_node.name = "Room" + str(room_number)
	add_child(current_room_node)
	
	var room_file = "res://Rooms/Room #" + str(room_number) + ".tscn"
	if ResourceLoader.exists(room_file):
		var room_scene = load(room_file)
		if room_scene:
			var room_instance = room_scene.instantiate()
			current_room_node.add_child(room_instance)
			count_enemies_in_room()
			setup_room_exit()
			await get_tree().process_frame
			reset_player_to_room_start()
			return
	
	create_fallback_room()

func create_fallback_room():
	var platform = StaticBody2D.new()
	platform.name = "Platform"
	platform.collision_layer = 2
	platform.collision_mask = 0
	platform.position = Vector2(0, 200)
	
	var platform_visual = ColorRect.new()
	platform_visual.color = Color.BROWN
	platform_visual.size = Vector2(800, 64)
	platform_visual.position = Vector2(-400, 0)
	
	var platform_collision = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(800, 64)
	platform_collision.shape = rect_shape
	
	platform.add_child(platform_visual)
	platform.add_child(platform_collision)
	current_room_node.add_child(platform)
	
	var spawn = Marker2D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector2(-300, 150)
	spawn.add_to_group("player_spawn")
	current_room_node.add_child(spawn)
	
	var exit = Area2D.new()
	exit.name = "RoomExit"
	exit.position = Vector2(300, 150)
	exit.add_to_group("room_exits")
	exit.collision_layer = 4
	exit.collision_mask = 1
	
	var exit_collision = CollisionShape2D.new()
	var exit_rect = RectangleShape2D.new()
	exit_rect.size = Vector2(64, 128)
	exit_collision.shape = exit_rect
	exit.add_child(exit_collision)
	current_room_node.add_child(exit)
	
	required_enemies_this_room = 0
	setup_room_exit()
	await get_tree().process_frame
	reset_player_to_room_start()

func count_enemies_in_room():
	var custom_enemy_requirements = {
		1: 3, 2: 3, 3: 4, 4: 5, 5: 6,
		6: 6, 7: 7, 8: 8, 9: 3, 10: 8,
		11: 8, 12: 10, 13: 10, 14: 5, 15: 10,
		16: 10, 17: 10, 18: 15, 19: 15, 20: 15
	}
	
	required_enemies_this_room = custom_enemy_requirements.get(current_room, 3)
	enemies_defeated_this_room = 0
	
	var actual_enemies = 0
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if current_room_node.is_ancestor_of(enemy):
			actual_enemies += 1
	
	if actual_enemies > 0 and actual_enemies < required_enemies_this_room:
		required_enemies_this_room = actual_enemies
	
	if enemy_manager and enemy_manager.has_method("count_enemies"):
		enemy_manager.count_enemies()

func setup_room_exit():
	var exits = get_tree().get_nodes_in_group("room_exits")
	for exit in exits:
		if current_room_node.is_ancestor_of(exit) and exit is Area2D:
			if not exit.body_entered.is_connected(_on_room_exit_entered):
				exit.body_entered.connect(_on_room_exit_entered)

func reset_player_to_room_start():
	var spawn_points = get_tree().get_nodes_in_group("player_spawn")
	player = get_tree().get_first_node_in_group("player")
	
	print("=== PLAYER TELEPORT DEBUG ===")
	print("Spawn points found: ", spawn_points.size())
	print("Player found: ", player != null)
	
	if player and spawn_points.size() > 0:
		var spawn_pos = spawn_points[0].global_position
		print("Teleporting player to spawn: ", spawn_pos)
		
		if player.has_method("teleport_to_position"):
			await player.teleport_to_position(spawn_pos)
		else:
			player.global_position = spawn_pos
			if player.has_property("velocity"):
				player.velocity = Vector2.ZERO
		
		if player.has_method("reset_player_state"):
			await player.reset_player_state()
		
		print("Player final position: ", player.global_position)
	else:
		print("ERROR: Missing spawn point or player!")
	print("=============================")

func _on_room_exit_entered(body):
	if not body.is_in_group("player"):
		return
	
	if not all_enemies_defeated():
		print("Cannot exit room - enemies remaining!")
		return
	
	print("Player reached exit with all enemies defeated!")
	advance_to_next_room()

func advance_to_next_room():
	current_room += 1
	
	if current_room > total_rooms:
		game_complete()
		return
	
	enemies_defeated_this_room = 0
	load_room(current_room)

func all_enemies_defeated():
	return enemies_defeated_this_room >= required_enemies_this_room

func on_enemy_defeated():
	enemies_defeated_this_room += 1
	print("Enemy defeated! Progress: ", enemies_defeated_this_room, "/", required_enemies_this_room)
	
	if all_enemies_defeated():
		print("All enemies in room defeated! Exit unlocked!")

func apply_time_penalty(penalty_type: String):
	if not is_game_active:
		return
	
	var penalty_amount = 0
	match penalty_type:
		"hit":
			penalty_amount = 5
		"attack":
			penalty_amount = 5
		"shield":
			penalty_amount = 10
		"powerup":
			penalty_amount = 5
		"area_attack":
			penalty_amount = 15
		"special":
			penalty_amount = 3
	
	game_time = max(0, game_time - penalty_amount)
	
	flash_timer_red()
	
	if game_time <= 0:
		game_over()
	
	update_ui()

func is_ability_available(ability_type: String) -> bool:
	var battery_percent = game_time / max_time
	
	match ability_type:
		"attack":
			return battery_percent > 0.10
		"shield": 
			return battery_percent > 0.25
		"powerup":
			return battery_percent > 0.50
		"area_attack":
			return battery_percent > 0.10
		_:
			return true

func update_ui():
	var minutes = int(game_time) / 60
	var seconds = int(game_time) % 60
	time_label.text = "Time: %02d:%02d" % [minutes, seconds]
	
	room_label.text = "Room: %d/20" % current_room
	enemy_label.text = "Enemies: %d/%d" % [enemies_defeated_this_room, required_enemies_this_room]
	
	update_battery_animation(game_time / max_time)

func update_battery_animation(time_percentage: float):
	if not battery_sprite or not battery_sprite.sprite_frames:
		return
	
	if not battery_sprite.sprite_frames.has_animation("battery_drain"):
		return
	
	var total_frames = battery_sprite.sprite_frames.get_frame_count("battery_drain")
	if total_frames == 0:
		return
	
	var frame_index = int((1.0 - time_percentage) * (total_frames - 1))
	frame_index = clamp(frame_index, 0, total_frames - 1)
	
	if battery_sprite.animation != "battery_drain":
		battery_sprite.play("battery_drain")
	
	battery_sprite.pause()
	battery_sprite.frame = frame_index

func flash_timer_red():
	if time_label:
		var tween = create_tween()
		tween.tween_property(time_label, "modulate", Color.RED, 0.1)
		tween.tween_property(time_label, "modulate", Color.WHITE, 0.3)

func game_over():
	is_game_active = false
	print("GAME OVER! Time ran out")
	
	GlobalVars.game_started = false
	
	if time_label:
		time_label.text = "GAME OVER!"
	if enemy_label:
		enemy_label.text = "TIME'S UP!"
	
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://StartMenu.tscn")

func game_complete():
	is_game_active = false
	print("MISSION COMPLETE! Player reached Room 21!")
	
	GlobalVars.game_started = false
	
	if time_label:
		time_label.text = "MISSION COMPLETE!"
	if enemy_label:
		enemy_label.text = "MASTER RESCUED!"
	if room_label:
		room_label.text = "HERO!"
	
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://StartMenu.tscn")
