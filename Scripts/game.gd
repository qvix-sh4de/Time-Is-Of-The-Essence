# Game.gd - Complete Fixed Game Manager (Clean Rewrite)
extends Node2D

# Game state
var current_room: int = 1
var total_rooms: int = 21
var game_time: float = 120.0
var max_time: float = 120.0
var is_game_active: bool = false

# Room management
var current_room_node: Node2D
var player: CharacterBody2D
var enemies_defeated_this_room: int = 0
var required_enemies_this_room: int = 0

# UI elements
var time_label: Label
var enemy_label: Label
var room_label: Label
var battery_sprite: AnimatedSprite2D

# Enemy manager
var enemy_manager: Node

func _ready():
	setup_ui()
	setup_enemy_manager()
	start_game()

func setup_ui():
	var canvas = CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)
	
	time_label = Label.new()
	time_label.position = Vector2(20, 20)
	time_label.add_theme_font_size_override("font_size", 24)
	time_label.text = "Time: 02:00"
	canvas.add_child(time_label)
	
	enemy_label = Label.new()
	enemy_label.position = Vector2(20, 50)
	enemy_label.add_theme_font_size_override("font_size", 20)
	enemy_label.text = "Enemies: 0/0"
	canvas.add_child(enemy_label)
	
	room_label = Label.new()
	room_label.position = Vector2(20, 80)
	room_label.add_theme_font_size_override("font_size", 20)
	room_label.text = "Room: 1/21"
	canvas.add_child(room_label)
	
	battery_sprite = AnimatedSprite2D.new()
	battery_sprite.name = "BatterySprite"
	battery_sprite.position = Vector2(300, 50)
	battery_sprite.scale = Vector2(2, 2)
	canvas.add_child(battery_sprite)

func setup_enemy_manager():
	enemy_manager = Node.new()
	enemy_manager.name = "EnemyManager"
	add_child(enemy_manager)
	
	var script_text = """
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
			enemy.connect("enemy_died", _on_enemy_died)

func _on_enemy_died():
	enemies_alive -= 1
	print("Enemy died! Remaining: ", enemies_alive)
	
	if enemies_alive <= 0:
		print("All enemies defeated!")
		all_enemies_defeated.emit()

func are_all_enemies_dead() -> bool:
	return enemies_alive <= 0
"""
	var enemy_script = GDScript.new()
	enemy_script.source_code = script_text
	enemy_manager.set_script(enemy_script)

func start_game():
	is_game_active = true
	current_room = 1
	game_time = max_time
	enemies_defeated_this_room = 0
	
	player = get_tree().get_first_node_in_group("player")
	if not player:
		print("ERROR: No player found!")
		return
	
	load_room(current_room)
	print("Game started! Room 1 loaded.")

func load_room(room_number: int):
	print("Loading Room #", room_number)
	
	if current_room_node:
		current_room_node.queue_free()
		await get_tree().process_frame
	
	var room_scene_path = "res://Rooms/Room #%d.tscn" % room_number
	
	if not ResourceLoader.exists(room_scene_path):
		print("ERROR: Room scene not found: ", room_scene_path)
		create_simple_fallback_room()
		return
	
	var room_scene = load(room_scene_path)
	current_room_node = room_scene.instantiate()
	current_room_node.name = "CurrentRoom"
	add_child(current_room_node)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	count_enemies_in_room()
	setup_room_exit()
	reset_player_to_room_start()
	update_ui()
	
	print("Room ", room_number, " loaded with ", required_enemies_this_room, " enemies")

func create_simple_fallback_room():
	print("Creating simple fallback room")
	
	current_room_node = Node2D.new()
	current_room_node.name = "FallbackRoom"
	add_child(current_room_node)
	
	var platform = StaticBody2D.new()
	platform.collision_layer = 1
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
	reset_player_to_room_start()

func count_enemies_in_room():
	var enemies = get_tree().get_nodes_in_group("enemies")
	required_enemies_this_room = 0
	enemies_defeated_this_room = 0
	
	for enemy in enemies:
		if current_room_node.is_ancestor_of(enemy):
			required_enemies_this_room += 1
	
	if enemy_manager and enemy_manager.has_method("count_enemies"):
		enemy_manager.count_enemies()
	
	print("Found ", required_enemies_this_room, " enemies in room")

func setup_room_exit():
	var exits = get_tree().get_nodes_in_group("room_exits")
	for exit in exits:
		if current_room_node.is_ancestor_of(exit) and exit is Area2D:
			if not exit.body_entered.is_connected(_on_room_exit_entered):
				exit.body_entered.connect(_on_room_exit_entered)
			print("Connected to room exit")

