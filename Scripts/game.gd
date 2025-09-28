# game.gd
# Complete Robot Time Attack Game with reset functionality
extends Node2D

# Game state variables
var current_level: int = 1
var game_time: float = 120.0
var enemies_defeated: int = 0
var required_enemies: int = 2
var is_game_running: bool = true
var level_start_time: float = 120.0

# UI elements
var time_label: Label
var level_label: Label
var enemy_label: Label
var ui_container: CanvasLayer
var battery_sprite: AnimatedSprite2D

func _ready():
	print("Robot Time Attack Game Starting...")
	level_start_time = game_time
	setup_ui()
	print("=== CONTROLS ===")
	print("Arrow Keys = Move robot")
	print("Space = Jump")
	print("F = Attack (costs 5 seconds)")
	print("G = Special Action (costs 3 seconds)")
	print("T = Test time penalty")
	print("E = Test enemy defeat")
	print("R = Restart level")
	print("================")

func setup_ui():
	# Prevent duplicate UI
	if ui_container != null:
		return
	
	# Create UI overlay
	ui_container = CanvasLayer.new()
	add_child(ui_container)
	
	# Battery sprite - scaled 2x larger
	battery_sprite = AnimatedSprite2D.new()
	battery_sprite.position = Vector2(60, 70)
	battery_sprite.scale = Vector2(3.0, 3.0)  # 2x larger than before
	ui_container.add_child(battery_sprite)
	
	# Load battery animation
	var battery_frames = load("res://Scenes/battery_drain.tres")
	if battery_frames:
		battery_sprite.sprite_frames = battery_frames
		print("Battery animation loaded successfully")
	else:
		print("No battery animation found - using timer only")
	
	# Timer display - 2x larger font
	time_label = Label.new()
	time_label.position = Vector2(200, 40)
	time_label.add_theme_font_size_override("font_size", 56)  # 2x larger
	time_label.text = "02:00"
	ui_container.add_child(time_label)
	
	# Level display - 2x larger font
	level_label = Label.new()
	level_label.position = Vector2(40, 140)
	level_label.add_theme_font_size_override("font_size", 40)  # 2x larger
	level_label.text = "LEVEL: 1/20"
	ui_container.add_child(level_label)
	
	# Enemy progress - 2x larger font
	enemy_label = Label.new()
	enemy_label.position = Vector2(40, 190)
	enemy_label.add_theme_font_size_override("font_size", 40)  # 2x larger
	enemy_label.text = "ENEMIES: 0/2"
	ui_container.add_child(enemy_label)
	
func _process(delta):
	# Countdown timer
	if is_game_running and game_time > 0:
		game_time -= delta
		update_ui()
		
		if game_time <= 0:
			game_over()

func _input(event):
	# Test controls and game management
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_T:
				apply_time_penalty("hit")
				print("Test: Lost 5 seconds!")
			KEY_E:
				enemy_defeated()
				print("Test: Enemy defeated!")
			KEY_R:
				restart_level()
				print("Level restarted!")

func apply_time_penalty(penalty_type: String):
	var penalty: float = 0.0
	
	match penalty_type:
		"hit":
			penalty = 5.0
		"special":
			penalty = 3.0
		"environmental":
			penalty = 2.0
		_:
			penalty = 5.0
	
	game_time = max(0.0, game_time - penalty)
	
	# Fix floating point precision issues by rounding to 1 decimal place
	game_time = round(game_time * 10.0) / 10.0
	
	flash_timer()
	print("Time penalty: -%.1fs | Remaining: %.1fs" % [penalty, game_time])
func enemy_defeated():
	enemies_defeated += 1
	bounce_enemy_counter()
	print("Enemy defeated! Progress: %d/%d" % [enemies_defeated, required_enemies])
	
	if enemies_defeated >= required_enemies:
		level_complete()

func level_complete():
	print("LEVEL %d COMPLETE!" % current_level)
	print("Bonus points for remaining time: %d" % int(game_time * 10))
	
	if current_level >= 20:
		game_won()
	else:
		next_level()

func next_level():
	current_level += 1
	enemies_defeated = 0
	
	# Increase difficulty - less time each level
	level_start_time = max(60.0, 120.0 - (current_level - 1) * 3.0)
	game_time = level_start_time
	
	# More enemies required each level
	required_enemies = 2 + int((current_level - 1) / 3)
	
	print("LEVEL %d START!" % current_level)
	print("Time limit: %.1fs" % game_time)
	print("Required enemies: %d" % required_enemies)
	
	# Reset all entities to starting positions
	reset_all_entities()

func restart_level():
	enemies_defeated = 0
	level_start_time = max(60.0, 120.0 - (current_level - 1) * 3.0)
	game_time = level_start_time
	is_game_running = true
	
	# Reset all entities to starting positions
	reset_all_entities()

func reset_all_entities():
	# Reset player to starting position
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("reset_to_start"):
		player.reset_to_start()
	
	# Reset all enemies to starting positions
	var enemies = get_tree().get_nodes_in_group("enemies")
	print("Resetting ", enemies.size(), " enemies to starting positions")
	
	for enemy in enemies:
		if enemy.has_method("reset_to_start"):
			enemy.reset_to_start()
	
	print("All entities reset to starting positions!")

func game_over():
	print("TIME'S UP! Auto-restarting level...")
	
	# Auto-restart instead of stopping
	restart_level()
	
	# Brief visual feedback that time ran out
	if time_label:
		time_label.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(time_label, "modulate", Color.WHITE, 1.0)
func game_won():
	print("CONGRATULATIONS!")
	print("You completed all 20 levels!")
	print("You are the ultimate robot!")

func update_ui():
	# Update timer display
	var minutes = int(game_time) / 60
	var seconds = int(game_time) % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]
	
	# Calculate time percentage for battery
	var time_percentage = game_time / level_start_time
	time_percentage = clamp(time_percentage, 0.0, 1.0)
	
	# Update battery animation if available
	update_battery_animation(time_percentage)
	
	# Color coding based on time remaining
	if time_percentage > 0.5:
		time_label.modulate = Color.WHITE
	elif time_percentage > 0.25:
		time_label.modulate = Color.YELLOW
	else:
		time_label.modulate = Color.RED
	
	# Update other labels
	level_label.text = "LEVEL: %d/20" % current_level
	enemy_label.text = "ENEMIES: %d/%d" % [enemies_defeated, required_enemies]

func update_battery_animation(time_percentage: float):
	if not battery_sprite or not battery_sprite.sprite_frames:
		return
	
	if not battery_sprite.sprite_frames.has_animation("battery_drain"):
		return
	
	var total_frames = battery_sprite.sprite_frames.get_frame_count("battery_drain")
	if total_frames == 0:
		return
	
	# Calculate frame (0 = full battery, last frame = empty)
	var frame_index = int((1.0 - time_percentage) * (total_frames - 1))
	frame_index = clamp(frame_index, 0, total_frames - 1)
	
	# Set animation and frame
	if battery_sprite.animation != "battery_drain":
		battery_sprite.play("battery_drain")
	
	battery_sprite.pause()
	battery_sprite.frame = frame_index

func flash_timer():
	var tween = create_tween()
	tween.tween_property(time_label, "modulate", Color.RED, 0.1)
	tween.tween_property(time_label, "modulate", Color.WHITE, 0.3)

func bounce_enemy_counter():
	var tween = create_tween()
	tween.tween_property(enemy_label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(enemy_label, "scale", Vector2(1.0, 1.0), 0.1)

func can_complete_level() -> bool:
	return enemies_defeated >= required_enemies
