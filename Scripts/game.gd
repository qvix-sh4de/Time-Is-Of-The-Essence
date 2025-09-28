extends Node2D

var current_room: int = 1
var total_rooms: int = 21
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
var battery_sprite: AnimatedSprite2D
var ui_canvas: CanvasLayer

var enemy_manager: Node

func _ready() -> void:
	setup_ui()
	setup_enemy_manager()
	start_game()

func setup_ui() -> void:
	ui_canvas = CanvasLayer.new()
	ui_canvas.name = "UI"
	add_child(ui_canvas)
	
	var ui_panel = ColorRect.new()
	ui_panel.color = Color(0, 0, 0, 0.7)
	ui_panel.size = Vector2(400, 120)
	ui_panel.position = Vector2(20, 20)
	ui_canvas.add_child(ui_panel)
	
	time_label = Label.new()
	time_label.position = Vector2(40, 35)
	time_label.add_theme_font_size_override("font_size", 32)
	time_label.add_theme_color_override("font_color", Color.CYAN)
	time_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	time_label.add_theme_constant_override("shadow_offset_x", 2)
	time_label.add_theme_constant_override("shadow_offset_y", 2)
	time_label.text = "TIME: 05:00"
	ui_canvas.add_child(time_label)
	
	enemy_label = Label.new()
	enemy_label.position = Vector2(40, 70)
	enemy_label.add_theme_font_size_override("font_size", 20)
	enemy_label.add_theme_color_override("font_color", Color.YELLOW)
	enemy_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	enemy_label.add_theme_constant_override("shadow_offset_x", 1)
	enemy_label.add_theme_constant_override("shadow_offset_y", 1)
	enemy_label.text = "ENEMIES: 0/3"
	ui_canvas.add_child(enemy_label)
	
	room_label = Label.new()
	room_label.position = Vector2(450, 35)
	room_label.add_theme_font_size_override("font_size", 18)
	room_label.add_theme_color_override("font_color", Color.WHITE)
	room_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	room_label.add_theme_constant_override("shadow_offset_x", 1)
	room_label.add_theme_constant_override("shadow_offset_y", 1)
	room_label.text = "ROOM: 1/21"
	ui_canvas.add_child(room_label)
	
	var battery_label = Label.new()
	battery_label.name = "BatteryLabel"
	battery_label.position = Vector2(450, 55)
	battery_label.add_theme_font_size_override("font_size", 16)
	battery_label.add_theme_color_override("font_color", Color.GREEN)
	battery_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	battery_label.add_theme_constant_override("shadow_offset_x", 1)
	battery_label.add_theme_constant_override("shadow_offset_y", 1)
	battery_label.text = "BATTERY: 100%"
	ui_canvas.add_child(battery_label)
	
	
	battery_sprite = AnimatedSprite2D.new()
	battery_sprite.name = "BatterySprite"
	battery_sprite.position = Vector2(380, 50)
	battery_sprite.scale = Vector2(2, 2)
	ui_canvas.add_child(battery_sprite)

func setup_enemy_manager() -> void:
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
			if not enemy.enemy_died.is_connected(_on_enemy_died):
				enemy.connect("enemy_died", _on_enemy_died)

func _on_enemy_died():
	enemies_alive -= 1
	
	if enemies_alive <= 0:
		all_enemies_defeated.emit()

func are_all_enemies_dead() -> bool:
	return enemies_alive <= 0
