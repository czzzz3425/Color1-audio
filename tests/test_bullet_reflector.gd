@tool
extends McpTestSuite
## BulletReflector 单元测试：覆盖开关门控与「不在场景树内也安全」的纯逻辑。
## 实际扫描/反弹（需要场景树）在 tests/test_parry.gd 的子弹契约测试与运行期验证中覆盖。

const Reflector := preload("res://scripts/mechanics/bullet_reflector.gd")


func suite_name() -> String:
	return "bullet_reflector"


func test_default_disabled() -> void:
	var r := Reflector.new()
	assert_false(r.is_enabled(), "默认关闭")
	assert_eq(r.reflect_now(), 0, "关闭时不反弹")
	track(r)


func test_toggle() -> void:
	var r := Reflector.new()
	r.set_enabled(true)
	assert_true(r.is_enabled(), "可开启")
	r.set_enabled(false)
	assert_false(r.is_enabled(), "可关闭")
	track(r)


func test_reflect_now_safe_without_tree() -> void:
	var r := Reflector.new()
	r.set_enabled(true)
	assert_eq(r.reflect_now(), 0, "不在场景树内应安全返回 0 而非崩溃")
	track(r)


func test_radius_and_faction_defaults() -> void:
	var r := Reflector.new()
	assert_gt(r.radius, 0.0, "默认应有反射半径")
	assert_eq(r.faction, "player", "默认反射归属玩家阵营")
	track(r)
