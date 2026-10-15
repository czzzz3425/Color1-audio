extends Node2D
## 弹反 + 黄色机制 演示 / 测试场景。
##
## 操作：
##   WASD / 方向键 移动，Shift 跑，Space 跳，R 旋转。
##   J / K / 鼠标中键 —— 弹反飞来的子弹（弹反成功后子弹变金、打回发射器）。
##   鼠标悬停白色物体：1 = 赋予红，2 = 赋予绿，3 = 吸收。
##
## 目标：
##   · 红 + 绿 赋予同一物体 → 物体变黄（HUD 显示状态）。
##   · 弹反 → 金色子弹飞回并击毁发射器。

const Rules := preload("res://scripts/element/element_rules.gd")

@export_range(128.0, 8192.0, 1.0) var interact_range := 3072.0

@onready var player: Node2D = $Player
@onready var info_label: Label = $HUD/Info
@onready var yellow_label: Label = $HUD/YellowStatus
@onready var parry_label: Label = $HUD/ParryStatus

var _selected := "burn"


func _ready() -> void:
	info_label.text = "【弹反】J / K / 鼠标中键；子弹变金并打回发射器\n【黄色】鼠标悬停物体：1=赋予红  2=赋予绿  3=吸收；红+绿 → 变黄，变黄后会自动反弹子弹\n【行走】两侧怪物沿直线往复行走，撞到中间方块/边界墙会折返；仍会朝玩家发射"
	for obj in get_tree().get_nodes_in_group("colorable"):
		if obj.has_signal("became_yellow"):
			obj.connect("became_yellow", _refresh_yellow)
			obj.connect("yellow_lost", _refresh_yellow)
			obj.connect("element_changed", _on_element_changed)
	var parry := player.get_node_or_null("Parry")
	if parry != null and parry.has_signal("state_changed"):
		parry.connect("state_changed", _on_parry_state)
	_refresh_yellow()
	_on_parry_state(false, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				_selected = "burn"
			KEY_2:
				_selected = "grow"
			KEY_3:
				_absorb_at_mouse()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_apply_at_mouse()


func _process(_delta: float) -> void:
	# 悬停反馈：让玩家知道鼠标下有什么可交互。
	var target := _colorable_at_mouse()
	if target != null:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _apply_at_mouse() -> void:
	var target := _colorable_at_mouse()
	if target == null or not target.has_method("apply_color"):
		return
	var cfg := Rules.config(_selected)
	target.call("apply_color", cfg.get("color", Color.WHITE), cfg.get("color_name", ""), player.global_position)
	_refresh_yellow()


func _absorb_at_mouse() -> void:
	var target := _colorable_at_mouse()
	if target == null or not target.has_method("absorb_color"):
		return
	target.call("absorb_color")
	_refresh_yellow()


## 鼠标下、工作圈内的 colorable 物体（重叠取 z_index 最高）。
func _colorable_at_mouse() -> Node:
	var mp := get_global_mouse_position()
	if player.global_position.distance_to(mp) > interact_range:
		return null
	var best: Node = null
	var best_z := -INF
	for obj in get_tree().get_nodes_in_group("colorable"):
		if not is_instance_valid(obj) or not obj.has_method("contains_point"):
			continue
		if not bool(obj.call("contains_point", mp)):
			continue
		var z := float(obj.get("z_index"))
		if z >= best_z:
			best_z = z
			best = obj
	return best


func _refresh_yellow() -> void:
	var y := _first_yellow_object()
	if y == null:
		yellow_label.text = "黄色物体：未找到"
		return
	var els: Array = y.call("elements") if y.has_method("elements") else []
	var state := "未变黄"
	if y.has_method("is_yellow") and bool(y.call("is_yellow")):
		state = "已变黄 ✦"
	yellow_label.text = "黄色物体元素：%s    → %s" % [str(els), state]


func _first_yellow_object() -> Node:
	for obj in get_tree().get_nodes_in_group("colorable"):
		if is_instance_valid(obj) and obj.has_method("is_yellow"):
			return obj
	return null


func _on_element_changed(_element_id: String) -> void:
	_refresh_yellow()


func _on_parry_state(parrying: bool, ratio: float) -> void:
	if parrying:
		parry_label.text = "弹反：★ 生效中"
	elif ratio > 0.0:
		parry_label.text = "弹反：冷却 %.0f%%" % (ratio * 100.0)
	else:
		parry_label.text = "弹反：就绪"
