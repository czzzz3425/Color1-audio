class_name ParryEmitter
extends StaticBody2D
## 弹幕发射器（示例 / 测试用）：周期性朝玩家发射 ParryProjectile。
## 它自己在 "enemy" 组里并带 take_damage，因此被弹反回来的子弹命中会掉血直至销毁——
## 演示「弹反 → 反打」的完整闭环，也可作为接入自己敌人的用法示例。
##
## 公共 API：fire() -> Node（手动发射一发，返回子弹节点）。

@export var projectile_scene: PackedScene = preload("res://scenes/parry_projectile.tscn")
@export_range(0.1, 10.0, 0.1) var fire_interval := 1.6
## true = 瞄准玩家；false = 沿 fire_direction 直线发射。
@export var aim_at_player := true
@export var fire_direction := Vector2.RIGHT
## 出膛点相对发射器的前向偏移（像素，避免子弹一出生就撞到自己）。
@export var muzzle_offset := 64.0
@export var projectile_speed := 420.0
@export_range(1, 50, 1) var max_health := 2

var health := 0

var _t := 0.0
var _player: Node2D

@onready var visual: Node2D = get_node_or_null("Visual")


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("parry_emitter")
	health = max_health
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_t = fire_interval   # 进场立刻先来一发，方便观察


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < fire_interval:
		return
	_t = 0.0
	fire()


## 发射一发子弹，返回子弹节点（发射失败返回 null）。
func fire() -> Node:
	if projectile_scene == null:
		return null
	var dir := fire_direction
	if aim_at_player and _player != null and is_instance_valid(_player):
		dir = global_position.direction_to(_player.global_position)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var proj := projectile_scene.instantiate()
	var holder := get_parent()
	if holder == null:
		proj.queue_free()
		return null
	holder.add_child(proj)
	if proj is Node2D:
		(proj as Node2D).global_position = global_position + dir.normalized() * muzzle_offset
	if proj.has_method("setup"):
		proj.call("setup", dir, "enemy")
		proj.set("speed", projectile_speed)
	return proj


func take_damage(amount: float = 1.0) -> void:
	health -= int(round(amount))
	_flash()
	if health <= 0:
		queue_free()


func _flash() -> void:
	if not (visual is Polygon2D):
		return
	(visual as Polygon2D).color = Color(1.4, 1.4, 1.4, 1.0)
	var t := create_tween()
	t.tween_property(visual, "color", Color(0.65, 0.25, 0.28, 1.0), 0.25)
