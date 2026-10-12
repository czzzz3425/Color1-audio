class_name ColdWisp
extends CharacterBody2D
## 寒灵（中立生物）：移动的冷源（freeze_source）——漂到哪，哪的水就结冰。
##
## 涌现载体：「会动的规则」——玩家用火（heat_source）驱赶它，把它赶到水面上，
## 它一边漂一边结冰，铺出冰桥。火 → 驱赶寒灵 → 冰铺路，是「热源驱冷源」的涌现链。
## 它是移动的 freeze_source，与焰虱（移动 heat_source）对称。
##
## 状态（用 _color 表达，与萤虫一致）：
##   "freeze" 默认——蓝光，漫游，经过水格自动结冰；附近有热源则远离（怕火）
##   ""       冷耗尽——蓝被吸走后，暂时不结冰（蓝光变暗），回充后恢复
##   "burn"   受热——被红打到，暂时静止、停止结冰（火压制冷源）
##
## 碰撞：collision_layer=0（不挡人）、collision_mask=0（自由漂，能越过深水去结冰）。
## ⚠️ 不要定义 is_frozen()（player._water_at_mouse 会误判成水格崩溃）。

const Rules := preload("res://scripts/element/element_rules.gd")

@export_group("移动")
@export var wander_speed: float = 60.0
@export var flee_speed: float = 160.0
@export var fear_radius: float = 400.0     # 热源驱赶半径
@export var wander_interval: float = 2.5
@export var wander_range: float = 120.0

@export_group("结冰")
@export var freeze_interval: float = 0.4   # 结冰扫描间隔
@export var recharge_time: float = 6.0     # 冷耗尽回充时长
@export var heat_cooldown: float = 3.0     # 受热（被红打）后恢复冷源的时长

@export_group("发光")
@export var light_radius: float = 320.0
@export var dim_glint: float = 70.0

@export_group("视觉")
@export var glow_color: Color = Color(0.5, 0.75, 1.0)
@export var dim_color: Color = Color(0.3, 0.35, 0.4)
@export var warm_color: Color = Color(1.0, 0.5, 0.4)
@export var hit_radius: float = 44.0

@onready var visual: Node2D = $Visual
@onready var light: LightSource = $Light

var _color: String = "freeze"
var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
var _freeze_cd: float = 0.0
var _recharge: float = 0.0
var _heat_cd: float = 0.0


func _ready() -> void:
	add_to_group("colorable")
	collision_layer = 0
	collision_mask = 0
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_new_wander_target()
	_refresh()


func _physics_process(delta: float) -> void:
	if _color == "freeze":
		_wander(delta)
		_freeze_cd = maxf(0.0, _freeze_cd - delta)
		if _freeze_cd <= 0.0:
			_freeze_cd = freeze_interval
			_freeze_water_under()
	elif _color == "":
		velocity = Vector2.ZERO
		_recharge += delta
		if _recharge >= recharge_time:
			_color = "freeze"
			_recharge = 0.0
			_refresh()
	elif _color == "burn":
		velocity = Vector2.ZERO
		_heat_cd -= delta
		if _heat_cd <= 0.0:
			_color = "freeze"
			_refresh()


## 漫游 + 怕火：附近有热源就往反方向逃。
func _wander(delta: float) -> void:
	var dir: Vector2 = global_position.direction_to(_wander_target)
	var fire := _nearest_heat()
	if fire != null:
		var away: Vector2 = global_position - fire.global_position
		if away.length() < 1.0:
			away = Vector2.from_angle(randf() * TAU)
		dir = (dir * 0.2 + away.normalized()).normalized()
		velocity = dir * flee_speed
	else:
		velocity = dir * wander_speed
	move_and_slide()
	if global_position.distance_to(_wander_target) < 24.0:
		_new_wander_target()
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_new_wander_target()


## 最近的燃火热源（怕火，驱赶方向）。
func _nearest_heat() -> Node2D:
	var best: Node2D = null
	var best_d := fear_radius
	for src in get_tree().get_nodes_in_group("heat_source"):
		var n := src as Node2D
		if n == null or not is_instance_valid(n):
			continue
		var d := global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


## 结冰脚下水格：找脚下的 WaterCell（有 is_frozen 的 colorable），未结冰则 apply 蓝。
func _freeze_water_under() -> void:
	for obj in get_tree().get_nodes_in_group("colorable"):
		if not is_instance_valid(obj):
			continue
		if not obj.has_method("is_frozen"):
			continue
		if bool(obj.call("is_frozen")):
			continue
		if not obj.has_method("contains_point"):
			continue
		if bool(obj.call("contains_point", global_position)):
			if obj.has_method("apply_color"):
				obj.call("apply_color", Color(0.3, 0.55, 1.0), "蓝", global_position)


func _new_wander_target() -> void:
	_wander_target = global_position + Vector2.from_angle(randf() * TAU) * randf_range(40.0, wander_range)
	_wander_timer = wander_interval * randf_range(0.7, 1.3)


# —— colorable 契约 ——
func has_color() -> bool:
	return _color != ""


func contains_point(world_pos: Vector2) -> bool:
	return global_position.distance_to(world_pos) <= hit_radius


func apply_color(_c: Color, color_name: String = "", _from_pos: Vector2 = Vector2.INF) -> bool:
	var element: String = Rules.element_for_color_name(color_name)
	# 给红 → 受热：暂时静止、停止结冰（火压制冷源）。
	if element == "burn" and _color != "burn":
		_color = "burn"
		_heat_cd = heat_cooldown
		_refresh()
		return true
	return false


func absorb_color() -> Dictionary:
	if _color != "freeze":
		return {"element": "", "color": Color.WHITE, "color_name": ""}
	_color = ""   # 冷耗尽：暂时不结冰，回充后恢复
	_recharge = 0.0
	_refresh()
	var cfg: Dictionary = Rules.config("freeze")
	return {
		"element": "freeze",
		"color": cfg.get("color", Color.WHITE),
		"color_name": cfg.get("color_name", ""),
		"amount": 1,
	}


func _refresh() -> void:
	if _color == "freeze":
		add_to_group("freeze_source")
	else:
		remove_from_group("freeze_source")
	if light != null:
		light.radius = light_radius if _color == "freeze" else dim_glint
		light.add_to_group("light_source")
	if visual != null:
		var tint: Color = dim_color
		if _color == "freeze":
			tint = glow_color
		elif _color == "burn":
			tint = warm_color
		visual.self_modulate = tint
