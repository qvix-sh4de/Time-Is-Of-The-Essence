# Victory.gd
extends Control

func _ready():
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.2, 0.1)
	bg.size = Vector2(1152, 648)
	add_child(bg)
	
	var title = Label.new()
	title.text = "MISSION ACCOMPLISHED!"
	title.position = Vector2(200, 200)
	title.add_theme_font_size_override("font_size", 48)
	title.modulate = Color.GOLD
	add_child(title)
	
	var msg = Label.new()
	msg.text = "You successfully rescued your master!"
	msg.position = Vector2(300, 300)
	msg.add_theme_font_size_override("font_size", 24)
	add_child(msg)
	
	var menu_btn = Button.new()
	menu_btn.text = "BACK TO MENU"
	menu_btn.position = Vector2(476, 400)
	menu_btn.size = Vector2(200, 60)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://StartMenu.tscn"))
	add_child(menu_btn)
