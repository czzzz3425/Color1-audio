extends SceneTree

var state: Node

func _initialize() -> void:
	_run.call_deferred()

func _door() -> Node2D:
	# 读取 level1 实际的门配置，不执行整关的拾取、剧情或存档点。
	var level: Node = load("res://scenes/level_1.tscn").instantiate()
	var door: Node2D = level.get_node("RoomDoor")
	level.remove_child(door)
	level.free()
	root.add_child(door)
	return door

func _run() -> void:
	state = root.get_node("GameState")
	for direction in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		state.reset()
		var door := _door()
		assert(door.required_key_id == "1")
		state.add_key("1")
		var body := CharacterBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 2
		body.add_to_group("player")
		var collision := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 18.0
		collision.shape = circle
		body.add_child(collision)
		root.add_child(body)
		var center: Vector2 = door.get_node("Collision").global_position
		body.global_position = center - direction * 850.0
		for frame in 240:
			await physics_frame
			body.velocity = direction * 450.0
			body.move_and_slide()
			if door.is_open:
				break
		assert(door.is_open, "Key holder could not reach trigger from %s" % direction)
		await process_frame
		assert(door.get_node("Collision").disabled)
		assert(not state.has_key("1") and state.was_key_used("1"))
		assert(state.is_gate_opened(door._progress_key))
		body.free()
		door.free()
		# 模拟只从 JSON 恢复全局解锁字典，没有房间临时状态。
		var restored := _door()
		restored.restore_state({})
		assert(restored.is_open)
		restored.free()
	state.reset()
	var locked := _door()
	var stranger := Node2D.new()
	stranger.add_to_group("player")
	root.add_child(stranger)
	locked._on_body_entered(stranger)
	assert(not locked.is_open)
	locked.free()
	stranger.free()
	state.used_keys["1"] = true
	var legacy := _door()
	legacy.restore_state({})
	assert(legacy.is_open)
	legacy.free()
	print("ROOM_DOOR_OK: real level1 door, four approach directions, key consumption, persisted/legacy unlock, no-key lock")
	quit()
