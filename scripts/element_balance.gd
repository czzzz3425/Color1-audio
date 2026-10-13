class_name ElementBalance
extends Node2D
## 元素天平：内置左右两块元素踏板（ElementPlate），比较两边的元素状态。
##
## 当两边都压着【相同】的非空元素时「平衡」→ 发 toggled(true)。任一变化导致不匹配 → toggled(false)。
## 这是「比较器」原语——把两个传感器（元素踏板）组合成一条逻辑门，元素状态成了「同色配对的砝码」。
##
## 涌现：把两块燃烧木头分别推到左右踏板上 → 天平平衡 → 接的机关开门；
## 只压一边、或两边元素不同（左火右冰）→ 不平衡。
##
## 接线：其他机关（门/阀/灯）连 toggled(balanced: bool) 信号即可被天平驱动。

@onready var left: ElementPlate = $Left
@onready var right: ElementPlate = $Right

var _balanced := false

## 平衡状态变化时发出（true=两边同色非空配对，false=不匹配）。
signal toggled(balanced: bool)


func _ready() -> void:
	left.element_changed.connect(_recheck)
	right.element_changed.connect(_recheck)
	_recheck("")


func _recheck(_el: String) -> void:
	var l := left.detected_element()
	var r := right.detected_element()
	var b := (l != "" and l == r)
	if b != _balanced:
		_balanced = b
		toggled.emit(b)


func is_balanced() -> bool:
	return _balanced
