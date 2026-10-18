@tool
extends McpTestSuite
## RedMinion 单元测试：覆盖「与玩家保持距离带」的纯逻辑决策，
## 不触碰场景树（CharacterBody2D 的物理行为不在此测）。

const Minion := preload("res://scripts/enemies/red_minion.gd")


func suite_name() -> String:
	return "red_minion"


func test_too_far_approaches() -> void:
	assert_eq(Minion.distance_band_dir(1000.0, 320.0, 720.0), 1, "太远应靠近玩家(+1)")


func test_too_close_retreats() -> void:
	assert_eq(Minion.distance_band_dir(100.0, 320.0, 720.0), -1, "太近应后退(-1)")


func test_in_band_free_wander() -> void:
	assert_eq(Minion.distance_band_dir(450.0, 320.0, 720.0), 0, "带内应自由漫游(0)")


func test_band_boundaries_are_inclusive() -> void:
	assert_eq(Minion.distance_band_dir(320.0, 320.0, 720.0), 0, "正好等于 min 视为在带内")
	assert_eq(Minion.distance_band_dir(720.0, 320.0, 720.0), 0, "正好等于 max 视为在带内")


func test_counter_color_locks_minion() -> void:
	var m := Minion.new()
	m.killed_by_element = "freeze"
	assert_true(m.lock_for_paint("蓝"), "克制色应让小怪定格")
	assert_true(m.is_paint_locked(), "定格状态应生效")
	m.release_paint_lock()
	assert_false(m.is_paint_locked(), "释放后应恢复移动")
	m.free()


func test_wrong_color_does_not_lock_minion() -> void:
	var m := Minion.new()
	m.killed_by_element = "freeze"
	assert_false(m.lock_for_paint("红"), "非克制色不应定格小怪")
	assert_false(m.is_paint_locked(), "小怪应保持自由移动")
	m.free()
