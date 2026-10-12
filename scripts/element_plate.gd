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

@onready var visual: Polygon2D = $Visual

var _occupants: Array = []   # 压在踏板上的 colorable 对象
var _last_element := ""

signal element_changed(element_id: String)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh()


func _physics_process(_delta: float) -> void:
	# 轮询：踩踏对象的元素可能被蔓延 / 相生改变（如踏板上的燃烧木被蓝打到熄火），
	# 只在状态真的变化时才发信号，避免每帧空发。
	var el := detected_element()
	if el != _last_element:
		_last_element = el
		_apply_visual(el)
		element_changed.emit(el)


func _on_body_entered(body: Node) -> void:
	if not _is_element_carrier(body):
		return
	if body not in _occupants:
		_occupants.append(body)
		_refresh()


func _on_body_exited(body: Node) -> void:
	if body in _occupants:
		_occupants.erase(body)
		_refresh()


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
	visual.color = c