func reset_player_to_room_start():
	var spawn_points = get_tree().get_nodes_in_group("player_spawn")
	
	print("=== PLAYER SPAWN DEBUG ===")
	print("Spawn points found: ", spawn_points.size())
	print("Player found: ", player != null)
	
	if player and spawn_points.size() > 0:
		var spawn_pos = spawn_points[0].global_position
		print("Teleporting player to: ", spawn_pos)
		
		if player.has_method("teleport_to_position"):
			player.teleport_to_position(spawn_pos)
		else:
			player.global_position = spawn_pos
			player.velocity = Vector2.ZERO
		
		if player.has_method("reset_player_state"):
			player.reset_player_state()
		
		print("Player positioned at: ", player.global_position)
	else:
		print("ERROR: Missing spawn point or player!")
	print("=========================")

func _on_room_exit_entered(body):
	if not body.is_in_group("player"):
		return
	
	if not all_enemies_defeated():
		print("Cannot exit room - ", get_remaining_enemy_count(), " enemies remaining!")
		flash_enemy_counter()
		return
	
	print("Player reached exit with all enemies defeated!")
	advance_to_next_room()

func get_remaining_enemy_count() -> int:
	var remaining = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if current_room_node.is_ancestor_of(enemy):
			remaining += 1
	return remaining

func all_enemies_defeated() -> bool:
	return get_remaining_enemy_count() == 0

func on_enemy_defeated():
	enemies_defeated_this_room += 1
	var remaining = get_remaining_enemy_count()
	print("Enemy defeated! Enemies remaining: ", remaining)
	
	if all_enemies_defeated():
		print("🎉 All enemies defeated! Room exit unlocked!")
		flash_success_message()
	
	update_ui()

func flash_enemy_counter():
	if enemy_label:
		var tween = create_tween()
		tween.tween_property(enemy_label, "modulate", Color.RED, 0.2)
		tween.tween_property(enemy_label, "modulate", Color.WHITE, 0.3)

func flash_success_message():
	if enemy_label:
		var tween = create_tween()
		tween.tween_property(enemy_label, "modulate", Color.GREEN, 0.2)
		tween.tween_property(enemy_label, "modulate", Color.WHITE, 0.5)

func advance_to_next_room():
	if current_room >= total_rooms:
		complete_game()
		return
	
	current_room += 1
	
	if current_room == 21:
		print("🎬 Loading final cutscene room...")
		game_time = 999.0
		load_cutscene_room()
	else:
		game_time = max_time
		print("🏃 Advancing to room ", current_room)
		load_room(current_room)

func load_cutscene_room():
	print("Loading Cutscene Room #21")
	
	if current_room_node:
		current_room_node.queue_free()
		await get_tree().process_frame
	
	var room_scene_path = "res://Rooms/Room #21.tscn"
	
	if ResourceLoader.exists(room_scene_path):
		var room_scene = load(room_scene_path)
		current_room_node = room_scene.instantiate()
		current_room_node.name = "CutsceneRoom"
		add_child(current_room_node)
		
		await get_tree().process_frame
		await get_tree().process_frame
		
		required_enemies_this_room = 0
		enemies_defeated_this_room = 0
		setup_room_exit()
		reset_player_to_room_start()
		
		print("Custom cutscene room loaded")
	else:
		create_automatic_cutscene_room()
	
	update_ui()

func create_automatic_cutscene_room():
	print("Creating automatic pixel art cutscene room")
	
	current_room_node = Node2D.new()
	current_room_node.name = "AutoCutsceneRoom"
	add_child(current_room_node)
	
	var platform = StaticBody2D.new()
	platform.collision_layer = 1
	platform.collision_mask = 0
	platform.position = Vector2(0, 200)
	
	var platform_collision = CollisionShape2D.new()
	var platform_rect = RectangleShape2D.new()
	platform_rect.size = Vector2(400, 32)
	platform_collision.shape = platform_rect
	platform.add_child(platform_collision)
	current_room_node.add_child(platform)
	
	var spawn = Marker2D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector2(-1000, 150)
	spawn.add_to_group("player_spawn")
	current_room_node.add_child(spawn)
	
	create_pixel_art_cutscene()
	
	required_enemies_this_room = 0
	enemies_defeated_this_room = 0
	reset_player_to_room_start()

