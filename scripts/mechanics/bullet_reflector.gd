class_name BulletReflector
extends Node2D
## 子弹反射组件：持续把进入 radius 的可弹反子弹反弹回去（镜面 / 护盾式被动，不需要按键）。
##
## 与 Parry 组件共用同一套子弹契约——任何子弹只要满足下面条件即可被反射：
##   · 加入组 "parryable_projectile"；
##   · 实现 can_parry() -> bool 与 parry(deflect_dir: Vector2, parrier: Node) -> bool。
## 项目内的 ParryProjectile 即满足该契约。
##
## 典型用途：黄色物体变黄后开启反射（见 yellow_object.gd）；护盾、陷阱、镜面墙等。
##
## 公共 API：
##   set_enabled(on) / is_enabled()
##   reflect_now() -> int     立即扫描并反弹，返回本次反弹数量
## 信号：reflected(projectile, direction)

signal reflected(projectile: Node, direction: Vector2)

## 是否开启反射。关闭时完全不工作。
@export var enabled := false
## 反射范围（世界像素，以组件全局位置为圆心）。
@export_range(8.0, 2048.0, 1.0) var radius := 176.0
## 反射后子弹的归属阵营，写回子弹的 source_group。
## 留空 = 不改，交由子弹按其 parrier 自行判定。需子弹暴露 source_group 属性。
@export var faction := "player"
## 扫描间隔（秒）。0 = 每个物理帧都扫描。
@export_range(0.0, 1.0, 0.01) var scan_interval := 0.0

var _cooldown := 0.0


func _ready() -> void:
	add_to_group("bullet_reflector")


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	if scan_interval > 0.0:
		_cooldown -= delta
		if _cooldown > 0.0:
			return
		_cooldown = scan_interval
	reflect_now()


func set_enabled(on: bool) -> void:
	enabled = on


func is_enabled() -> bool:
	return enabled


## 立即扫描范围内可弹反的子弹并反弹，返回反弹数量。
func reflect_now() -> int:
	if not enabled:
		return 0
	if not is_inside_tree():
		return 0
	var tree := get_tree()
	if tree == null:
		return 0
	var origin := global_position
	var count := 0
	for p in tree.get_nodes_in_group("parryable_projectile"):
		if not is_instance_valid(p) or not (p is Node2D):
			continue
		if not GameState.is_in_current_scene(p):
			continue
		if not p.has_method("can_parry") or not bool(p.call("can_parry")):
			continue
		if origin.distance_to((p as Node2D).global_position) > radius:
			continue
		var dir := origin.direction_to((p as Node2D).global_position)
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		if not p.has_method("parry"):
			continue
		if not bool(p.call("parry", dir, get_parent())):
			continue
		# 约定：子弹可暴露 source_group 属性。留空则不改，由子弹按 parrier 判定。
		if faction != "" and p.get("source_group") != null:
			p.set("source_group", faction)
		count += 1
		reflected.emit(p, dir)
	return count
