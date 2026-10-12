class_name Firefly
extends CharacterBody2D
## 萤虫（中立生物）：单张贴图 + 全代码行为（无动画帧）。
##
## 状态（用 _color 表达，视觉 / 移动 / 光源全由它驱动）：
##   "burn"   默认——发红光（暗房里是红色光源），慢速漫游，玩家靠近时避让
##   ""       害怕——红光被吸走后：只剩一点微光（能看见、照不亮）+ 加速逃跑
##   "freeze" 冻结——被赋予蓝后静止不动，但灯保持亮（= 钉一个固定火把）
##   吸蓝 → 恢复 "burn"；吸红 → 变 ""（害怕）
##
## 碰撞：CharacterBody2D + move_and_slide 撞墙滑动，不穿进 TileMapLayer 的墙。
##   collision_layer=0（不挡玩家/跟班），collision_mask=2（撞「障碍」层：墙/树/木条；
##   项目里深水也复用层2，所以也会挡——迷宫没水可忽略，以后要飞过水再拆层）。
##
## colorable 契约：apply_color / absorb_color / has_color / contains_point + "colorable" 组。
## ⚠️ 不要加 is_frozen()：player._water_at_mouse 会把带 is_frozen 的 colorable 误判成
##    水格去 set_freeze_preview，直接崩溃。

const Rules := preload("res://scripts/element/element_rules.gd")

@export_group("移动")
@export var wander_speed: float = 40.0
@export var flee_speed: float = 220.0
@export var avoid_radius: float = 260.0
@export var scared_avoid_radius: float = 480.0
@export var wander_interval: float = 2.5
@export var wander_range: float = 160.0

@export_group("发光")
@export var light_radius: float = 360.0
## 害怕时的微光半径：小到只够看见萤虫本身、照不亮周围（玩家追得回，又不算「光源还在」）。
@export var scared_glint_radius: float = 80.0

@export_group("视觉")
@export var glow_color: Color = Color(1.0, 0.55, 0.25)
@export var frozen_color: Color = Color(0.4, 0.65, 1.0)
@export var dim_color: Color = Color(0.35, 0.35, 0.35)
@export var hit_radius: float = 48.0

@onready var visual: Node2D = $Visual
@onready var light: LightSource = $Light

var _color: String = "burn"
var _player: Node2D = null
var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
var _rest_timer: float = 0.0
var _bob_t: float = 0.0


func _ready() -> void:
	add_to_group("colorable")
	# 萤虫不挡任何东西（玩家/跟班可穿过），只撞「障碍」层（层 2）。
	collision_layer = 0
	collision_mask = 2
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_player = get_tree().get_first_node_in_group("player") as Node2D
	if light != null:
		light.radius = light_radius
	_new_wander_target()
	_refresh()


## 视觉上下浮动：纯装饰，与物理移动分离。
func _process(delta: float) -> void:
	_bob_t += delta
	if _color == "freeze":
		visual.position.y = 0.0
		return
	visual.position.y = sin(_bob_t * 3.0) * 5.0


## 移动：用 move_and_slide 撞墙滑动，不会穿进 TileMapLayer 的墙里。
func _physics_process(delta: float) -> void:
	if _color == "freeze":
		velocity = Vector2.ZERO
		return

	# 偶尔原地歇脚，打破「匀速直线」的机械感。
	if _rest_timer > 0.0:
		_rest_timer -= delta
		velocity = Vector2.ZERO
		return

	var speed: float = flee_speed if _color == "" else wander_speed
	var avoid_r: float = scared_avoid_radius if _color == "" else avoid_radius
	var dir: Vector2 = global_position.direction_to(_wander_target)

	if _player != null and is_instance_valid(_player):
		var away: Vector2 = global_position - _player.global_position
		if away.length() < avoid_r:
			# 靠近则把漫游方向往「远离玩家」掰，靠得越近逃得越明显
			dir = (dir * 0.3 + away.normalized()).normalized()

	velocity = dir * speed
	move_and_slide()

	if global_position.distance_to(_wander_target) < 24.0:
		_new_wander_target()
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_new_wander_target()
	# 撞墙滑动时更快换目标，避免贴着墙死滑。
	if get_slide_collision_count() > 0:
		_wander_timer -= delta * 3.0


func _new_wander_target() -> void:
	_wander_target = global_position + Vector2.from_angle(randf() * TAU) * randf_range(40.0, wander_range)
	_wander_timer = wander_interval * randf_range(0.7, 1.3)
	# 小概率原地歇脚。
	if randf() < 0.12:
		_rest_timer = randf_range(0.5, 1.2)


# —— colorable 契约 ——
func has_color() -> bool:
	return _color != ""


func contains_point(world_pos: Vector2) -> bool:
	return global_position.distance_to(world_pos) <= hit_radius


func apply_color(_c: Color, color_name: String = "", _from_pos: Vector2 = Vector2.INF) -> bool:
	# 给红 → 重新发光（burn）；给蓝 → 冻结（freeze）。同色重复给 = 无效，返回 false 不消耗种子。
	var element: String = Rules.element_for_color_name(color_name)
	if element == "burn" and _color != "burn":
		_color = "burn"
		_refresh()
		return true
	if element == "freeze" and _color != "freeze":
		_color = "freeze"
		_refresh()
		return true
	return false


func absorb_color() -> Dictionary:
	var el: String = _color
	if el == "":
		return {"element": "", "color": Color.WHITE, "color_name": ""}
	# 吸蓝 → 恢复发光；吸红 → 熄大灯、变害怕（只留微光）
	_color = "burn" if el == "freeze" else ""
	_refresh()
	var cfg: Dictionary = Rules.config(el)
	return {
		"element": el,
		"color": cfg.get("color", Color.WHITE),
		"color_name": cfg.get("color_name", ""),
		"amount": 1,
	}


func _refresh() -> void:
	# darkness_overlay 按 "light_source" 组读，不认 visible，所以「熄灯」= 调半径，不靠移组。
	if light != null:
		if _color == "":
			light.radius = scared_glint_radius   # 害怕：只留一点微光，能看见、照不亮
		else:
			light.radius = light_radius          # burn / freeze：都亮；冻结只是静止不灭灯
		light.add_to_group("light_source")
	if visual != null:
		var tint: Color = dim_color
		if _color == "burn":
			tint = glow_color
		elif _color == "freeze":
			tint = frozen_color
		visual.self_modulate = tint
