class_name ElementRules
extends RefCounted

## 元素系统数据表（单一数据源）。
## 颜色名 -> 元素 id；元素 id -> 行为配置。
## 策划调整只改这里，不动行为代码。

const COLOR_NAME_TO_ELEMENT := {
	"红": "burn",
	"蓝": "freeze",
	"绿": "grow",
}

const ELEMENTS := {
	"burn": {
		"color_name": "红",
		"color": Color(1.0, 0.3, 0.3),
		"vfx": "res://shaders/fire.tscn",
		"spreads": false,
		"spread_radius": 1120.0,
		"spread_delay": 0.9,
	},
	"freeze": {
		"color_name": "蓝",
		"color": Color(0.3, 0.55, 1.0),
		"vfx": "res://effects/freeze_spread/freeze_spread.tscn",
		"spreads": false,
		"spread_radius": 880.0,
		"spread_delay": 0.7,
	},
	"grow": {
		"color_name": "绿",
		"color": Color(0.35, 0.85, 0.4),
		"vfx": "",
		"spreads": false,
		"spread_radius": 512.0,
		"spread_delay": 1.0,
	},
	# 青 = 蓝 × 绿 的混合态：不是玩家可直接持有的种子，只作为混合结果存在。
	"cyan": {
		"color_name": "青",
		"color": Color(0.3, 0.9, 0.95),
		"vfx": "",
		"spreads": false,
		"spread_radius": 512.0,
		"spread_delay": 1.0,
	},
}


static func element_for_color_name(color_name: String) -> String:
	return str(COLOR_NAME_TO_ELEMENT.get(color_name, ""))


static func config(element_id: String) -> Dictionary:
	return ELEMENTS.get(element_id, {})


static func has(element_id: String) -> bool:
	return ELEMENTS.has(element_id)
