extends Control
## 对话框之外的双人立绘舞台。每侧保留一人，当前说话者提亮并轻轻呼吸。

@export_range(0.1, 1.0, 0.05) var enter_duration := 0.48
@export_range(0.1, 1.0, 0.05) var exit_duration := 0.22

var _slots: Array[TextureRect] = []
var _configs: Array[CharacterPortrait] = [null, null]
var _motions: Array[Tween] = [null, null]
var _breaths: Array[Tween] = [null, null]
var _active_side := -1


func _ready() -> void:
	for side in range(2):
		var slot := TextureRect.new()
		slot.name = "LeftPortrait" if side == 0 else "RightPortrait"
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.hide()
		add_child(slot)
		_slots.append(slot)
	resized.connect(_on_resized)


func show_character(config: CharacterPortrait) -> void:
	if config == null or config.portrait == null:
		_active_side = -1
		for side in range(2):
			_hide_slot(side)
		return
	var side := clampi(config.side, 0, 1)
	var changed := _configs[side] != config or not _slots[side].visible
	var speaker_changed := _active_side != side
	_active_side = side
	if changed:
		_stop_tweens(side)
		_configs[side] = config
		var slot := _slots[side]
		slot.texture = config.portrait
		slot.flip_h = config.flip_h
		_layout_slot(side)
		var destination := slot.position
		slot.position.x = -slot.size.x - 24.0 if side == 0 else size.x + 24.0
		slot.scale = Vector2(0.96, 1.04)
		slot.modulate = Color(1, 1, 1, 0)
		slot.show()
		var tween := create_tween().set_parallel(true)
		_motions[side] = tween
		tween.tween_property(slot, "position", destination, enter_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(slot, "scale", Vector2.ONE, enter_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(slot, "modulate", Color.WHITE, enter_duration * 0.6)
		tween.chain().tween_callback(_start_breath.bind(side))
	elif speaker_changed:
		_stop_tweens(side)
		_layout_slot(side)
		var tween := create_tween()
		_motions[side] = tween
		tween.tween_property(_slots[side], "modulate", Color.WHITE, 0.18)
		tween.tween_callback(_start_breath.bind(side))
	# 对侧角色留在舞台上，降低亮度，避免轮流说话时重复进出。
	var other := 1 - side
	if _slots[other].visible and _configs[other] != null:
		_stop_tweens(other)
		_layout_slot(other)
		_motions[other] = create_tween()
		_motions[other].tween_property(_slots[other], "modulate", Color(0.65, 0.65, 0.7, 1), 0.18)


func _layout_slot(side: int) -> void:
	var config := _configs[side]
	if config == null:
		return
	var slot := _slots[side]
	slot.size = Vector2(size.x * 0.32, size.y * 0.92) * config.size_multiplier
	var center_x := size.x * (0.23 if side == 0 else 0.77)
	slot.position = Vector2(center_x - slot.size.x * 0.5, size.y - slot.size.y) + config.position_offset
	slot.pivot_offset = Vector2(slot.size.x * 0.5, slot.size.y)
	slot.scale = Vector2.ONE


func _start_breath(side: int) -> void:
	if _active_side != side or not _slots[side].visible:
		return
	var slot := _slots[side]
	var tween := create_tween().set_loops()
	_breaths[side] = tween
	tween.tween_property(slot, "scale", Vector2(1.008, 1.018), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(slot, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _hide_slot(side: int) -> void:
	_stop_tweens(side)
	_configs[side] = null
	var slot := _slots[side]
	if not slot.visible:
		return
	var destination := slot.position
	destination.x = -slot.size.x - 24.0 if side == 0 else size.x + 24.0
	var tween := create_tween().set_parallel(true)
	_motions[side] = tween
	tween.tween_property(slot, "position", destination, exit_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(slot, "modulate:a", 0.0, exit_duration)
	tween.chain().tween_callback(slot.hide)


func dismiss() -> void:
	_active_side = -1
	for side in range(2):
		_hide_slot(side)
	await get_tree().create_timer(exit_duration).timeout


func _stop_tweens(side: int) -> void:
	if _motions[side] != null:
		_motions[side].kill()
		_motions[side] = null
	if _breaths[side] != null:
		_breaths[side].kill()
		_breaths[side] = null


func _on_resized() -> void:
	for side in range(_slots.size()):
		_stop_tweens(side)
		if _configs[side] == null:
			_slots[side].hide()
			continue
		_layout_slot(side)
		_slots[side].modulate = Color.WHITE if side == _active_side else Color(0.65, 0.65, 0.7, 1)
		_start_breath(side)