func create_pixel_art_cutscene():
	var cutscene_canvas = CanvasLayer.new()
	cutscene_canvas.name = "CutsceneCanvas"
	current_room_node.add_child(cutscene_canvas)
	
	var screen_bg = ColorRect.new()
	screen_bg.color = Color.BLACK
	screen_bg.size = Vector2(1200, 800)
	screen_bg.position = Vector2(0, 0)
	cutscene_canvas.add_child(screen_bg)
	
	create_castle_scene(cutscene_canvas)
	animate_rescue_sequence(cutscene_canvas)

func create_castle_scene(canvas: CanvasLayer):
	var castle_bg = ColorRect.new()
	castle_bg.color = Color(0.15, 0.1, 0.25, 1.0)
	castle_bg.size = Vector2(800, 600)
	castle_bg.position = Vector2(200, 100)
	canvas.add_child(castle_bg)
	
	create_castle_walls(canvas)
	create_prison_gate(canvas)
	create_human_prisoner(canvas)
	create_robot_hero(canvas)

func create_castle_walls(canvas: CanvasLayer):
	var left_wall = ColorRect.new()
	left_wall.color = Color(0.1, 0.05, 0.15, 1.0)
	left_wall.size = Vector2(100, 600)
	left_wall.position = Vector2(200, 100)
	canvas.add_child(left_wall)
	
	var right_wall = ColorRect.new()
	right_wall.color = Color(0.1, 0.05, 0.15, 1.0)
	right_wall.size = Vector2(100, 600)
	right_wall.position = Vector2(900, 100)
	canvas.add_child(right_wall)
	
	var floor = ColorRect.new()
	floor.color = Color(0.08, 0.08, 0.12, 1.0)
	floor.size = Vector2(800, 100)
	floor.position = Vector2(200, 600)
	canvas.add_child(floor)
	
	for i in range(8):
		var stone_line = ColorRect.new()
		stone_line.color = Color(0.05, 0.05, 0.08, 1.0)
		stone_line.size = Vector2(800, 2)
		stone_line.position = Vector2(200, 600 + i * 12)
		canvas.add_child(stone_line)

func create_prison_gate(canvas: CanvasLayer):
	var gate_bg = ColorRect.new()
	gate_bg.name = "GateBackground"
	gate_bg.color = Color(0.05, 0.05, 0.05, 1.0)
	gate_bg.size = Vector2(120, 200)
	gate_bg.position = Vector2(540, 350)
	canvas.add_child(gate_bg)
	
	for i in range(6):
		var bar = ColorRect.new()
		bar.name = "GateBar" + str(i)
		bar.color = Color(0.3, 0.3, 0.3, 1.0)
		bar.size = Vector2(8, 180)
		bar.position = Vector2(550 + i * 18, 360)
		canvas.add_child(bar)
		
		var highlight = ColorRect.new()
		highlight.color = Color(0.5, 0.5, 0.5, 1.0)
		highlight.size = Vector2(2, 180)
		highlight.position = Vector2(550 + i * 18, 360)
		canvas.add_child(highlight)

func create_human_prisoner(canvas: CanvasLayer):
	var human_body = ColorRect.new()
	human_body.name = "HumanPrisoner"
	human_body.color = Color(0.2, 0.15, 0.1, 1.0)
	human_body.size = Vector2(24, 60)
	human_body.position = Vector2(580, 460)
	canvas.add_child(human_body)
	
	var human_head = ColorRect.new()
	human_head.name = "HumanHead"
	human_head.color = Color(0.25, 0.2, 0.15, 1.0)
	human_head.size = Vector2(20, 20)
	human_head.position = Vector2(582, 440)
	canvas.add_child(human_head)
	
	var chains = ColorRect.new()
	chains.name = "Chains"
	chains.color = Color(0.4, 0.4, 0.4, 1.0)
	chains.size = Vector2(6, 40)
	chains.position = Vector2(589, 470)
	canvas.add_child(chains)

func create_robot_hero(canvas: CanvasLayer):
	var robot_body = ColorRect.new()
	robot_body.name = "RobotHero"
	robot_body.color = Color(0.6, 0.8, 1.0, 1.0)
	robot_body.size = Vector2(32, 48)
	robot_body.position = Vector2(400, 500)
	canvas.add_child(robot_body)
	
	var robot_head = ColorRect.new()
	robot_head.name = "RobotHead"
	robot_head.color = Color(0.7, 0.9, 1.0, 1.0)
	robot_head.size = Vector2(28, 28)
	robot_head.position = Vector2(402, 472)
	canvas.add_child(robot_head)
	
	var left_eye = ColorRect.new()
	left_eye.name = "RobotLeftEye"
	left_eye.color = Color(1.0, 1.0, 0.0, 1.0)
	left_eye.size = Vector2(4, 4)
	left_eye.position = Vector2(408, 482)
	canvas.add_child(left_eye)
	
	var right_eye = ColorRect.new()
	right_eye.name = "RobotRightEye"
	right_eye.color = Color(1.0, 1.0, 0.0, 1.0)
	right_eye.size = Vector2(4, 4)
	right_eye.position = Vector2(418, 482)
	canvas.add_child(right_eye)

