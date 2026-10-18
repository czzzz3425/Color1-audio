class_name ElementGate
extends StaticBody2D
## 元素门：由元素传感器（ElementPlate / ElementBalance）驱动的挡路门。
##
## 与元素阀同款「每帧轮询条件 → 开合碰撞」模式，但条件来源是传感器而非 heat_source 组。
## 把「传感器」和「挡路门」解耦：传感器只发状态，门负责开合。这样任意传感器都能接任意门。
##
## - sensor_path 指向 ElementBalance → 平衡才开（忽略 required_element）。
## - sensor_path 指向 ElementPlate（有 detected_element()）→ 检测到的元素满足 required_element 才开
##   （required_element == "" 表示任意非空元素）。
##
## 需要子节点：Visual（门贴图 CanvasItem）、Collision（CollisionShape2D，阻挡玩家）。

@export_group("传感器")
@export var sensor_path: NodePath
## 仅对 ElementPlate 生效：需要识别的元素（"burn"/"freeze"/"grow"；"" = 任意非空元素）。
@export var required_element := ""

@export_group("视觉")
@export var closed_color := Color(0.7, 0.3, 0.3)
@export var open_color := Color(0.5, 0.55, 0.5)

@onready var visual: CanvasItem = get_node_or_null("Visual") as CanvasItem
@onready var collision: CollisionShape2D = get_node_or_null("Collision") as CollisionShape2D

var _open := false


func _ready() -> void:
	collision_layer = 2   # 挡玩家（玩家 collision_mask 含层 2）
	collision_mask = 0
	_apply()


func _physics_process(_delta: float) -> void:
	var want := _condition_met()
	if want != _open:
		var was_open := _open
		_open = want
		_apply()
		# 只在「从关到开」的瞬间提示一次，避免每帧刷屏；关回去不提示。
		if _open and not was_open:
			GameState.notice.emit("某处的大门打开了")


func _condition_met() -> bool:
	var sensor := get_node_or_null(sensor_path)
	if sensor == null or not is_instance_valid(sensor):
		return false
	if sensor is ElementBalance:
		return sensor.is_balanced()
	if sensor.has_method("detected_element"):
		var el: String = sensor.call("detected_element")
		if required_element == "":
			return el != ""
		return el == required_element
	return false


func _apply() -> void:
	if collision != null:
		collision.set_deferred("disabled", _open)
	if visual != null:
		var t := create_tween()
		# 开门淡出、关门恢复，保持门贴图原色（不再整扇染色）。
		t.tween_property(visual, "modulate:a", 0.0 if _open else 1.0, 0.2)
