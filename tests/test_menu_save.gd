extends SceneTree
## Run with APPDATA pointing inside .godot/menu-save-test-user; never touches real saves.
var GameState: Node
var SceneManager: Node

func _initialize() -> void:
	_run.call_deferred()

func _menu() -> Node:
	for child in current_scene.get_children():
		if child.get_script() == load("res://scripts/main_menu.gd"):
			return child
	return null

func _boot() -> void:
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game

func _run() -> void:
	GameState = root.get_node("GameState")
	SceneManager = root.get_node("SceneManager")
	assert(OS.get_user_data_dir().replace("\\", "/").contains(".godot/menu-save-test-user"), "Use an isolated APPDATA directory")
	GameState.new_game()
	_boot()
	await create_timer(1.5).timeout
	assert(paused and _menu()._continue.disabled)
	assert(SceneManager.current_room_scene == current_scene.start_room)
	_menu()._toggle_settings()
	assert(_menu()._settings.visible and not _menu()._continue.visible)
	_menu()._toggle_settings()
	assert(not _menu()._settings.visible and _menu()._continue.visible)
	_menu()._begin()
	await create_timer(3.2).timeout
	assert(not paused and _menu() == null)
	# Seed a real checkpoint save in the next level, including player-specific state.
	GameState.keys["menu_test_key"] = true
	GameState.elements = {"burn": 2, "freeze": 1}
	GameState.health_upgrades = {"menu_test_heart": 1}
	GameState.opened_gates["menu_test_gate"] = true
	GameState.set_checkpoint("res://scenes/level_2.tscn", Vector2(-5202, -19165))
	var saved_text := FileAccess.get_file_as_string(GameState.SAVE_PATH)
	assert(reload_current_scene() == OK)
	await create_timer(1.5).timeout
	assert(paused and not _menu()._continue.disabled)
	assert(SceneManager.current_room_scene == "res://scenes/level_2.tscn")
	assert(current_scene.player.global_position == Vector2(-5202, -19165))
	assert(int(current_scene.player.palette_snapshot().inventory.get("burn", 0)) == 2)
	assert(int(current_scene.player.palette_snapshot().inventory.get("freeze", 0)) == 1)
	assert(current_scene.player.max_health == 2)
	assert(saved_text == FileAccess.get_file_as_string(GameState.SAVE_PATH), "Preview must not write save")
	_menu()._continue_game()
	await create_timer(3.2).timeout
	assert(not paused and _menu() == null)
	assert(SceneManager.current_room_scene == "res://scenes/level_2.tscn")
	assert(GameState.keys.has("menu_test_key") and GameState.opened_gates.has("menu_test_gate"))
	assert(int(current_scene.player.palette_snapshot().inventory.get("burn", 0)) == 2)
	assert(int(current_scene.player.palette_snapshot().inventory.get("freeze", 0)) == 1)
	# Returning to menu and cancelling a new game must preserve disk progress.
	saved_text = FileAccess.get_file_as_string(GameState.SAVE_PATH)
	assert(reload_current_scene() == OK)
	await create_timer(1.5).timeout
	_menu()._begin()
	assert(_menu()._new_game_prompt.visible)
	assert(saved_text == FileAccess.get_file_as_string(GameState.SAVE_PATH))
	_menu()._show_new_game_prompt(false)
	assert(_menu()._continue.visible and _menu()._start.visible)
	_menu()._request_session("new")
	await create_timer(3.2).timeout
	assert(not paused and _menu() == null)
	assert(SceneManager.current_room_scene == current_scene.start_room)
	assert(GameState.keys.is_empty() and GameState.elements.is_empty())
	assert(current_scene.player.max_health == 1)
	assert(not GameState.has_save_file())
	# A malformed or stale save must not crash or enable Continue.
	for broken in ['{"checkpoint_scene":"res://scenes/level_2.tscn","checkpoint_pos":[]}', '{"checkpoint_scene":"res://missing.tscn","checkpoint_pos":[0,0]}', 'not json']:
		var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
		file.store_string(broken)
		file.close()
		assert(not GameState.has_valid_save())
		assert(not GameState.continue_game())
	assert(reload_current_scene() == OK)
	await create_timer(1.5).timeout
	assert(paused and _menu()._continue.disabled)
	assert(SceneManager.current_room_scene == current_scene.start_room)
	GameState.new_game()
	print("MENU_SAVE_OK: no-save, preview, continue, inventory/health, confirmation, new-game reset, invalid save")
	quit()
