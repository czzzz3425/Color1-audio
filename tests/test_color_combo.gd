@tool
extends McpTestSuite
## ColorCombo 单元测试：只覆盖纯逻辑（组合 / 吸收 / 重置 / 自定义配方 / 信号），
## 不触碰场景树，可在编辑器内安全运行。

const Combo := preload("res://scripts/mechanics/color_combo.gd")


func suite_name() -> String:
	return "color_combo"


func test_empty_not_complete() -> void:
	var c := Combo.new()
	assert_false(c.is_complete(), "空组合不算凑齐")
	assert_eq(c.result_id(), "", "未凑齐无产物")


func test_red_then_green_makes_yellow() -> void:
	var c := Combo.new()
	assert_true(c.apply("burn"), "赋予红应改变状态")
	assert_false(c.is_complete(), "只有红还不算黄")
	assert_true(c.apply("grow"), "赋予绿应改变状态")
	assert_true(c.is_complete(), "红+绿=黄")
	assert_eq(c.result_id(), "yellow", "产物应为 yellow")


func test_order_independent() -> void:
	var c := Combo.new()
	c.apply("grow")
	c.apply("burn")
	assert_true(c.is_complete(), "先绿后红同样变黄")


func test_duplicate_apply_is_noop() -> void:
	var c := Combo.new()
	assert_true(c.apply("burn"))
	assert_false(c.apply("burn"), "同色重复赋予应无效")
	assert_eq(c.elements().size(), 1, "不应重复记录")


func test_absorb_breaks_combo() -> void:
	var c := Combo.new()
	c.apply("burn")
	c.apply("grow")
	assert_eq(c.absorb(), "grow", "吸收最近赋予的元素（后进先出）")
	assert_false(c.is_complete(), "抽走其一即破坏黄色")
	assert_eq(c.result_id(), "")


func test_absorb_empty() -> void:
	var c := Combo.new()
	assert_eq(c.absorb(), "", "空物体吸收返回空串")


func test_reset_clears() -> void:
	var c := Combo.new()
	c.apply("burn")
	c.apply("grow")
	c.reset()
	assert_false(c.is_complete(), "重置后不再凑齐")
	assert_eq(c.elements().size(), 0)


func test_custom_recipe() -> void:
	var c := Combo.new(["burn", "freeze"], "purple")
	c.apply("burn")
	c.apply("freeze")
	assert_true(c.is_complete(), "自定义配方应凑齐")
	assert_eq(c.result_id(), "purple")


func test_signals_fire() -> void:
	var c := Combo.new()
	var log: Array = []
	c.completed.connect(func(id: String) -> void: log.append("completed:" + id))
	c.broken.connect(func(id: String) -> void: log.append("broken:" + id))
	c.apply("burn")
	c.apply("grow")
	assert_true(log.has("completed:yellow"), "凑齐应发 completed")
	c.absorb()
	assert_true(log.has("broken:yellow"), "破坏应发 broken")
