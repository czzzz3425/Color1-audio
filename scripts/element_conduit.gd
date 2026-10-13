class_name ElementConduit
extends Node2D
## 元素导管（合并棱镜）：把输入端喂入的元素投到输出端，让元素的通用效果在那里发生。
## 一条规则：一端进什么，另一端出什么。
##   红 → 输出端点火：给范围内可上色物上红（点燃），并放一个短暂的火光脉冲（热源+光源，
##        能远程开阀、照暗房、引焰虱）。
##   蓝 → 输出端冻结：给范围内可上色物上蓝（远程冻铁球 / 冻焰虱）。
##   绿（生长）搁置。
## 自身不冻结（被动导线）；「停流」= 不喂即可。多段串联 = 一个输出接到下一个输入。
##
## 需要子节点：Output（Node2D，输出落点标记）。输入点 = 本节点（contains_point 命中即喂）。
## ⚠️ 不要定义 is_frozen()（player._water_at_mouse 会误判成水格崩溃）。

const Rules := preload("res://scripts/element/element_rules.gd")

@export_group("输出")
@export var output_radius: float = 140.0       # 输出端生效半径
@export var pulse_duration: float = 2.5        # 红脉冲（火+光）持续时长
@export var pulse_light_radius: float = 320.0  # 红脉冲的光斑半径
@export_group("输入")
@export var hit_radius: float = 40.0           # 输入端点击命中半径

@onready var output: Node2D = get_node_or_null("Output") as Node2D


func _ready() -> void:
	add_to_group("colorable")


func _output_pos() -> Vector2:
	return output.global_position if output != null else global_position


# —— colorable 契约 ——
func apply_color(c: Color, color_name: String = "", _from_pos: Vector2 = Vector2.INF) -> bool:
	var element := Rules.element_for_color_name(color_name)
	if element == "":
		return false
	return _emit(element, c)


func has_color() -> bool:
	return false   # 导线本身不存元素


func absorb_color() -> Dictionary:
	return {"element": "", "color": Color.WHITE, "color_name": ""}


func contains_point(world_pos: Vector2) -> bool:
	return global_position.distance_to(world_pos) <= hit_radius


## 在输出端触发元素通用效果：扫范围内的可上色物逐个 apply_color；红额外放一个火脉冲。
func _emit(element: String, c: Color) -> bool:
	var cfg := Rules.config(element)
	var pos := _output_pos()
	var applied := false
	for obj in get_tree().get_nodes_in_group("colorable"):
		if not GameState.is_in_current_scene(obj):
			continue
		if obj == self:
			continue
		var n := obj as Node2D
		if n == null or not is_instance_valid(n):
			continue
		if not n.has_method("apply_color"):
			continue
		if pos.distance_to(n.global_position) <= output_radius:
			if bool(n.call("apply_color", c, cfg.get("color_name", ""), pos)):
				applied = true
	if element == "burn":
		_spawn_pulse(pos)
		applied = true   # 远程投火本身就有火+光，永远算一次有效发射
	return applied


## 红脉冲：输出端短暂出现一个热源+光源（开阀 / 照暗房 / 引焰虱），到时自动熄灭。
func _spawn_pulse(pos: Vector2) -> void:
	var pulse := Node2D.new()
	pulse.name = "ProjectedFlame"
	pulse.add_to_group("heat_source")
	add_child(pulse)
	pulse.global_position = pos
	var l := LightSource.new()
	l.radius = pulse_light_radius
	pulse.add_child(l)
	get_tree().create_timer(pulse_duration).timeout.connect(pulse.queue_free)
