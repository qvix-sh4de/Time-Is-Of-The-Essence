# HowToPlay.gd
extends Control

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.2)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var title = Label.new()
	title.text = "HOW TO PLAY"
	title.position = Vector2(400, 30)
	title.add_theme_font_size_override("font_size", 48)
	add_child(title)
	
	var instructions = Label.new()
	instructions.text = """TIME IS OF THE ESSENCE!
Get to your master before time runs out by dismantling other robots.

CONTROLS:
- Arrow Keys: Move • Space: Jump
- F: Attack (-5 seconds) • E: Shield (-10 seconds)
- G: Power-up (-5 seconds) • R: Area Attack (-15 seconds)

TIME PENALTIES:
- Taking a hit: -5 seconds • Any attack: -5 seconds
- Shield use: -10 seconds • Area attack: -15 seconds

Clear all enemies to unlock the exit. Reach Room 21 to win!"""
	instructions.position = Vector2(50, 120)
	instructions.size = Vector2(1000, 400)
	instructions.add_theme_font_size_override("font_size", 24)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(instructions)
	
	var back_btn = Button.new()
	back_btn.text = "BACK TO MENU"
	back_btn.position = Vector2(450, 520)
	back_btn.size = Vector2(250, 60)
	back_btn.add_theme_font_size_override("font_size", 28)
	back_btn.pressed.connect(func(): 
		get_tree().change_scene_to_file("res://Scenes/StartMenu.tscn")
	)
	add_child(back_btn)
