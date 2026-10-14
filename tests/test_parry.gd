@tool
extends McpTestSuite
## 弹反系统单元测试：覆盖时序状态机 ParryTiming 与子弹 ParryProjectile 的纯逻辑
## （窗口 / 冷却 / 比率 / 归属翻转 / 提速 / 单次弹反 / 不可弹反），不触碰场景树。

const Timing := preload("res://scripts/mechanics/parry_timing.gd")
const Proj := preload("res://scripts/mechanics/parry_projectile.gd")


func suite_name() -> String:
	return "parry"


# —— ParryTiming ——

func test_window_opens_and_expires() -> void:
	var t := Timing.new(0.2, 0.4)
	assert_true(t.can_start(), "初始应就绪")
	assert_true(t.start(), "应能开窗")
	assert_true(t.is_active(), "开窗后生效")
	t.advance(0.1)
	assert_true(t.is_active(), "窗口内仍生效")
	t.advance(0.15)
	assert_false(t.is_active(), "超时窗口应关闭")


func test_cooldown_blocks_restart() -> void:
	var t := Timing.new(0.2, 0.3)
	t.start()
	t.advance(0.25)   # 窗口已关，冷却剩 0.25
	assert_false(t.is_active(), "窗口应已关闭")
	assert_false(t.can_start(), "冷却中不能再弹反")
	t.advance(0.3)
	assert_true(t.can_start(), "冷却结束后恢复")


func test_cooldown_ratio() -> void:
	var t := Timing.new(0.2, 0.8)
	assert_eq(t.cooldown_ratio(), 0.0, "就绪时比率为 0")
	t.start()
	assert_gt(t.cooldown_ratio(), 0.9, "刚触发时比率接近 1")
	t.advance(1.0)
	assert_eq(t.cooldown_ratio(), 0.0, "冷却完比率归 0")


func test_reset() -> void:
	var t := Timing.new(0.2, 0.4)
	t.start()
	t.reset()
	assert_false(t.is_active(), "重置后无窗口")
	assert_true(t.can_start(), "重置后应就绪")


# —— ParryProjectile ——

func test_parry_flips_faction_and_direction() -> void:
	var p := Proj.new()
	p.setup(Vector2.LEFT, "enemy")
	assert_true(p.can_parry(), "默认可弹反")
	var before_speed := p.speed
	var parrier := Node.new()
	parrier.add_to_group("player")
	track(parrier)
	assert_true(p.parry(Vector2.RIGHT, parrier), "弹反应成功")
	assert_eq(p.source_group, "player", "归属应翻转为弹反者阵营")
	assert_eq(p.direction, Vector2.RIGHT, "方向应变为反弹方向")
	assert_gt(p.speed, before_speed, "反弹后应提速")
	track(p)


func test_single_parry_only() -> void:
	var p := Proj.new()
	p.setup(Vector2.LEFT)
	var parrier := Node.new()
	parrier.add_to_group("player")
	track(parrier)
	assert_true(p.parry(Vector2.RIGHT, parrier), "第一次弹反应成功")
	assert_false(p.can_parry(), "默认只能弹反一次")
	assert_false(p.parry(Vector2.RIGHT, parrier), "第二次弹反应失败")
	track(p)


func test_unparryable_projectile() -> void:
	var p := Proj.new()
	p.parryable = false
	p.setup(Vector2.LEFT)
	assert_false(p.can_parry(), "parryable=false 不可弹反")
	var parrier := Node.new()
	parrier.add_to_group("player")
	track(parrier)
	assert_false(p.parry(Vector2.RIGHT, parrier), "不可弹反的子弹弹反失败")
	track(p)


func test_enemy_parrier_faction() -> void:
	var p := Proj.new()
	p.setup(Vector2.RIGHT, "player")
	var parrier := Node.new()
	parrier.add_to_group("enemy")
	track(parrier)
	assert_true(p.parry(Vector2.LEFT, parrier), "敌方也可用同套机制弹反")
	assert_eq(p.source_group, "enemy", "归属翻转为敌方阵营")
	track(p)
