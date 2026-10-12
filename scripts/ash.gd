class_name Ash
extends Node2D
## 灰烬：红烧缠藤后的余烬堆——「绿 × 火 = 灰烬」的相生产物。
##
## 灰烬是藤的「有机」与火的「热」化合出的新实体，是元素转化的涌现节点：
##   · heat_source：余火未熄，能开元素阀 / 引焰虱（火从藤「转移」到了灰烬）。
##   · colorable：残留的火种可被吸收，返还 1 红（绿 → 烧 → 灰烬 → 吸红 的元素循环）。
##   · growth_source：死灰是肥料，未来「扫描生长源」的机关 / 绿生长会读它。
##
## 生命周期：出生时带余火（热源），lifetime 秒后冷却成死灰（不再发热、不可吸红），
## 但仍留作肥料。被吸收红色则当场散掉。
##
## ⚠️ 不要定义 is_frozen()（player._water_at_mouse 会误判成水格崩溃）。

const Rules := preload("res://scripts/element/element_rules.gd")

## 冷却成死灰的秒数（之后不再是热源）。
@export var lifetime := 8.0
## 点击吸收的判定半径。
@export var hit_radius := 40.0
## 带余火的颜色。
@export var ember_color := Color(0.85, 0.4, 0.2)
## 死灰颜色。
@export var ash_color := Color(0.55, 0.5, 0.45)

var _hot := true
var _visual: Polygon2D


func _ready() -> void:
	add_to_group("colorable")
	add_to_group("heat_source")
	add_to_group("growth_source")
	_visual = Polygon2D.new()
	_visual.name = "Visual"
	_visual.polygon = PackedVector2Array([
		Vector2(-14, -8), Vector2(14, -8), Vector2(14, 8), Vector2(-14, 8),
	])
	_visual.color = ember_color
	add_child(_visual)
	get_tree().create_timer(lifetime).timeout.connect(_cool)


## 冷却：余火熄灭，不再发热、不可吸红，但仍是肥料（growth_source）。
func _cool() -> void:
	if not _hot:
		return
	_hot = false
	remove_from_group("heat_source")
	if _visual != null:
		_visual.color = ash_color


func has_color() -> bool:
	return _hot


## 灰烬不可被上色（只能吸收残留火种），返回 false 不耗种子。
func apply_color(_c: Color, _color_name: String = "", _from_pos: Vector2 = Vector2.INF) -> bool:
	return false


## 吸收残留火种：返还 1 红，灰烬散掉。
func absorb_color() -> Dictionary:
	if not _hot:
		return {"element": "", "color": Color.WHITE, "color_name": ""}
	_hot = false
	queue_free()
	return {
		"element": "burn",
		"color": Rules.config("burn")["color"],
		"color_name": Rules.config("burn")["color_name"],
		"amount": 1,
	}


func contains_point(world_pos: Vector2) -> bool:
	return global_position.distance_to(world_pos) <= hit_radius