"""
	var enemy_script = GDScript.new()
	enemy_script.source_code = script_text
	enemy_manager.set_script(enemy_script)

func start_game() -> void:
	is_game_active = true
	current_room = 1
	game_time = max_time
	enemies_defeated_this_room = 0
	
	player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	load_room(current_room)

func load_room(room_number: int) -> void:
	if current_room_node:
		current_room_node.queue_free()
		await get_tree().process_frame
	
	var room_scene_path = "res://Rooms/Room #%d.tscn" % room_number
	
	if not ResourceLoader.exists(room_scene_path):
		create_simple_fallback_room()
		return
	
	var room_scene = load(room_scene_path)
	current_room_node = room_scene.instantiate()
	current_room_node.name = "CurrentRoom"
	add_child(current_room_node)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	if room_number == 21:
		hide_ui_for_cutscene()
	else:
		show_ui_for_gameplay()
		count_enemies_in_room()
		setup_room_exit()
		reset_player_to_room_start()
	
	update_ui()

func hide_ui_for_cutscene() -> void:
	if ui_canvas:
		ui_canvas.visible = false

func show_ui_for_gameplay() -> void:
	if ui_canvas:
		ui_canvas.visible = true

func create_simple_fallback_room() -> void:
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

func count_enemies_in_room() -> void:
	var custom_enemy_requirements = {
		1: 1, 2: 3, 3: 4, 4: 5, 5: 6,
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

func setup_room_exit() -> void:
	var exits = get_tree().get_nodes_in_group("room_exits")
	for exit in exits:
		if current_room_node.is_ancestor_of(exit) and exit is Area2D:
			if not exit.body_entered.is_connected(_on_room_exit_entered):
				exit.body_entered.connect(_on_room_exit_entered)

func reset_player_to_room_start() -> void:
	var spawn_points = get_tree().get_nodes_in_group("player_spawn")
	
	if player and spawn_points.size() > 0:
		var spawn_pos = spawn_points[0].global_position
		
		if player.has_method("teleport_to_position"):
			player.teleport_to_position(spawn_pos)
		else:
			player.global_position = spawn_pos
			player.velocity = Vector2.ZERO
		
		if player.has_method("reset_player_state"):
			player.reset_player_state()

func _on_room_exit_entered(body) -> void:
	if not body:
		return
		
	if not body.is_in_group("player"):
		return
	
	if not all_enemies_defeated():
		flash_enemy_counter()
		return
	
	advance_to_next_room()

func get_remaining_enemy_count() -> int:
	var remaining = 0
	var enemies = get_tree().get_nodes_in_group("enemies")
	if not enemies:
		return 0
		
	for enemy in enemies:
		if enemy and is_instance_valid(enemy) and current_room_node and current_room_node.is_ancestor_of(enemy):
			remaining += 1
	return remaining

func all_enemies_defeated() -> bool:
	var remaining = get_remaining_enemy_count()
	return remaining == 0

func on_enemy_defeated() -> void:
	enemies_defeated_this_room += 1
	var remaining = get_remaining_enemy_count()
	
	if all_enemies_defeated():
		flash_success_message()
	
	update_ui()

func flash_enemy_counter() -> void:
	if enemy_label and is_instance_valid(enemy_label):
		var tween = create_tween()
		tween.tween_property(enemy_label, "modulate", Color.RED, 0.2)
		tween.tween_property(enemy_label, "modulate", Color.WHITE, 0.3)

func flash_success_message() -> void:
	if enemy_label and is_instance_valid(enemy_label):
		var tween = create_tween()
		tween.tween_property(enemy_label, "modulate", Color.GREEN, 0.2)
		tween.tween_property(enemy_label, "modulate", Color.WHITE, 0.5)

func advance_to_next_room() -> void:
	if current_room >= total_rooms:
		complete_game()
		return
	
	current_room += 1
	load_room(current_room)

func complete_game() -> void:
	is_game_active = false
	show_ui_for_gameplay()
	
	if time_label and is_instance_valid(time_label):
		time_label.text = "MISSION COMPLETE!"
	if enemy_label and is_instance_valid(enemy_label):
		enemy_label.text = "MASTER RESCUED!"
	if room_label and is_instance_valid(room_label):
		room_label.text = "HERO!"
	
	if time_label and is_instance_valid(time_label):
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(time_label, "modulate", Color.GOLD, 0.5)
		tween.tween_property(time_label, "modulate", Color.WHITE, 0.5)

func get_battery_percentage() -> float:
	if max_time <= 0:
		return 0.0
	return game_time / max_time

func is_ability_available(ability_type: String) -> bool:
	var battery_percent = get_battery_percentage()
	
	match ability_type:
		"attack":
			return true
		"shield": 
			return battery_percent > 0.25
		"powerup":
			return battery_percent > 0.50
		"area_attack":
			return battery_percent > 0.10
		_:
			return true

func apply_time_penalty(penalty_type: String) -> void:
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

func flash_timer_red() -> void:
	if time_label and is_instance_valid(time_label):
		var tween = create_tween()
		tween.tween_property(time_label, "modulate", Color.RED, 0.1)
		tween.tween_property(time_label, "modulate", Color.WHITE, 0.3)

func game_over() -> void:
	is_game_active = false
	show_ui_for_gameplay()
	
	if time_label and is_instance_valid(time_label):
		time_label.text = "GAME OVER!"
	if enemy_label and is_instance_valid(enemy_label):
		enemy_label.text = "TIME'S UP!"
	if room_label and is_instance_valid(room_label):
		room_label.text = "RESTART"
		
	await get_tree().create_timer(3.0).timeout
	start_game()

func _process(delta) -> void:
	if is_game_active:
		game_time -= delta
		
		if game_time <= 0:
			game_over()
		else:
			update_ui()

func update_ui() -> void:
	if not ui_canvas or not ui_canvas.visible:
		return
		
	var minutes = int(game_time) / 60
	var seconds = int(game_time) % 60
	
	time_label.text = "TIME: %02d:%02d" % [minutes, seconds]
	
	var time_percentage = game_time / max_time
	if time_percentage > 0.5:
		time_label.add_theme_color_override("font_color", Color.CYAN)
	elif time_percentage > 0.25:
		time_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		time_label.add_theme_color_override("font_color", Color.RED)
	
	var remaining_enemies = get_remaining_enemy_count()
	var defeated_enemies = required_enemies_this_room - remaining_enemies
	enemy_label.text = "ENEMIES: %d/%d" % [defeated_enemies, required_enemies_this_room]
	
	if defeated_enemies >= required_enemies_this_room:
		enemy_label.add_theme_color_override("font_color", Color.LIME)
	else:
		enemy_label.add_theme_color_override("font_color", Color.YELLOW)
	
	room_label.text = "ROOM: %d/21" % current_room
	
	var battery_percent = get_battery_percentage() * 100
	var battery_label = ui_canvas.get_node_or_null("BatteryLabel")
	if battery_label:
		battery_label.text = "BATTERY: %.0f%%" % battery_percent
		
		if battery_percent > 50:
			battery_label.add_theme_color_override("font_color", Color.GREEN)
		elif battery_percent > 25:
			battery_label.add_theme_color_override("font_color", Color.YELLOW)
		elif battery_percent > 10:
			battery_label.add_theme_color_override("font_color", Color.ORANGE)
		else:
			battery_label.add_theme_color_override("font_color", Color.RED)
	
	var ability_label = ui_canvas.get_node_or_null("AbilityLabel")
	if ability_label:
		var available_abilities = []
		var lost_abilities = []
		
		if is_ability_available("attack"):
			available_abilities.append("F")
			
		if is_ability_available("shield"):
			available_abilities.append("E")
		else:
			lost_abilities.append("E")
			
		if is_ability_available("powerup"):
			available_abilities.append("G")
		else:
			lost_abilities.append("G")
			
		if is_ability_available("area_attack"):
			available_abilities.append("R")
		else:
			lost_abilities.append("R")
		
		var status_text = ""
		if available_abilities.size() > 0:
			status_text += "-".join(available_abilities) + " READY"
		if lost_abilities.size() > 0:
			if status_text != "":
				status_text += " | "
			status_text += "❌" + "-".join(lost_abilities)
		
		if status_text == "":
			status_text = "❌ ALL ABILITIES LOST"
		
		ability_label.text = status_text
		
		if lost_abilities.size() == 0:
			ability_label.add_theme_color_override("font_color", Color.LIME)
		elif available_abilities.size() > 0:
			ability_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			ability_label.add_theme_color_override("font_color", Color.RED)
	
	update_battery_display()

func update_battery_display() -> void:
	if not battery_sprite:
		return
	
	var time_percentage = game_time / max_time
	
	if battery_sprite.sprite_frames and battery_sprite.sprite_frames.has_animation("battery_drain"):
		var total_frames = battery_sprite.sprite_frames.get_frame_count("battery_drain")
		if total_frames > 0:
			var frame_index = int((1.0 - time_percentage) * (total_frames - 1))
			frame_index = clamp(frame_index, 0, total_frames - 1)
			
			if battery_sprite.animation != "battery_drain":
				battery_sprite.play("battery_drain")
			
			battery_sprite.pause()
			battery_sprite.frame = frame_index
			
