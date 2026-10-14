class_name YellowObject
extends Node2D
## 黄色机制载体：一个可上色物体，被依次赋予「红」和「绿」两种能力后变为黄色物体。
##
## 组合规则委托给 ColorCombo（默认 红+绿=黄，可在 Inspector 改 required_elements / result_element）。
## 本类负责：
##   · 实现 colorable 契约（apply_color / has_color / absorb_color / current_element / contains_point），
##     因此可直接被玩家的「赋予 / 吸收」流程（companion.gd）识别与操作，无需额外接线；
##   · 视觉：颜色随已含元素混合，凑齐后变为黄色并自动加入 "yellow_object" 组。
##
## 供他人挂监听：became_yellow / yellow_lost / element_changed(element_id) / reflected_bullet(...)；
## 也可直接查询：is_yellow() / elements() / current_element()。
##
## 变黄后附带「反射子弹」能力：自动挂一个 BulletReflector，仅当变黄时开启，破坏后关闭。
##
## 需要子节点：Visual（Polygon2D 或 Sprite2D）。可另放 Shadow 等装饰。

signal became_yellow
signal yellow_lost
signal element_changed(element_id: String)
## 黄色状态下反射了一颗子弹（供音效 / 特效 / 计数）。
signal reflected_bullet(projectile: Node, direction: Vector2)

const Rules := preload("res://scripts/element/element_rules.gd")
const Combo := preload("res://scripts/mechanics/color_combo.gd")
const Reflector := preload("res://scripts/mechanics/bullet_reflector.gd")
const DepthSort := preload("res://scripts/depth_sort.gd")

## 凑齐黄色所需的元素（默认红+绿，顺序无关）。
@export var required_elements: Array = ["burn", "grow"]
## 产物元素 id。
@export var result_element: String = "yellow"
## 未上色时的底色。
@export var base_color := Color(0.95, 0.95, 0.95)
## 无 Visual 子节点时的命中判定半径（世界像素）。
@export_range(8.0, 512.0, 1.0) var hit_radius := 48.0

@export_group("反射子弹")
## 变黄后是否自动开启子弹反射。
@export var reflect_bullets := true
## 反射范围（世界像素）。
@export_range(8.0, 1024.0, 1.0) var reflect_radius := 176.0
## 反射后子弹归属阵营（写回子弹 source_group）。留空 = 由子弹自行判定。
@export var reflect_faction := "player"

var _combo: ColorCombo
var _reflector: Reflector
var _last_element := ""

@onready var visual: Node2D = get_node_or_null("Visual")


func _ready() -> void:
	z_index = DepthSort.z_for(global_position.y)
	add_to_group("colorable")
	_combo = Combo.new(required_elements, result_element)
	_combo.completed.connect(_on_completed)
	_combo.broken.connect(_on_broken)
	_setup_reflector()
	_refresh()


## 装配反射组件（默认关闭，仅变黄时开启）。
func _setup_reflector() -> void:
	_reflector = Reflector.new()
	_reflector.name = "BulletReflector"
	_reflector.radius = reflect_radius
	_reflector.faction = reflect_faction
	_reflector.set_enabled(false)
	_reflector.reflected.connect(_on_reflected)
	add_child(_reflector)


## colorable 契约：赋予一个元素（color_name 经 Rules 映射为元素 id）。
## 真的改变状态返回 true（重复给同色返回 false，调用方据此不消耗种子）。
func apply_color(_c: Color, color_name: String = "", _from_pos: Vector2 = Vector2.INF) -> bool:
	var element := Rules.element_for_color_name(color_name)
	if element == "":
		return false
	if not _combo.apply(element):
		return false
	_flash()
	_refresh()
	return true


func has_color() -> bool:
	return not _combo.elements().is_empty()


## 主元素：凑齐返回 result_element（"yellow"），否则最近赋予的元素；空物返回 ""。
func current_element() -> String:
	if _combo.is_complete():
		return result_element
	var els := _combo.elements()
	return str(els[els.size() - 1]) if not els.is_empty() else ""


## colorable 契约：抽走最近赋予的元素，返回其颜色信息。
func absorb_color() -> Dictionary:
	var element := _combo.absorb()
	_refresh()
	if element == "":
		return {"element": "", "color": Color.WHITE, "color_name": ""}
	var cfg := Rules.config(element)
	return {
		"element": element,
		"color": cfg.get("color", Color.WHITE),
		"color_name": cfg.get("color_name", ""),
	}


## 点击命中：世界坐标点是否落在 Visual 上（多边形用 is_point_in_polygon，贴图用 get_rect）。
func contains_point(world_pos: Vector2) -> bool:
	if visual is Polygon2D:
		return Geometry2D.is_point_in_polygon((visual as Polygon2D).to_local(world_pos), (visual as Polygon2D).polygon)
	if visual is Sprite2D:
		return (visual as Sprite2D).get_rect().has_point((visual as Sprite2D).to_local(world_pos))
	return global_position.distance_to(world_pos) <= hit_radius


## 是否为黄色（已凑齐产物）。
func is_yellow() -> bool:
	return _combo.is_complete()


## 当前含有的元素 id 列表（按赋予顺序）。
func elements() -> Array:
	return _combo.elements()


func _on_completed(_result_id: String) -> void:
	if not is_in_group("yellow_object"):
		add_to_group("yellow_object")
	if reflect_bullets and _reflector != null:
		_reflector.set_enabled(true)
	_refresh()
	became_yellow.emit()


func _on_broken(_result_id: String) -> void:
	remove_from_group("yellow_object")
	if _reflector != null:
		_reflector.set_enabled(false)
	_refresh()
	yellow_lost.emit()


## 反射组件回调：闪一下 + 广播。
func _on_reflected(projectile: Node, direction: Vector2) -> void:
	_flash()
	reflected_bullet.emit(projectile, direction)


## 视觉刷新：按已含元素混合颜色；凑齐则用产物（黄）色。
func _refresh() -> void:
	var col := base_color
	if _combo.is_complete():
		col = Rules.config(result_element).get("color", Color(1.0, 0.85, 0.2))
	else:
		for el in _combo.elements():
			col = col.lerp(Rules.config(el).get("color", col), 0.75)
	_set_visual_color(col)
	var cur := current_element()
	if cur != _last_element:
		_last_element = cur
		element_changed.emit(cur)


func _set_visual_color(col: Color) -> void:
	if visual is Polygon2D:
		(visual as Polygon2D).color = col
	elif visual is Sprite2D:
		(visual as Sprite2D).self_modulate = col


## 上色小反馈：轻微弹一下。
func _flash() -> void:
	if visual == null:
		return
	var t := create_tween()
	t.tween_property(visual, "scale", Vector2(1.12, 1.12), 0.08)
	t.tween_property(visual, "scale", Vector2.ONE, 0.12)
