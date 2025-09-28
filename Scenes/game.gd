# Main.gd
# Enhanced version with visual UI and robot integration
extends Node2D

# Game state
var current_level: int = 1
var game_time: float = 120.0
var enemies_defeated: int = 0
var required_enemies: int = 2
var is_game_running: bool = true

# UI elements
var time_label: Label
var level_label: Label
var enemy_label: Label
var ui_container: CanvasLayer

func _ready():
	setup_ui()
	print("🤖 === ROBOT TIME ATTACK GAME ===")
	print("Arrow Keys = Move robot")
	print("Space = Jump")
	print("F = Attack (costs 5 seconds)")
	print("E = Special Action (costs 3 seconds)")
	print("H = Test robot hit")
	print("T = Test robot connection")
	print("A = Test hit penalty")
	print("S = Test enemy defeat")
	print("===================================")
	
	# Debug: Check if robot can find this node
	print("🔍 Main game node path: ", get_path())

func setup_ui():
	# Create UI layer
	ui_container = CanvasLayer.new()
	add_child(ui_container)
	
	# Create main UI container
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	ui_container.add_child(vbox)
	
	# Timer display
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 32)
	time_label.text = "TIME: 02:00"
	vbox.add_child(time_label)
	
	# Level display
	level_label = Label.new()
	level_label.add_theme_font_size_override("font_size", 24)
	level_label.text = "LEVEL: 1/20"
	vbox.add_child(level_label)
	
	# Enemy progress
	enemy_label = Label.new()
	enemy_label.add_theme_font_size_override("font_size", 24)
	enemy_label.text = "ENEMIES: 0/2"
	vbox.add_child(enemy_label)

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
	print("🤖 Robot caused time penalty: -%.1fs | Remaining: %.1fs" % [penalty, game_time])

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
	
	# Increase difficulty
	game_time = max(60.0, 120.0 - (current_level - 1) * 3.0)
	required_enemies = 2 + int((current_level - 1) / 3)
	
	print("📈 LEVEL %d START!" % current_level)
	print("⏰ Time limit: %.1fs" % game_time)
	print("🎯 Required enemies: %d" % required_enemies)

func restart_level():
	enemies_defeated = 0
	game_time = max(60.0, 120.0 - (current_level - 1) * 3.0)
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
	time_label.text = "TIME: %02d:%02d" % [minutes, seconds]
	
	# Change color based on remaining time
	if game_time > 30:
		time_label.modulate = Color.WHITE
	elif game_time > 10:
		time_label.modulate = Color.YELLOW
	else:
		time_label.modulate = Color.RED
	
	# Update other labels
	level_label.text = "LEVEL: %d/20" % current_level
	enemy_label.text = "ENEMIES: %d/%d" % [enemies_defeated, required_enemies]

func flash_timer_red():
	var tween = create_tween()
	tween.tween_property(time_label, "modulate", Color.RED, 0.1)
	tween.tween_property(time_label, "modulate", Color.WHITE, 0.3)

func bounce_enemy_counter():
	var tween = create_tween()
	tween.tween_property(enemy_label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(enemy_label, "scale", Vector2(1.0, 1.0), 0.1)
