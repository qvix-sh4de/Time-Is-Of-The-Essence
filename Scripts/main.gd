# Main.gd
# Enhanced version with visual UI and robot integration
extends Node2D

# Game state
var current_level: int = 1
var game_time: float = 120.0
var enemies_defeated: int = 0
var required_enemies: int = 2
var is_game_running: bool = true
var level_start_time: float = 120.0  # Store the starting time for percentage calculation

# UI elements
var time_label: Label
var level_label: Label
var enemy_label: Label
var ui_container: CanvasLayer
var battery_sprite: AnimatedSprite2D

func _ready():
	level_start_time = game_time  # Initialize starting time
	setup_ui()
	print("🤖 === ROBOT TIME ATTACK GAME ===")
	print("Arrow Keys = Move robot")
	print("Space = Jump")
	print("F = Attack")
	print("E = Special Action (costs time)")
	print("A = Test hit penalty")
	print("S = Test enemy defeat")
	print("===================================")

func setup_ui():
	# Create UI layer
	ui_container = CanvasLayer.new()
	add_child(ui_container)
	
	# Create main UI container
	var main_container = Control.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_container.add_child(main_container)
	
	# Battery UI container (top left)
	var battery_container = HBoxContainer.new()
	battery_container.position = Vector2(20, 20)
	main_container.add_child(battery_container)
	
	# Create battery animated sprite
	battery_sprite = AnimatedSprite2D.new()
	battery_sprite.scale = Vector2(2, 2)  # Adjust scale as needed
	battery_container.add_child(battery_sprite)
	
	# Load your battery animation - UPDATE THIS PATH TO YOUR BATTERY ANIMATION
	# battery_sprite.sprite_frames = load("res://path/to/your/battery_animation.tres")
	
	# Time text next to battery
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 28)
	time_label.text = "02:00"
	battery_container.add_child(time_label)
	
	# Level and enemy info below battery
	var info_container = VBoxContainer.new()
	info_container.position = Vector2(20, 80)
	main_container.add_child(info_container)
	
	# Level display
	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 24)
	level_label.text = "LEVEL: 1/20"
	info_container.add_child(level_label)
	
	# Enemy progress
	enemy_label = Label.new()
	enemy_label.add_theme_font_size_override("font_size", 24)
	enemy_label.text = "ENEMIES: 0/2"
	info_container.add_child(enemy_label)

func _process(delta):
	if is_game_running and game_time > 0:
		game_time -= delta
		update_ui()
		
		if game_time <= 0:
			game_over()

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_A:
				apply_time_penalty("hit")
				print("🔥 Test hit penalty!")
			
			KEY_S:
				enemy_defeated()
				print("⚔️ Test enemy defeat!")
			
			KEY_R:
				restart_level()
				print("🔄 Level restarted!")

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
	
	game_time = max(0, game_time - penalty)
	
	# Visual feedback
	flash_timer_red()
	print("⏰ Time penalty: -%.1fs | Remaining: %.1fs" % [penalty, game_time])

func enemy_defeated():
	enemies_defeated += 1
	
	# Visual feedback
	bounce_enemy_counter()
	print("👾 Enemy defeated! Progress: %d/%d" % [enemies_defeated, required_enemies])
	
	if enemies_defeated >= required_enemies:
		level_complete()

func level_complete():
	print("🎉 LEVEL %d COMPLETE!" % current_level)
	print("💫 Bonus points for remaining time: %d" % int(game_time * 10))
	
	if current_level >= 20:
		game_won()
	else:
		next_level()

func next_level():
	current_level += 1
	enemies_defeated = 0
	
	# Increase difficulty and store starting time
	level_start_time = max(60.0, 120.0 - (current_level - 1) * 3.0)
	game_time = level_start_time
	required_enemies = 2 + int((current_level - 1) / 3)
	
	print("📈 LEVEL %d START!" % current_level)
	print("⏰ Time limit: %.1fs" % game_time)
	print("🎯 Required enemies: %d" % required_enemies)

func restart_level():
	enemies_defeated = 0
	level_start_time = max(60.0, 120.0 - (current_level - 1) * 3.0)
	game_time = level_start_time
	is_game_running = true

func game_over():
	is_game_running = false
	time_label.modulate = Color.RED
	print("💀 GAME OVER!")
	print("🏁 Final Level: %d" % current_level)

func game_won():
	print("🏆 CONGRATULATIONS!")
	print("🌟 You completed all 20 levels!")
	print("👑 You are the ultimate robot!")

func update_ui():
	# Update timer with color coding
	var minutes = int(game_time) / 60
	var seconds = int(game_time) % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]
	
	# Calculate battery percentage based on current level's starting time
	var time_percentage = game_time / level_start_time
	time_percentage = clamp(time_percentage, 0.0, 1.0)
	
	# Update battery animation frame
	update_battery_animation(time_percentage)
	
	# Change color based on remaining time percentage
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
	
	# Check if the battery animation exists
	if not battery_sprite.sprite_frames.has_animation("battery_drain"):
		print("❌ Animation 'battery_drain' not found!")
		return
	
	# Get total frames in the animation (should be 19)
	var total_frames = battery_sprite.sprite_frames.get_frame_count("battery_drain")
	
	if total_frames == 0:
		print("❌ No frames in 'battery_drain' animation!")
		return
	
	# Calculate which frame to show based on percentage
	# Frame 0 = 100%, Frame 18 = ~0%
	var frame_index = int((1.0 - time_percentage) * (total_frames - 1))
	frame_index = clamp(frame_index, 0, total_frames - 1)
	
	# Set the animation and frame
	if battery_sprite.animation != "battery_drain":
		battery_sprite.play("battery_drain")
	
	battery_sprite.pause()  # Stop auto-playing
	battery_sprite.frame = frame_index

func flash_timer_red():
	var tween = create_tween()
	tween.tween_property(time_label, "modulate", Color.RED, 0.1)
	tween.tween_property(time_label, "modulate", Color.WHITE, 0.3)

func bounce_enemy_counter():
	var tween = create_tween()
	tween.tween_property(enemy_label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(enemy_label, "scale", Vector2(1.0, 1.0), 0.1)
