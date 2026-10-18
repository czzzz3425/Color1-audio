extends SceneTree

class Target extends Node2D:
	var paints := 0
	var absorbs := 0
	var accepts := true
	var colored := true
	var multi := false
	var receiver: Node
	var on_apply: Callable
	func apply_color(_color: Color, _name: String, _source: Vector2) -> bool:
		paints += 1
		if on_apply.is_valid(): on_apply.call()
		return accepts
	func has_color() -> bool: return colored
	func absorb_color() -> Dictionary:
		absorbs += 1
		colored = false
		if multi:
			receiver.refund_element("freeze", 1)
			receiver.refund_element("grow", 1)
			return {"element": ""}
		return {"element": "freeze", "amount": 1}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(OS.get_user_data_dir().replace("\\", "/").contains(".godot/menu-save-test-user"))
	var game_state: Node = root.get_node("GameState")
	game_state.reset()
	game_state.companion_recruited = true
	var player: Node = load("res://scenes/player.tscn").instantiate()
	player.set_script(load("res://tests/fixtures/paint_test_player.gd"))
	root.add_child(player)
	player.set_physics_process(false)
	var companion: Node = load("res://prefabs/creatures/companion.tscn").instantiate()
	root.add_child(companion)
	companion.restore_following()
	var first := Target.new()
	var replaced := Target.new()
	var next := Target.new()
	root.add_child(first)
	root.add_child(replaced)
	root.add_child(next)
	first.position = Vector2(600, 0)
	replaced.position = Vector2(500, 200)
	next.position = Vector2(700, 100)
	player.receive_element("burn", 6)
	player.test_target = first
	player._grant()
	assert(first.paints == 0 and companion._phase == "fly")
	assert(not companion._task.is_empty() and is_instance_valid(companion._task.marker))
	player.test_target = replaced
	player._grant()
	player.test_target = next
	player._grant()
	assert(int(player.palette_snapshot().inventory.burn) == 4, "Replaced order must refund its reservation")
	assert(companion._pending.target.get_ref() == next)
	# Saving while both orders are in flight retains unspent seeds on disk.
	game_state.set_checkpoint("res://scenes/level_1.tscn", Vector2.ZERO)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game_state.SAVE_PATH))
	assert(int(saved.elements.burn) == 6)
	await create_timer(0.65).timeout
	assert(first.paints == 1 and replaced.paints == 0)
	assert(companion._task.target.get_ref() == next, "Next order must begin before any return flight")
	await create_timer(0.6).timeout
	assert(next.paints == 1 and companion._phase == "linger")
	assert(companion.global_position.distance_to(next.global_position) < 2)
	# Absorption can start during lingering, credits immediately after its work gesture.
	player.test_target = first
	player._absorb()
	assert(first.absorbs == 0 and not player.palette_snapshot().inventory.has("freeze"))
	await create_timer(0.65).timeout
	assert(first.absorbs == 1 and int(player.palette_snapshot().inventory.freeze) == 1)
	assert(companion._phase == "linger")
	# It can now use that color locally without first returning to the player.
	player.test_target = next
	player._grant()
	await create_timer(0.55).timeout
	assert(next.paints == 2)
	# A vanished active target refunds exactly once, as does a cancelled next order.
	companion.cancel_orders()
	player._select_element("burn")
	var doomed := Target.new()
	root.add_child(doomed)
	doomed.position = Vector2(800, 0)
	var before := int(player.palette_snapshot().inventory.burn)
	player.test_target = doomed
	player._grant()
	doomed.free()
	await create_timer(0.7).timeout
	assert(int(player.palette_snapshot().inventory.burn) == before)
	next.accepts = false
	player.test_target = next
	player._grant()
	await create_timer(0.6).timeout
	assert(int(player.palette_snapshot().inventory.burn) == before)
	next.accepts = true
	player.test_target = first
	player._grant()
	player.test_target = next
	player._grant()
	companion.cancel_orders()
	assert(int(player.palette_snapshot().inventory.burn) == before)
	assert(companion._pending.is_empty() and companion._task.is_empty())
	# Multi-element donors return through their own callback; no duplicate credit.
	var blend := Target.new()
	blend.multi = true
	blend.receiver = player
	root.add_child(blend)
	player.test_target = blend
	player._absorb()
	await create_timer(0.7).timeout
	assert(int(player.palette_snapshot().inventory.freeze) == 1)
	assert(int(player.palette_snapshot().inventory.grow) == 1)
	await create_timer(1.3).timeout
	assert(companion.is_available())
	game_state.new_game()
	print("COMPANION_ORDERS_OK: arrival timing, one-slot replacement, direct chaining, absorb credit, reservations, refunds, save safety, return")
	quit()
