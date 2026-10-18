extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _gate(direction: Vector2) -> Node2D:
	var gate: Node2D = load("res://prefabs/rooms/one_way_gate.tscn").instantiate()
	gate.name = "TestGate"
	gate.pass_dir = direction
	gate.scale = Vector2(0.35, 0.35)
	root.add_child(gate)
	return gate

func _run() -> void:
	var state: Node = root.get_node("GameState")
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		state.reset()
		var gate := _gate(direction)
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
		var center: Vector2 = gate.collision.global_position
		# Forbidden side stays blocked even after sustained contact.
		body.global_position = center + direction * 500.0
		for frame in 130:
			await physics_frame
			body.velocity = -direction * 450.0
			body.move_and_slide()
		assert(not gate._open and gate.visual.visible)
		assert((body.global_position - center).dot(direction) > 0.0)
		# Merely being on the allowed side must not open the gate.
		body.global_position = center - direction * 500.0
		body.velocity = Vector2.ZERO
		body.move_and_slide()
		await physics_frame
		assert(not gate._open)
		for frame in 130:
			await physics_frame
			body.velocity = direction * 450.0
			body.move_and_slide()
			if gate._open:
				break
		assert(gate._open and not gate.visual.visible)
		await process_frame
		assert(gate.collision.disabled)
		assert(state.is_gate_opened(gate._progress_key))
		# Returning from the formerly forbidden side must not close it again.
		body.global_position = center + direction * 300.0
		for frame in 100:
			await physics_frame
			body.velocity = -direction * 450.0
			body.move_and_slide()
		assert((body.global_position - center).dot(direction) < -100)
		assert(gate._open)
		body.free()
		gate.free()
		var restored := _gate(direction)
		assert(restored._open and not restored.visual.visible)
		restored.free()
	state.reset()
	# The placed level1 gate uses Sprite2D instead of Visual; it must disappear too.
	var level: Node = load("res://scenes/level_1.tscn").instantiate()
	var placed: Node = level.get_node("OneWayGate")
	var original_size: Vector2 = placed.get_node("Collision").shape.size
	level.remove_child(placed)
	level.free()
	root.add_child(placed)
	assert(placed.visual != null and placed.collision.shape.size == original_size)
	placed.open()
	assert(not placed.visual.visible)
	placed.free()
	print("ONE_WAY_GATE_OK: four directions, blocked side, contact-only unlock, disappears, return passage, persistence, level1 art")
	quit()
