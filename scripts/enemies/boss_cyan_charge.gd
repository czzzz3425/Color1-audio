class_name BossCyanCharge
extends RefCounted
## Boss 专属青色冲锋机制（纯逻辑，不依赖任何解密元素/颜色系统）。
##
## 注意：这不是解密的「蓝 × 绿 = 青」混合机制，也不会调用 ElementBehavior / ColorCombo /
## ElementRules.config("cyan") / cyan_move_*。Boss 只借用「青色」这一视觉主题，
## 冲锋的触发条件、方向、计时、撞墙判定全部在这里独立实现。
##
## 行为：
##   start() 锁定「远离赋予来源」的方向（来源无效时用兜底方向）。
##   tick() 推进计时；达到最短时间后撞到东西 = CRASHED；超过最长时间 = FINISHED。
## Boss 负责把 direction * speed 应用到 CharacterBody2D，并处理扣血/眩晕/视觉。

enum Outcome { NONE, CRASHED, FINISHED }

## 冲锋速度（世界像素/秒）。
var speed := 1500.0
## 起冲后至少多久才允许判定撞墙（避免刚起步就被自身碰撞打断）。
var min_time := 0.15
## 冲锋最长时间（秒），超时自动结束。
var max_time := 2.2
## 撞墙时按最大生命比例自伤。
var self_damage_ratio := 0.16
## 撞墙后眩晕时长（秒）。
var stun_time := 1.4

## 当前冲锋方向（单位向量）。
var direction := Vector2.RIGHT
## 已冲锋时长（秒）。
var elapsed := 0.0
## 是否正在冲锋。
var active := false


## 开始冲锋。from_pos = 玩家赋予蓝色时的来源位置（跟班落点）。
func start(boss_pos: Vector2, from_pos: Vector2, fallback_dir: Vector2) -> void:
	direction = direction_away(boss_pos, from_pos, fallback_dir)
	elapsed = 0.0
	active = true


## 推进一帧。collision_count = 宿主 CharacterBody2D 本帧的滑动碰撞数。
func tick(delta: float, collision_count: int) -> int:
	if not active:
		return Outcome.NONE
	elapsed += delta
	if elapsed >= min_time and collision_count > 0:
		active = false
		return Outcome.CRASHED
	if elapsed >= max_time:
		active = false
		return Outcome.FINISHED
	return Outcome.NONE


## 中止冲锋（例如 Boss 死亡/被打断）。
func stop() -> void:
	active = false
	elapsed = 0.0


## 远离来源的方向；来源无效时退回 fallback_dir。纯函数，供单测。
static func direction_away(
	boss_pos: Vector2, from_pos: Vector2, fallback_dir: Vector2
) -> Vector2:
	if from_pos != Vector2.INF:
		var away := boss_pos - from_pos
		if away.length() > 1.0:
			return away.normalized()
	var d := fallback_dir.normalized()
	return d if d != Vector2.ZERO else Vector2.RIGHT
