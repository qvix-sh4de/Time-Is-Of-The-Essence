# Game.gd - Complete Fixed Game Manager
extends Node2D

# Game state
var current_room: int = 1
var total_rooms: int = 20
var game_time: float = 120.0  # 2 minutes per room
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
	# Create UI Canvas
	var canvas = CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)
	
	# Time display
	time_label = Label.new()
	time_label.position = Vector2(20, 20)
	time_label.add_theme_font_size_override("font_size", 24)
	time_label.text = "Time: 02:00"
	canvas.add_child(time_label)
	
	# Enemy counter
	enemy_label = Label.new()
	enemy_label.position = Vector2(20, 50)
	enemy_label.add_theme_font_size_override("font_size", 20)
	enemy_label.text = "Enemies: 0/0"
	canvas.add_child(enemy_label)
	
	# Room display
	room_label = Label.new()
	room_label.position = Vector2(20, 80)
	room_label.add_theme_font_size_override("font_size", 20)
	room_label.text = "Room: 1/20"
	canvas.add_child(room_label)
	
	# Battery display
	battery_sprite = AnimatedSprite2D.new()
	battery_sprite.name = "BatterySprite"
	battery_sprite.position = Vector2(300, 50)
	battery_sprite.scale = Vector2(2, 2)
	canvas.add_child(battery_sprite)

func setup_enemy_manager():
	# Create enemy manager
	enemy_manager = Node.new()
	enemy_manager.name = "EnemyManager"
	add_child(enemy_manager)
	
	# Add enemy manager script
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
	enemy_manager.set_script(enemy_manager_script)

func start_game():
	is_game_active = true
	current_room = 1
	game_time = max_time
	enemies_defeated_this_room = 0
	
	# Find player
	player = get_tree().get_first_node_in_group("player")
	if not player:
		print("ERROR: No player found!")
		return
	
	# Load first room
	load_room(current_room)
	
	print("Game started! Room 1 loaded.")

func load_room(room_number: int):
	print("Loading Room #", room_number)
	
	# Clear current room
	if current_room_node:
		current_room_node.queue_free()
		await get_tree().process_frame
	
	# Load room scene
	var room_scene_path = "res://Rooms/Room #%d.tscn" % room_number
	
	if not ResourceLoader.exists(room_scene_path):
		print("ERROR: Room scene not found: ", room_scene_path)
		create_fallback_room()
		return
	
	# Load and instance the room
	var room_scene = load(room_scene_path)
	current_room_node = room_scene.instantiate()
	current_room_node.name = "CurrentRoom"
	add_child(current_room_node)
	
	# Wait for everything to load
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Count enemies and setup room systems
	count_enemies_in_room()
	setup_room_exit()
	reset_player_to_room_start()
	
	# Update UI
	update_ui()
	
	print("Room ", room_number, " loaded with ", required_enemies_this_room, " enemies")

func create_fallback_room():
	# Create a simple fallback room if scene file is missing
	print("Creating fallback room for room ", current_room)
	
	current_room_node = Node2D.new()
	current_room_node.name = "FallbackRoom"
	add_child(current_room_node)
	
	# Create simple platform
	var platform = StaticBody2D.new()
	platform.collision_layer = 2  # Platforms on layer 2
	platform.collision_mask = 0   # Platforms don't need to detect anything
	
	var sprite = ColorRect.new()
	sprite.color = Color.BROWN
	sprite.size = Vector2(800, 32)
	sprite.position = Vector2(-400, 200)
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(800, 32)
	collision.shape = shape
	platform.position = Vector2(0, 200)
	platform.add_child(sprite)
	platform.add_child(collision)
	current_room_node.add_child(platform)
	
	# Create player spawn
	var spawn = Marker2D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector2(-300, 150)
	spawn.add_to_group("player_spawn")
	current_room_node.add_child(spawn)
	
	# Create room exit
	var exit = Area2D.new()
	exit.name = "RoomExit" 
	exit.position = Vector2(300, 150)
	exit.add_to_group("room_exits")
	exit.collision_layer = 8  # Exit on layer 4 (bit 4 = value 8)
	exit.collision_mask = 1   # Detects player (layer 1)
	var exit_collision = CollisionShape2D.new()
	var exit_shape = RectangleShape2D.new()
	exit_shape.size = Vector2(64, 128)
	exit_collision.shape = exit_shape
	exit.add_child(exit_collision)
	current_room_node.add_child(exit)
	
	required_enemies_this_room = 0
	setup_room_exit()
	reset_player_to_room_start()

