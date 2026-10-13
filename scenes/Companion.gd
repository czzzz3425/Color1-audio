extends Line2D

@export var target: Node2D # 确保在检查器里把 Companion 拖进来
@export var max_points: int = 15 # 拖尾最长保留多少个点
@export var min_distance: float = 8.0 # 每移动多少像素记录一个点
@export var jitter_amount: float = 2.0 # 手绘抖动幅度（推荐 1.0 ~ 3.0）
@export var tail_offset: Vector2 = Vector2(0, 15) # 尾巴尖的偏移量，默认向下15像素

@export_group("静止收尾设置")
@export var stop_speed_threshold: float = 10.0 # 速度低于多少算静止
@export var erase_speed: int = 3 # 静止时每帧删除几个点（调大消失更快，调到20以上等于瞬间消失）

var points_array: PackedVector2Array = []
var last_target_pos: Vector2

## 未选中任何颜色时的兜底拖尾色（玩家拿到颜色之前默认黑色）。
const DEFAULT_TRAIL_COLOR := Color.BLACK

func _ready():
	# 1. 基础手绘风格设置
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	width = 10.0

	# 2. 颜色渐变：头部实、尾部透明，头部色随玩家当前选中的颜色走。
	_set_trail_color(_current_trail_color())

	# 3. 宽度曲线：头部粗，尾部细
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.0))
	width_curve = curve

	# 4. 玩家换色时同步拖尾颜色。
	var p := get_tree().get_first_node_in_group("player")
	if p != null and p.has_signal("color_changed"):
		p.connect("color_changed", _on_color_changed)
		
	if target:
		last_target_pos = target.global_position


## 当前应该用的拖尾颜色：玩家选中了颜色用选中色，否则用默认黑色。
func _current_trail_color() -> Color:
	var p := get_tree().get_first_node_in_group("player")
	if p == null or str(p.get("selected_color_name")) == "无":
		return DEFAULT_TRAIL_COLOR
	return p.get("selected_color")


## 玩家换色：选中色同步到拖尾，未选中则回到默认黑色。
func _on_color_changed(new_color: Color, color_name: String) -> void:
	_set_trail_color(DEFAULT_TRAIL_COLOR if color_name == "无" else new_color)


## 用 color 重建渐变：头部不透明、尾部完全透明，形成收尾淡出。
func _set_trail_color(color: Color) -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(color.r, color.g, color.b, 1.0))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	gradient = grad


func _process(delta):
	if not target:
		return
		
	# 👈 计算起点：用幽灵当前位置 + 尾巴偏移量
	var start_pos = target.global_position + tail_offset
	
	# 👈 核心修改：判断小跟班是否在移动
	var is_moving = false
	if target.get("velocity"):
		# 如果有 velocity 属性，用速度判断
		is_moving = target.velocity.length() > stop_speed_threshold
	else:
		# 如果没有 velocity 属性，用位置差判断
		is_moving = start_pos.distance_to(last_target_pos) > 1.0
		last_target_pos = start_pos

	if is_moving:
		# --- 移动时：正常记录点 ---
		if points_array.is_empty() or start_pos.distance_to(points_array[-1]) > min_distance:
			# 加入手绘抖动
			var jitter = Vector2(
				randf_range(-jitter_amount, jitter_amount),
				randf_range(-jitter_amount, jitter_amount)
			)
			
			points_array.append(start_pos + jitter)
			
			# 限制最大长度，删掉最旧的
			if points_array.size() > max_points:
				points_array.remove_at(0)
				
			points = points_array
	else:
		# --- 静止时：快速抹除拖尾（收笔效果） ---
		if points_array.size() > 0:
			# 每帧删除 erase_speed 个点
			for i in range(erase_speed):
				if points_array.size() > 0:
					points_array.remove_at(0)
			points = points_array
