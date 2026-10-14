class_name Companion
extends Node2D
## 小跟班：首触对话结束后开始跟随玩家，并成为「上色/吸收」的执行者。
## 玩家鼠标指示（工作圈内）→ 跟班弧线飞过去执行 apply_color/absorb_color → 飞回玩家。
## 用 tween 做呼吸挤压、待机浮动、飞行弧线 + squash&stretch 落地弹跳，生动可爱。
## 结构：Node2D（本脚本）+ InteractArea（首触检测）+ Visual（占位色块，可换 Sprite2D）。

enum State { IDLE, FOLLOWING, TASK }

@export_group("Dialogue")
@export var dialogue_resource: DialogueResource
## 首触对话的起始 cue（留空 = 文件开头）。
@export var start_cue: String = ""
## 卡住超时提醒用的 cue 标题（~ hint_idle）。
@export var idle_reminder_cue: String = "hint_idle"

@export_group("Follow")
## 相对玩家的固定偏移（屏幕坐标，y 向下）。右下后方的跟班位置。
@export var follow_offset: Vector2 = Vector2(-96, 64)
## 指数平滑系数，越大贴得越紧。
@export var follow_speed: float = 8.0
## 小于此距离视为已到位。
@export var stop_distance: float = 8.0

@export_group("Cute")
## 移动时小跳的高度（像素）。
@export var hop_height: float = 12.0
## 移动时小跳的频率。
@export var hop_frequency: float = 7.0
## 待机上下浮动幅度。
@export var bob_amplitude: float = 4.0
## 待机浮动速度。
@export var bob_speed: float = 3.0
## 呼吸挤压幅度（scale.y 在 1±breathe_amount 间循环）。
@export var breathe_amount: float = 0.06

@export_group("Flight")
## 飞行弧线的抬升高度（像素）。
@export var flight_arc: float = 96.0
## 单程飞行时长（秒）。
@export var flight_duration: float = 0.5

@export_group("Reminders")
## 玩家卡住多久后提醒（秒）。
@export var idle_reminder_delay: float = 12.0
## 这个时间窗口内净位移小于此值就算「卡住」。
@export var idle_move_threshold: float = 64.0
## 两次提醒之间的最小间隔（秒）。
@export var idle_reminder_cooldown: float = 30.0

var state: int = State.IDLE
var player: Node2D

var _talking := false
var _visual: Node2D
var _area: Area2D
var _hop_phase := 0.0
var _idle_t := 0.0
var _idle_accum := 0.0
var _idle_ref_pos := Vector2.ZERO
var _last_reminder_ms := 0
var _facing := 1.0
var _breath_tween: Tween
var _fly_tween: Tween
var _task: Dictionary = {}    # 当前任务：{type, target, color, color_name, element}
var _carry: Dictionary = {}   # 吸收带回的种子 {element, amount}


func _ready() -> void:
	# 切关后小跟班已常驻；旧关重新实例化时会出现第二个，这里让后加载的自毁，避免重复。
	for c in get_tree().get_nodes_in_group("companion"):
		if is_instance_valid(c) and c != self:
			queue_free()
			return
	add_to_group("companion")
	player = get_tree().get_first_node_in_group("player") as Node2D
	_area = $InteractArea as Area2D
	_visual = $Visual as Node2D
	_area.body_entered.connect(_on_body_entered)
	if player != null:
		_idle_ref_pos = player.global_position
	_start_breathing()


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if state == State.TASK:
		return   # 飞行/执行动画由 tween 控制
	if state == State.FOLLOWING and not _talking:
		_follow(delta)
		_check_reminders(delta)
	else:
		_idle_bob(delta)


## —— 跟随 / 待机动效 ——

func _follow(delta: float) -> void:
	var target := player.global_position + follow_offset
	var to := target - global_position
	if to.length() <= stop_distance:
		_idle_bob(delta)
		return
	var speed := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(target, speed)
	if absf(to.x) > 1.0:
		_facing = 1.0 if to.x > 0.0 else -1.0
	_visual.scale.x = _facing
	_hop_phase += delta * hop_frequency
	_visual.position.y = -absf(sin(_hop_phase)) * hop_height


func _idle_bob(delta: float) -> void:
	_visual.scale.x = _facing
	_idle_t += delta
	_visual.position.y = sin(_idle_t * bob_speed) * bob_amplitude


