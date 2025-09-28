extends Node

# Game state variables
var current_level: int = 1
var game_time: float = 120.0
var is_game_active: bool = false
var enemies_defeated: int = 0
var required_enemies: int = 2

# Timer UI
@onready var time_label = Label.new()

func _ready():
	# Setup UI
	setup_ui()
	
	# Start game
	start_game()
	print("Simple game manager started!")

func setup_ui():
	# Create simple timer display
	time_label.position = Vector2(10, 10)
	time_label.add_theme_font_size_override("font_size", 24)
	add_child(time_label)

func _process(delta):
	if is_game_active and game_time > 0:
		game_time -= delta
		update_ui()
		
		if game_time <= 0:
			game_over()

func _input(event):
	# Test controls
	if Input.is_action_just_pressed("ui_accept"):  # Space/Enter
		apply_time_penalty(5.0)
		print("Hit penalty applied!")
	
	if Input.is_action_just_pressed("ui_select"):  # Enter
		enemy_defeated()
		print("Enemy defeated!")

func start_game():
	is_game_active = true
	print("Game started! Press Space for hit penalty, Enter to defeat enemy")

func apply_time_penalty(penalty: float):
	game_time = max(0, game_time - penalty)
	print("Time penalty: -", penalty, "s. Remaining: ", game_time, "s")

func enemy_defeated():
	enemies_defeated += 1
	print("Enemies defeated: ", enemies_defeated, "/", required_enemies)
	
	if enemies_defeated >= required_enemies:
		print("Level complete! You can advance!")

func update_ui():
	var minutes = int(game_time) / 60
	var seconds = int(game_time) % 60
	time_label.text = "Time: %02d:%02d | Level: %d | Enemies: %d/%d" % [minutes, seconds, current_level, enemies_defeated, required_enemies]

func game_over():
	is_game_active = false
	print("Game Over!")
