class_name ColorCombo
extends RefCounted
## 颜色组合规则（纯逻辑，可单测，不依赖场景树）。
## 记录一个物体「依次被赋予了哪些元素」，并判定是否凑齐某种混合产物。
##
## 默认配方：红(burn) + 绿(grow) = 黄(yellow)——对同一物体先用红色能力、再用绿色能力，
## 物体即变为黄色物体（顺序无关）。
##
## 可复用：构造时传入 required（所需元素集合）与 result（产物 id），即可定义任意组合，
## 例如 ColorCombo.new(["burn", "freeze"], "purple") = 红+蓝=紫。
##
## 用法：
##   var combo := ColorCombo.new()
##   combo.apply("burn")        # 赋予红：真的改变状态返回 true（重复给同色返回 false）
##   combo.apply("grow")        # 赋予绿 → 凑齐
##   combo.is_complete()        # true
##   combo.result_id()          # "yellow"
##   combo.absorb()             # 抽走「最近一次」赋予的元素，返回其 id
##
## 信号：element_added / element_removed / completed / broken（供 UI、音效、机关监听）。

signal element_added(element_id: String)
signal element_removed(element_id: String)
signal completed(result_id: String)
signal broken(result_id: String)

## 凑齐产物所需的元素集合。
var required: Array = []
## 凑齐后产物的元素 id（如 "yellow"）。
var result: String = "yellow"

var _order: Array = []          # 按赋予顺序保存的元素 id（不重复）
var _present: Dictionary = {}   # element_id -> true


func _init(required_elements: Array = ["burn", "grow"], result_element: String = "yellow") -> void:
	required = required_elements.duplicate()
	result = result_element


## 赋予一个元素。真的改变状态返回 true；元素为空或已有同色返回 false（调用方据此避免消耗种子）。
func apply(element_id: String) -> bool:
	if element_id == "" or _present.has(element_id):
		return false
	var was := is_complete()
	_present[element_id] = true
	_order.append(element_id)
	element_added.emit(element_id)
	if not was and is_complete():
		completed.emit(result)
	return true


## 抽走「最近一次」赋予的元素（后进先出），返回其 id；无元素返回 ""。
func absorb() -> String:
	if _order.is_empty():
		return ""
	var was := is_complete()
	var element_id: String = _order.pop_back()
	_present.erase(element_id)
	element_removed.emit(element_id)
	if was and not is_complete():
		broken.emit(result)
	return element_id


## 是否含某个元素。
func has(element_id: String) -> bool:
	return _present.has(element_id)


## 是否已凑齐产物（= 变为黄色物体）。
func is_complete() -> bool:
	if required.is_empty():
		return false
	for el in required:
		if not _present.has(el):
			return false
	return true


## 当前产物 id：凑齐返回 result，否则 ""。
func result_id() -> String:
	return result if is_complete() else ""


## 当前含有的元素（按赋予顺序）。
func elements() -> Array:
	return _order.duplicate()


## 清空（若之前已凑齐，会发 broken）。
func reset() -> void:
	var was := is_complete()
	_order.clear()
	_present.clear()
	if was:
		broken.emit(result)


## 存档 / 还原。
func snapshot() -> Dictionary:
	return {"order": _order.duplicate()}


func restore(data: Dictionary) -> void:
	reset()
	for el in data.get("order", []):
		apply(str(el))