func animate_rescue_sequence(canvas: CanvasLayer):
	var tween = create_tween()
	
	print("🎬 Starting rescue animation sequence...")
	
	var robot_body = canvas.get_node("RobotHero")
	var robot_head = canvas.get_node("RobotHead")
	var left_eye = canvas.get_node("RobotLeftEye")
	var right_eye = canvas.get_node("RobotRightEye")
	
	tween.tween_delay(1.0)
	tween.parallel().tween_property(robot_body, "position:x", 480.0, 2.0)
	tween.parallel().tween_property(robot_head, "position:x", 482.0, 2.0)
	tween.parallel().tween_property(left_eye, "position:x", 488.0, 2.0)
	tween.parallel().tween_property(right_eye, "position:x", 498.0, 2.0)
	
	tween.tween_delay(0.5)
	for i in range(6):
		var bar = canvas.get_node("GateBar" + str(i))
		tween.parallel().tween_property(bar, "position:y", 250.0, 1.0)
	
	var human_body = canvas.get_node("HumanPrisoner")
	var human_head = canvas.get_node("HumanHead")
	var chains = canvas.get_node("Chains")
	
	tween.tween_delay(0.3)
	tween.parallel().tween_property(human_body, "position:x", 520.0, 1.5)
	tween.parallel().tween_property(human_head, "position:x", 522.0, 1.5)
	tween.parallel().tween_property(chains, "modulate:a", 0.0, 0.5)
	
	var screen_bg = canvas.get_children()[0]
	tween.tween_delay(0.5)
	tween.tween_property(screen_bg, "color", Color.BLACK, 1.0)
	
	var all_elements = canvas.get_children()
	for element in all_elements:
		if element != screen_bg:
			tween.parallel().tween_property(element, "modulate:a", 0.0, 1.0)
	
	tween.tween_delay(1.0)
	tween.tween_callback(show_golden_podium_scene.bind(canvas))

func show_golden_podium_scene(canvas: CanvasLayer):
	print("🎬 Showing golden podium scene...")
	
	var podium_bg = ColorRect.new()
	podium_bg.color = Color(1.0, 0.8, 0.0, 1.0)
	podium_bg.size = Vector2(400, 200)
	podium_bg.position = Vector2(400, 300)
	podium_bg.modulate.a = 0.0
	canvas.add_child(podium_bg)
	
	var congrats_text = Label.new()
	congrats_text.text = "CONGRATULATIONS!"
	congrats_text.position = Vector2(450, 320)
	congrats_text.add_theme_font_size_override("font_size", 36)
	congrats_text.add_theme_color_override("font_color", Color.BLACK)
	congrats_text.modulate.a = 0.0
	canvas.add_child(congrats_text)
	
	var master_text = Label.new()
	master_text.text = "You have saved your master!"
	master_text.position = Vector2(470, 380)
	master_text.add_theme_font_size_override("font_size", 20)
	master_text.add_theme_color_override("font_color", Color.BLACK)
	master_text.modulate.a = 0.0
	canvas.add_child(master_text)
	
	var tween = create_tween()
	
	tween.tween_property(podium_bg, "modulate:a", 1.0, 1.0)
	tween.tween_delay(0.5)
	tween.tween_property(congrats_text, "modulate:a", 1.0, 1.0)
	tween.tween_delay(0.5)
	tween.tween_property(master_text, "modulate:a", 1.0, 1.0)
	
	tween.parallel().tween_property(congrats_text, "scale", Vector2(1.2, 1.2), 0.5)
	tween.parallel().tween_property(congrats_text, "scale", Vector2(1.0, 1.0), 0.5)
	
	tween.tween_delay(2.0)
	tween.tween_callback(complete_cutscene_and_show_exit)

