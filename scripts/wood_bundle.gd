class_name WoodBundle
extends CharacterBody2D
## 枯木束：可推动 + 可燃/可冻结的有机燃料（暗房里 = 可搬运的火把）。
##
## 与既有 ColorableBase 共用同一套 ElementBehavior 元素语义：
##   红(burn)   → 点燃：燃烧发光（成为 light_source，焰虱会追过来）+ 预留蔓延位
##   蓝(freeze) → 冻结：不可推动、不可点燃（消防隔离带）
##   蓝打在燃烧中 → freeze×burn 碎裂（与树/木条一致，用蓝扑灭并销毁燃料）
## 吸收当前色 → 抽走（吸红=灭火；吸蓝=解冻），复用 ElementBehavior.clear()。
##
## 根节点是 CharacterBody2D 以便玩家 push（复用 PushableBody 的 move_and_collide 推法），
## 玩家朝它顶住时由 player._push_boxes 调用 push(dir, delta)。
##
## ⚠️ 同 firefly/fire_louse：不要定义 is_frozen()（player._water_at_mouse 会误判成水格崩溃）。

const Rules := preload("res://scripts/element/element_rules.gd")
const Behavior := preload("res://scripts/element/element_behavior.gd")
const DepthSort := preload("res://scripts/depth_sort.gd")

@export_group("推动")
@export_range(0.0, 3000.0, 5.0) var push_speed := 1280.0

@export_group("发光")
@export_range(16.0, 2048.0, 8.0) var light_radius := 352.0
@export var light_offset := Vector2.ZERO
@export_group("青（蓝×绿）")
@export var cyan_move_dir := Vector2.RIGHT
@export_range(0.0, 4096.0, 8.0) var cyan_move_distance := 768.0
@export_range(0.05, 5.0, 0.05) var cyan_move_duration := 0.5
## 黄（红×绿混合）态：是否开启子弹反射与反射参数。
@export var reflect_bullets := true
@export_range(8.0, 2048.0, 1.0) var reflect_radius := 176.0
@export var reflect_faction := "player"

@export_group("状态")
@export var state_id: String = ""

@onready var visual: Sprite2D = $Visual
@onready var collision: CollisionShape2D = $Collision

var _behavior: ElementBehavior


func _ready() -> void:
	add_to_group("colorable")
	add_to_group("stateful")
	if state_id == "":
		state_id = name
	# 层 2 = 障碍：玩家（mask 6）会撞到它 → 可推；它也撞墙（mask 2）→ 推到墙边停下。
	collision_layer = 2
	collision_mask = 2
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	z_index = DepthSort.z_for(global_position.y)
	_setup_behavior()


func _physics_process(_delta: float) -> void:
	# 被推走后按脚底 Y 更新深度排序，保持被墙/树正确遮挡。
	z_index = DepthSort.z_for(global_position.y)


func _setup_behavior() -> void:
	_behavior = Behavior.new()
	_behavior.name = "ElementBehavior"
	_behavior.light_radius = light_radius
	_behavior.light_offset = light_offset
	_behavior.cyan_move_dir = cyan_move_dir
	_behavior.cyan_move_distance = cyan_move_distance
	_behavior.cyan_move_duration = cyan_move_duration
	_behavior.reflect_bullets = reflect_bullets
	_behavior.reflect_radius = reflect_radius
	_behavior.reflect_faction = reflect_faction
	if visual != null:
		_behavior.visual_center = visual.position
		_behavior.shatter_target = visual
	add_child(_behavior)


# —— 推动（玩家顶住时调用）——
func push(dir: Vector2, delta: float) -> void:
	if _behavior != null and _behavior.current_element() == "freeze":
		return   # 冻结：不可推动
	if dir == Vector2.ZERO or delta <= 0.0:
		return
	move_and_collide(dir.normalized() * push_speed * delta)


# —— colorable 契约 ——
func apply_color(_c: Color, color_name: String = "", from_pos: Vector2 = Vector2.INF) -> bool:
	var element := Rules.element_for_color_name(color_name)
	if element == "":
		return false
	# 冻结的木束不可点燃（firebreak）：红撞到冻结 → 无效，不消耗种子。
	if element == "burn" and _behavior.current_element() == "freeze":
		return false
	return _behavior.apply(element, from_pos)


func has_color() -> bool:
	return _behavior != null and _behavior.has_element()


## 当前元素状态（非破坏性读取：burn / freeze / grow / ""）。供元素踏板等传感器查询。
func current_element() -> String:
	return _behavior.current_element() if _behavior != null else ""


func absorb_color() -> Dictionary:
	var els: Array = _behavior.absorb()
	if els.size() == 1 and els[0] != "":
		var cfg := Rules.config(els[0])
		return {
			"element": els[0],
			"color": cfg.get("color", Color.WHITE),
			"color_name": cfg.get("color_name", ""),
		}
	# 青 → 蓝+绿：直接退给玩家。
	var player := get_tree().get_first_node_in_group("player")
	for el in els:
		if el != "" and player != null and player.has_method("refund_element"):
			player.call("refund_element", el, 1)
	return {
		"element": "",
		"color": Color.WHITE,
		"color_name": "",
	}


func contains_point(world_pos: Vector2) -> bool:
	if visual != null:
		return visual.get_rect().has_point(visual.to_local(world_pos))
	return global_position.distance_to(world_pos) <= 48.0


# —— 状态持久化（Room 进出场统一 save/restore）——
func save_state() -> Dictionary:
	return {
		"pos": global_position,
		"element": _behavior.current_element() if _behavior != null else "",
	}


func restore_state(data: Dictionary) -> void:
	global_position = data.get("pos", global_position)
	velocity = Vector2.ZERO
	var el: String = data.get("element", "")
	if el != "" and _behavior != null and not _behavior.has_element():
		_behavior.apply(el)
