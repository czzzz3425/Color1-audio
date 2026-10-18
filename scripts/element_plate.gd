class_name ElementPlate
extends Area2D
## 元素踏板：检测「压在本踏板上的对象」携带什么元素状态，按状态变色 + 发信号。
##
## 是「元素状态传感器」——把任何携带元素的 colorable 对象（燃烧木头 / 冰块 / 缠藤物）
## 变成触发器。与元素阀互补：阀是「附近 heat_source 范围扫描」，踏板是「接触检测 + 三色识别」。
##
## 涌现：把燃烧物推到踏板上 → 踏板识别 burn → 连接的门打开（「搬运元素状态压机关」）；
## 冻结物压踏板 → 识别 freeze → 接另一条路。元素状态成了「砝码」。
##
## 检测对象：CharacterBody2D（可推木头，动态触发 body_entered）或 StaticBody2D（冰块，
## 初始重叠即触发）。collision_mask 设层 2+3 以覆盖障碍/箱子。

const Rules := preload("res://scripts/element/element_rules.gd")

@export_group("视觉")
@export var idle_color := Color(0.3, 0.3, 0.32)
@export var burn_color := Color(1.0, 0.3, 0.3)
@export var freeze_color := Color(0.3, 0.55, 1.0)
@export var grow_color := Color(0.35, 0.85, 0.4)
@export var cyan_color := Color(0.3, 0.9, 0.95)
@export var yellow_color := Color(1.0, 0.85, 0.2)

@onready var visual: Sprite2D = $Visual
@onready var collision_shape: CollisionShape2D = $Collision

var _occupants: Array = []   # 压在踏板上的 colorable 对象
var _last_element := ""

signal element_changed(element_id: String)


func _ready() -> void:
	_refresh()


func _physics_process(_delta: float) -> void:
	# 每帧几何扫描：不用 body_entered，因为 StaticBody2D 被 tween/瞬移（青色移动）后
	# 物理引擎不会更新碰撞对，body_entered 会漏检。这里直接按世界矩形判断压在板上的对象。
	_rebuild_occupants()
	# 轮询：踩踏对象的元素可能被蔓延 / 相生改变（如踏板上的燃烧木被蓝打到熄火），
	# 只在状态真的变化时才发信号，避免每帧空发。
	var el := detected_element()
	if el != _last_element:
		_last_element = el
		_apply_visual(el)
		element_changed.emit(el)


## 重建压板对象：遍历 colorable 组，把「携带元素状态且中心落在踏板矩形内」的对象记下来。
func _rebuild_occupants() -> void:
	_occupants.clear()
	var rect := _plate_rect()
	for obj in get_tree().get_nodes_in_group("colorable"):
		if not GameState.is_in_current_scene(obj):
			continue
		if not (obj is Node2D):
			continue
		if not _is_element_carrier(obj):
			continue
		if rect.has_point((obj as Node2D).global_position):
			_occupants.append(obj)


## 踏板的世界矩形（按 Collision 的 RectangleShape2D 尺寸）。
func _plate_rect() -> Rect2:
	var half := Vector2(48, 48)
	if collision_shape != null and collision_shape.shape is RectangleShape2D:
		half = (collision_shape.shape as RectangleShape2D).size * 0.5
	return Rect2(global_position - half, half * 2)


## 是否携带元素状态的对象（有 current_element / 在 heat_source 组）。
## 玩家本身没有元素状态，不会被认成触发器（玩家是种子的持有者，不是载体）。
func _is_element_carrier(body: Node) -> bool:
	if body.has_method("current_element"):
		return true
	if body.is_in_group("heat_source"):
		return true
	return false


## 当前踩踏对象的最强元素状态（burn / freeze / grow / ""）。
func detected_element() -> String:
	for obj in _occupants:
		if not is_instance_valid(obj):
			continue
		if obj.has_method("current_element"):
			var el: String = obj.call("current_element")
			if el != "":
				return el
		if obj.is_in_group("heat_source"):
			return "burn"
	return ""


func _refresh() -> void:
	_last_element = detected_element()
	_apply_visual(_last_element)
	element_changed.emit(_last_element)


func _apply_visual(el: String) -> void:
	if visual == null:
		return
	var c: Color = idle_color
	if el == "burn":
		c = burn_color
	elif el == "freeze":
		c = freeze_color
	elif el == "grow":
		c = grow_color
	elif el == "cyan":
		c = cyan_color
	elif el == "yellow":
		c = yellow_color
	visual.self_modulate = c
