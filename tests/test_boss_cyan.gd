@tool
extends McpTestSuite
## BossCyanCharge 单元测试：验证 Boss 独立青色冲锋的方向/最短时间/撞墙/超时逻辑。
## 这里不涉及任何解密元素系统（ElementBehavior / ColorCombo / ElementRules）。

const Charge := preload("res://scripts/enemies/boss_cyan_charge.gd")


func suite_name() -> String:
	return "boss_cyan"


func test_direction_away_from_source() -> void:
	var d := Charge.direction_away(Vector2(100, 0), Vector2.ZERO, Vector2.LEFT)
	assert_eq(d, Vector2.RIGHT, "应朝远离赋予来源的方向冲锋")


func test_direction_falls_back_without_source() -> void:
	var d := Charge.direction_away(Vector2.ZERO, Vector2.INF, Vector2.DOWN)
	assert_eq(d, Vector2.DOWN, "来源无效时应使用兜底方向")


func test_crash_only_after_min_time() -> void:
	var c := Charge.new()
	c.start(Vector2.ZERO, Vector2(-10, 0), Vector2.RIGHT)
	assert_eq(c.tick(0.1, 1), Charge.Outcome.NONE, "最短时间前不判定撞墙")
	assert_eq(c.tick(0.1, 1), Charge.Outcome.CRASHED, "超过最短时间后撞墙应崩溃")
	assert_false(c.active, "崩溃后应停止冲锋")


func test_timeout_finishes() -> void:
	var c := Charge.new()
	c.start(Vector2.ZERO, Vector2(-10, 0), Vector2.RIGHT)
	assert_eq(c.tick(c.max_time + 0.01, 0), Charge.Outcome.FINISHED, "无碰撞时超时应结束")


func test_stop_disables_charge() -> void:
	var c := Charge.new()
	c.start(Vector2.ZERO, Vector2(-10, 0), Vector2.RIGHT)
	c.stop()
	assert_false(c.active, "stop 后不再冲锋")
	assert_eq(c.tick(1.0, 1), Charge.Outcome.NONE, "停止后不再产生结果")
