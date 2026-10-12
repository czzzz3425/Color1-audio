class_name ElementValve
extends StaticBody2D
## 元素阀：火驱动的升降闸门。附近有「热源」（燃烧物 / 火种 / 焰虱追击红光）就开，没有就关。
##
## 多源开门是自动涌现的——任何 heat_source 组里的节点靠近都能开（燃烧木束、余烬、焰虱），
## 不写死「玩家触发」。开门的那个火本身还发光，所以「点火开门」= 把焰虱引到门口（火的代价）。
##
## 蓝(freeze) → 冻结锁定当前开/关状态（忽略热源，直到被吸收蓝解锁）。
## 吸收蓝 → 解锁（恢复随热源开关）。绿（生长）搁置，预留「藤蔓封锁」位。
## 红直接上色无效——阀不是燃料，喂火要用「附近热源」而不是点它。
##
## 需要子节点：Visual（门贴图 CanvasItem）、Collision（CollisionShape2D，阻挡玩家）。
## ⚠️ 不要定义 is_frozen()（player._water_at_mouse 会误判成水格崩溃）。

const Rules := preload("res://scripts/element/element_rules.gd")

@export_group("热感应")
@export var heat_radius: float = 220.0

@export_group("视觉")
@export var closed_color := Color(0.85, 0.65, 0.25)   # 关着（等火来）
@export var open_color := Color(0.55, 0.55, 0.55)     # 开着（有热源）
@export var frozen_color := Color(0.4, 0.65, 1.0)     # 冻结（锁状态）
@export var hit_radius: float = 64.0

@export_group("状态")
@export var valve_id: String = ""
@export var starts_open := false
@export var state_id: String = ""

@onready var visual: CanvasItem = get_node_or_null("Visual") as CanvasItem
@onready var collision: CollisionShape2D = get_node_or_null("Collision") as CollisionShape2D

var _open := false
var _frozen := false


func _ready() -> void:
	add_to_group("colorable")
	add_to_group("stateful")
	if valve_id == "":
		valve_id = name
	if state_id == "":
		state_id = valve_id
	collision_layer = 2   # 挡玩家（玩家 collision_mask 含层 2）
	collision_mask = 0
	_open = starts_open
	_apply()


func _physics_process(_delta: float) -> void:
	if _frozen:
		return   # 冻结：锁当前状态，不随热源变化
	var want := _heat_nearby()
	if want != _open:
		_open = want
		_apply()


func _heat_nearby() -> bool:
	for src in get_tree().get_nodes_in_group("heat_source"):
		if not GameState.is_in_current_scene(src):
			continue
		var n := src as Node2D
		if n == null or not is_instance_valid(n):
			continue
		if global_position.distance_to(n.global_position) <= heat_radius:
			return true
	return false


## 开/关 = 取消/恢复碰撞 + 换色。用 tween 让切换有过渡。
func _apply() -> void:
	if collision != null:
		collision.set_deferred("disabled", _open)
	if visual != null:
		var c: Color = frozen_color if _frozen else (open_color if _open else closed_color)
		var t := create_tween()
		t.tween_property(visual, "modulate", c, 0.2)


# —— colorable 契约（只认蓝冻结 / 吸收蓝解锁）——
func apply_color(_c: Color, color_name: String = "", _from_pos: Vector2 = Vector2.INF) -> bool:
	var element := Rules.element_for_color_name(color_name)
	if element == "freeze":
		if _frozen:
			return false   # 已冻结，重复给不耗种子
		_frozen = true
		_apply()
		return true
	return false   # 红/其它：阀不是燃料，喂火要用「附近热源」，直接上色无效


func absorb_color() -> Dictionary:
	if not _frozen:
		return {"element": "", "color": Color.WHITE, "color_name": ""}
	_frozen = false
	_apply()
	return {
		"element": "freeze",
		"color": Rules.config("freeze")["color"],
		"color_name": Rules.config("freeze")["color_name"],
		"amount": 1,
	}


func has_color() -> bool:
	return _frozen


func contains_point(world_pos: Vector2) -> bool:
	if visual is Polygon2D:
		var poly := (visual as Polygon2D).polygon
		if not poly.is_empty():
			var mn := poly[0]
			var mx := poly[0]
			for p in poly:
				mn = mn.min(p)
				mx = mx.max(p)
			return Rect2(mn, mx - mn).has_point(to_local(world_pos))
	return global_position.distance_to(world_pos) <= hit_radius


# —— 状态持久化 ——
func save_state() -> Dictionary:
	return {"open": _open, "frozen": _frozen}


func restore_state(data: Dictionary) -> void:
	_open = data.get("open", starts_open)
	_frozen = data.get("frozen", false)
	_apply()
