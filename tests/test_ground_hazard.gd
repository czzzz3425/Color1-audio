@tool
extends McpTestSuite
## GroundHazard 单元测试：只覆盖纯逻辑（kind → 组名 / 是否造成伤害），
## 不触碰场景树，可在编辑器内安全运行。

const Hazard := preload("res://scripts/enemies/ground_hazard.gd")


func suite_name() -> String:
	return "ground_hazard"


func test_burn_group() -> void:
	assert_eq(Hazard.group_for_kind(Hazard.Kind.BURN), "burn_trail", "燃烧痕迹应入 burn_trail 组")


func test_ice_group() -> void:
	assert_eq(Hazard.group_for_kind(Hazard.Kind.ICE_CRYSTAL), "ice_crystal", "冰晶应入 ice_crystal 组")


func test_burn_damages() -> void:
	assert_true(Hazard.is_damaging_kind(Hazard.Kind.BURN), "燃烧痕迹应造成伤害")


func test_ice_slows_not_damages() -> void:
	assert_false(Hazard.is_damaging_kind(Hazard.Kind.ICE_CRYSTAL), "冰晶应只减速、不掉血")