func complete_cutscene_and_show_exit():
	print("🎬 Cutscene complete - bringing player to golden podium")
	
	var spawn_points = get_tree().get_nodes_in_group("player_spawn")
	if spawn_points.size() > 0:
		spawn_points[0].position = Vector2(0, 150)
	
	if player:
		if player.has_method("teleport_to_position"):
			player.teleport_to_position(Vector2(0, 150))
		else:
			player.global_position = Vector2(0, 150)
	
	var golden_platform = StaticBody2D.new()
	golden_platform.collision_layer = 1
	golden_platform.collision_mask = 0
	golden_platform.position = Vector2(0, 200)
	
	var golden_sprite = ColorRect.new()
	golden_sprite.color = Color.GOLD
	golden_sprite.size = Vector2(400, 32)
	golden_sprite.position = Vector2(-200, 0)
	
	var golden_collision = CollisionShape2D.new()
	var golden_rect = RectangleShape2D.new()
	golden_rect.size = Vector2(400, 32)
	golden_collision.shape = golden_rect
	
	golden_platform.add_child(golden_sprite)
	golden_platform.add_child(golden_collision)
	current_room_node.add_child(golden_platform)
	
	var exit = Area2D.new()
	exit.name = "RoomExit"
	exit.position = Vector2(200, 150)
	exit.add_to_group("room_exits")
	exit.collision_layer = 4
	exit.collision_mask = 1
	
	var exit_collision = CollisionShape2D.new()
	var exit_rect = RectangleShape2D.new()
	exit_rect.size = Vector2(64, 128)
	exit_collision.shape = exit_rect
	exit.add_child(exit_collision)
	
	var exit_sprite = ColorRect.new()
	exit_sprite.color = Color.GOLD
	exit_sprite.size = Vector2(64, 128)
	exit_sprite.position = Vector2(-32, -64)
	exit.add_child(exit_sprite)
	
	var exit_text = Label.new()
	exit_text.text = "VICTORY"
	exit_text.position = Vector2(-25, -10)
	exit_text.add_theme_font_size_override("font_size", 14)
	exit_text.add_theme_color_override("font_color", Color.BLACK)
	exit.add_child(exit_text)
	
	current_room_node.add_child(exit)
	exit.body_entered.connect(_on_room_exit_entered)
	
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(exit_sprite, "modulate", Color.WHITE, 0.7)
	tween.tween_property(exit_sprite, "modulate", Color.GOLD, 0.7)
	
	print("✨ Golden victory portal created!")

func complete_game():
	is_game_active = false
	print("🎉🎉🎉 ULTIMATE VICTORY! You completed the entire rescue mission! 🎉🎉🎉")
	time_label.text = "MISSION COMPLETE!"
	enemy_label.text = "MASTER RESCUED!"
	room_label.text = "HERO!"
	
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(time_label, "modulate", Color.GOLD, 0.5)
	tween.tween_property(time_label, "modulate", Color.WHITE, 0.5)

func apply_time_penalty(penalty_type: String):
	if not is_game_active:
		return
	
	var penalty_amount = 0
	match penalty_type:
		"hit":
			penalty_amount = 5
		"attack":
			penalty_amount = 5
		"special":
			penalty_amount = 3
	
	game_time = max(0, game_time - penalty_amount)
	print("Time penalty: -", penalty_amount, "s. Remaining: ", game_time, "s")
	
	flash_timer_red()
	
	if game_time <= 0:
		game_over()
	
	update_ui()

func flash_timer_red():
	if time_label:
		var tween = create_tween()
		tween.tween_property(time_label, "modulate", Color.RED, 0.1)
		tween.tween_property(time_label, "modulate", Color.WHITE, 0.3)

func game_over():
	is_game_active = false
	print("⏰ GAME OVER! Restarting from Room 1...")
	time_label.text = "GAME OVER!"
	await get_tree().create_timer(2.0).timeout
	start_game()

func _process(delta):
	if is_game_active:
		game_time -= delta
		
		if game_time <= 0:
			game_over()
		else:
			update_ui()

func update_ui():
	var minutes = int(game_time) / 60
	var seconds = int(game_time) % 60
	time_label.text = "Time: %02d:%02d" % [minutes, seconds]
	
	var remaining_enemies = get_remaining_enemy_count()
	var defeated_enemies = required_enemies_this_room - remaining_enemies
	enemy_label.text = "Enemies: %d/%d" % [defeated_enemies, required_enemies_this_room]
	
	room_label.text = "Room: %d/%d" % [current_room, total_rooms]
	
	update_battery_display()

func update_battery_display():
	if not battery_sprite:
		return
	
	var time_percentage = game_time / max_time
	
	if battery_sprite.sprite_frames and battery_sprite.sprite_frames.has_animation("battery_drain"):
		var total_frames = battery_sprite.sprite_frames.get_frame_count("battery_drain")
		if total_frames > 0:
			var frame_index = int((1.0 - time_percentage) * (total_frames - 1))
			frame_index = clamp(frame_index, 0, total_frames - 1)
