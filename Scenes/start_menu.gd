# StartMenu.gd
extends Control

func _ready():
	GlobalVars.game_started = false
	
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.2)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var title = Label.new()
	title.text = "ROBOT RESCUE MISSION"
	title.position = Vector2(200, 150)
	title.add_theme_font_size_override("font_size", 64)
	add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Time is running out - save your master!"
	subtitle.position = Vector2(250, 230)
	subtitle.add_theme_font_size_override("font_size", 32)
	add_child(subtitle)
	
	var play_btn = Button.new()
	play_btn.text = "PLAY"
	play_btn.position = Vector2(450, 320)
	play_btn.size = Vector2(250, 80)
	play_btn.add_theme_font_size_override("font_size", 40)
	play_btn.pressed.connect(func(): 
		GlobalVars.game_started = true
		get_tree().change_scene_to_file("res://Scenes/game.tscn")
	)
	add_child(play_btn)
	
	var help_btn = Button.new()
	help_btn.text = "HOW TO PLAY"
	help_btn.position = Vector2(450, 420)
	help_btn.size = Vector2(250, 80)
	help_btn.add_theme_font_size_override("font_size", 32)
	help_btn.pressed.connect(func(): 
		get_tree().change_scene_to_file("res://Scenes/HowToPlay.tscn")
	)
	add_child(help_btn)