func count_enemies_in_room():
	# Count all enemies in the current room
	var enemies = get_tree().get_nodes_in_group("enemies")
	required_enemies_this_room = 0
	enemies_defeated_this_room = 0
	
	for enemy in enemies:
		# Check if enemy is a child of current room
		if current_room_node.is_ancestor_of(enemy):
			required_enemies_this_room += 1
	
	# Update enemy manager
	if enemy_manager and enemy_manager.has_method("count_enemies"):
		enemy_manager.count_enemies()
	
	print("Found ", required_enemies_this_room, " enemies in room")

func setup_room_exit():
	# Find and connect room exits
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
	# Flash the enemy counter red when trying to exit with enemies remaining
	if enemy_label:
		var tween = create_tween()
		tween.tween_property(enemy_label, "modulate", Color.RED, 0.2)
		tween.tween_property(enemy_label, "modulate", Color.WHITE, 0.3)

func flash_success_message():
	# Flash the enemy counter green when all enemies defeated
	if enemy_label:
		var tween = create_tween()
		tween.tween_property(enemy_label, "modulate", Color.GREEN, 0.2)
		tween.tween_property(enemy_label, "modulate", Color.WHITE, 0.5)

func advance_to_next_room():
	if current_room >= total_rooms:
		complete_game()
		return
	
	current_room += 1
	game_time = max_time  # Reset timer for new room
	print("🏃 Advancing to room ", current_room)
	load_room(current_room)

func complete_game():
	is_game_active = false
	print("🎉 CONGRATULATIONS! You completed all ", total_rooms, " rooms!")
	time_label.text = "GAME COMPLETE!"
	enemy_label.text = "ALL ROOMS CLEARED!"
	room_label.text = "VICTORY!"

func apply_time_penalty(penalty_type: String):
	if not is_game_active:
		return
	
	var penalty_amount = 0
	match penalty_type:
		"hit":
			penalty_amount = 5
		"attack":
			penalty_amount = 5  # Attack also costs 5 seconds
		"special":
			penalty_amount = 3
	
	game_time = max(0, game_time - penalty_amount)
	print("Time penalty: -", penalty_amount, "s. Remaining: ", game_time, "s")
	
	# Flash timer red
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
	# FIXED: Clean timer display (no decimals)
	var minutes = int(game_time) / 60
	var seconds = int(game_time) % 60
	time_label.text = "Time: %02d:%02d" % [minutes, seconds]
	
	# FIXED: Accurate enemy counter
	var remaining_enemies = get_remaining_enemy_count()
	var defeated_enemies = required_enemies_this_room - remaining_enemies
	enemy_label.text = "Enemies: %d/%d" % [defeated_enemies, required_enemies_this_room]
	
	# Update room display
	room_label.text = "Room: %d/%d" % [current_room, total_rooms]
	
	# Update battery animation
	update_battery_display()

func update_battery_display():
	if not battery_sprite:
		return
	
	# Calculate time percentage for battery display
	var time_percentage = game_time / max_time
	
	# If you have battery animation loaded
	if battery_sprite.sprite_frames and battery_sprite.sprite_frames.has_animation("battery_drain"):
		var total_frames = battery_sprite.sprite_frames.get_frame_count("battery_drain")
		if total_frames > 0:
			var frame_index = int((1.0 - time_percentage) * (total_frames - 1))
			frame_index = clamp(frame_index, 0, total_frames - 1)
			
			if battery_sprite.animation != "battery_drain":
				battery_sprite.play("battery_drain")
			
			battery_sprite.pause()
			battery_sprite.frame = frame_index
