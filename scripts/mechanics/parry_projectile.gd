class_name ParryProjectile
extends CharacterBody2D
## 可弹反子弹：直线飞行，命中「敌对阵营」实体造成伤害与击退；被 Parry 弹反后反向、归属翻转。
##
## 阵营用 source_group 表示（默认 "enemy"，即攻击玩家）。被弹反时 source_group 变为弹反者所属阵营
## （弹反者是玩家 → "player"），于是它转而伤害敌人——「弹反」天然变成「反打」。
##
## 组 "parryable_projectile" 让 Parry 组件发现它（parryable 为真时自动加入）。
##
## 公共 API：
##   setup(direction, source_group := "enemy")  初始化朝向 / 阵营
##   can_parry() -> bool                        现在能否被弹反
##   parry(deflect_dir, parrier) -> bool        由 Parry 调用：反弹（反向 + 归属翻转 + 提速）
##   is_parried() -> bool
## 信号：parried(direction) / hit(target)

signal parried(direction: Vector2)
signal hit(target: Node)

@export_group("飞行")
@export var speed := 900.0
@export var lifetime := 6.0
@export var direction := Vector2.RIGHT

@export_group("命中")
@export var damage := 1.0
@export var knockback_strength := 600.0

@export_group("弹反")
## 是否可被弹反（加入 "parryable_projectile" 组）。
@export var parryable := true
## 反弹后速度倍率。
@export var reflect_speed_scale := 1.2
## 是否只能被弹反一次。
@export var single_parry := true

## 当前阵营：谁发射的（"enemy" / "player" / 自定义组名）。
var source_group := "enemy"

@onready var visual: Node2D = get_node_or_null("Visual")

var _age := 0.0
var _parried := false


func _ready() -> void:
	if parryable:
		add_to_group("parryable_projectile")
	_update_visual_rotation()


## 初始化。from 为发射者阵营组名（默认 "enemy"）。
func setup(dir: Vector2, from: String = "enemy") -> void:
	direction = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	source_group = from
	_update_visual_rotation()


func is_parried() -> bool:
	return _parried


func can_parry() -> bool:
	return parryable and not (_parried and single_parry)


## 由 Parry 调用：沿 deflect_dir 反弹，归属翻转为弹反者阵营。
func parry(deflect_dir: Vector2, parrier: Node) -> bool:
	if not can_parry():
		return false
	_parried = true
	direction = deflect_dir.normalized() if deflect_dir != Vector2.ZERO else -direction
	speed *= reflect_speed_scale
	source_group = _faction_of(parrier)
	_age = 0.0
	# 归属翻转后不再命中「玩家层」（层 1），避免刚弹反就被自己挡住。
	set_collision_mask_value(1, source_group != "player")
	_update_visual_rotation()
	_on_parried_visual()
	parried.emit(direction)
	return true


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	var col := move_and_collide(direction * speed * delta)
	if col == null:
		return
	_resolve_hit(col.get_collider())
	queue_free()


func _resolve_hit(collider: Node) -> void:
	if collider == null:
		return
	if collider.is_in_group(source_group):
		return   # 同阵营：不造成伤害
	if collider.has_method("take_damage"):
		collider.call("take_damage", damage)
		hit.emit(collider)
	if collider.has_method("knockback"):
		collider.call("knockback", direction, knockback_strength)


func _faction_of(node: Node) -> String:
	if node != null:
		if node.is_in_group("player"):
			return "player"
		if node.is_in_group("enemy"):
			return "enemy"
	return "player"


func _on_parried_visual() -> void:
	var gold := Color(1.0, 0.9, 0.35, 1.0)
	if visual is Polygon2D:
		(visual as Polygon2D).color = gold
	elif visual is Sprite2D:
		(visual as Sprite2D).self_modulate = gold


## 让视觉朝向飞行方向（只转视觉，不影响圆形碰撞与移动）。
func _update_visual_rotation() -> void:
	if visual != null:
		visual.rotation = direction.angle()