func _start_breathing() -> void:
	_breath_tween = create_tween().set_loops()
	_breath_tween.tween_property(_visual, "scale:y", 1.0 + breathe_amount, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath_tween.tween_property(_visual, "scale:y", 1.0 - breathe_amount, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_breathing() -> void:
	if _breath_tween and _breath_tween.is_valid():
		_breath_tween.kill()


## —— 任务入口（玩家调用）——

## 是否已招募（首触对话结束、开始跟随之后）。
func is_recruited() -> bool:
	return state != State.IDLE


## 跟班当前是否空闲、能接任务（已招募 + 不在任务中 + 不在对话）。
func is_available() -> bool:
	return state == State.FOLLOWING and not _talking


## 玩家指示：让跟班飞过去给 target 上色。返回是否接受（忙则拒绝）。
func paint(target: Node, color: Color, color_name: String, element: String) -> bool:
	if not is_available():
		return false
	_task = {"type": "paint", "target": target, "color": color, "color_name": color_name, "element": element}
	_begin_task()
	return true


## 玩家指示：让跟班飞过去从 target 抽色并带回来。返回是否接受。
func absorb(target: Node) -> bool:
	if not is_available():
		return false
	_task = {"type": "absorb", "target": target}
	_begin_task()
	return true


## 玩家指示：让跟班飞过去与 target 交互（如开宝箱）。返回是否接受。
func interact(target: Node) -> bool:
	if not is_available():
		return false
	_task = {"type": "interact", "target": target}
	_begin_task()
	return true


## —— 任务执行（飞出 → 落地 → 执行 → 飞回）——

func _begin_task() -> void:
	state = State.TASK
	_visual.position = Vector2.ZERO
	_visual.rotation = 0.0
	_stop_breathing()
	var target: Node = _task["target"]
	if not is_instance_valid(target):
		_finish_task()
		return
	_fly_to(target.global_position, _do_task)


## 弧线飞向 end，落地时回调 on_arrive。
func _fly_to(end: Vector2, on_arrive: Callable) -> void:
	_kill_fly()
	var start := global_position
	var dir := end - start
	_facing = 1.0 if dir.x >= 0.0 else -1.0
	_visual.scale.x = _facing
	var mid := (start + end) * 0.5
	mid.y -= flight_arc
	var tween := create_tween()
	# 起飞蓄力：压扁 → 拉长。
	tween.tween_property(_visual, "scale:y", 0.6, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_visual, "scale:y", 1.15, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 弧线飞行。
	tween.tween_method(_set_arc_pos.bind(start, mid, end), 0.0, 1.0, flight_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(on_arrive)
	_fly_tween = tween


func _set_arc_pos(t: float, a: Vector2, b: Vector2, c: Vector2) -> void:
	global_position = _quad_bezier(a, b, c, t)


func _quad_bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var ab := a.lerp(b, t)
	var bc := b.lerp(c, t)
	return ab.lerp(bc, t)


## 落地：squash&stretch 压扁回弹，完成后执行任务动作。
func _do_task() -> void:
	_visual.scale = Vector2(1.5 * _facing, 0.5)
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector2(_facing, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_execute_task)


func _execute_task() -> void:
	var target: Node = _task["target"]
	if not is_instance_valid(target):
		_finish_task()
		return
	if _task["type"] == "paint":
		var applied: bool = bool(target.call("apply_color", _task["color"], _task["color_name"], global_position))
		if not applied and player != null and player.has_method("refund_element"):
			player.call("refund_element", _task["element"], 1)
	elif _task["type"] == "absorb":  # 抽色后带回来，飞回玩家才结算。
		var info: Dictionary = target.call("absorb_color")
		var el := str(info.get("element", ""))
		if el != "":
			_carry = {"element": el, "amount": int(info.get("amount", 1))}
	else:  # interact：落地后让目标执行交互（如开宝箱）。
		if target.has_method("interact"):
			target.call("interact")
	_fly_back()


func _fly_back() -> void:
	var home := player.global_position + follow_offset
	_fly_to(home, _on_return_arrive)


## 飞回落地：squash 回弹，完成后结算并恢复跟随。
func _on_return_arrive() -> void:
	_visual.scale = Vector2(1.5 * _facing, 0.5)
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector2(_facing, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_finish_task)


func _finish_task() -> void:
	if not _carry.is_empty() and player != null and player.has_method("receive_element"):
		player.call("receive_element", _carry["element"], _carry["amount"])
	_carry = {}
	_task = {}
	state = State.FOLLOWING
	if player != null:
		_idle_ref_pos = player.global_position
	_start_breathing()


func _kill_fly() -> void:
	if _fly_tween and _fly_tween.is_valid():
		_fly_tween.kill()


## —— 对话触发 / 提醒 ——

func _on_body_entered(body: Node) -> void:
	if state != State.IDLE or _talking:
		return
	if not body.is_in_group("player"):
		return
	if dialogue_resource == null:
		push_warning("Companion '%s' 未配置 dialogue_resource" % name)
		return
	_area.set_deferred("monitoring", false)   # 首触后关掉触碰检测，之后改跟随
	_play_dialogue(start_cue)


func _play_dialogue(cue: String, resource: DialogueResource = null) -> void:
	var source := resource if resource != null else dialogue_resource
	if source == null:
		return
	_talking = true
	if not StoryDirector.request(self, source, cue, Callable(), _on_own_dialogue_finished, _on_own_dialogue_cancelled):
		_talking = false


func _on_own_dialogue_finished() -> void:
	if not _talking:
		return
	_talking = false
	if state == State.IDLE:
		state = State.FOLLOWING
		if player != null:
			_idle_ref_pos = player.global_position


func _on_own_dialogue_cancelled() -> void:
	_talking = false


func _check_reminders(delta: float) -> void:
	if StoryDirector.is_busy():
		return
	# 1. 位置标记提醒
	for hint in get_tree().get_nodes_in_group("companion_hint"):
		if not GameState.is_in_current_scene(hint):
			continue
		var h: CompanionHint = hint as CompanionHint
		if h == null or not h.can_trigger():
			continue
		if player.global_position.distance_to(h.global_position) <= h.radius:
			_play_dialogue(h.trigger(), h.dialogue_resource)
			return

	# 2. 卡住超时提醒
	_idle_accum += delta
	if _idle_accum < idle_reminder_delay:
		return
	if player.global_position.distance_to(_idle_ref_pos) >= idle_move_threshold:
		# 没卡住，只是走到别处了：重开窗口
		_idle_accum = 0.0
		_idle_ref_pos = player.global_position
		return
	var now := Time.get_ticks_msec()
	if now - _last_reminder_ms >= int(idle_reminder_cooldown * 1000.0):
		_last_reminder_ms = now
		_play_dialogue(idle_reminder_cue)
	_idle_accum = 0.0
	_idle_ref_pos = player.global_position
