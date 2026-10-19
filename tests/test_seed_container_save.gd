extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	assert(OS.get_user_data_dir().replace("\\", "/").contains(".godot/menu-save-test-user"))
	var state: Node = root.get_node("GameState")
	state.new_game()
	state.companion_recruited = true
	var game: Node = load("res://scenes/game.tscn").instantiate()
	game.show_main_menu = false
	game.start_room = "res://scenes/level_3.tscn"
	root.add_child(game)
	current_scene = game
	await create_timer(0.8).timeout
	var manager: Node = root.get_node("SceneManager")
	var container: Node = manager.current_room.get_node("SeedContainer")
	var initial := int(container.save_state().store.grow)
	var info: Dictionary = container.absorb_color()
	game.player.receive_element(info.element, 1)
	var remaining := int(container.save_state().store.grow)
	state.set_checkpoint("res://scenes/level_3.tscn", game.player.global_position)
	assert(reload_current_scene() == OK)
	await create_timer(1.2).timeout
	container = manager.current_room.get_node("SeedContainer")
	var restored := int(container.save_state().store.grow)
	print("SEED_SAVE_REPRO initial=", initial, " before_save=", remaining, " after_load=", restored, " retained_in_inventory=", current_scene.player.palette_snapshot().inventory)
	assert(initial == 5 and remaining == 4 and restored == remaining)
	assert(int(current_scene.player.palette_snapshot().inventory.grow) == 1)
	print("SEED_CONTAINER_SAVE_OK: no refilling finite containers after continue")
	state.new_game()
	quit()
