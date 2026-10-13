class_name FireLouse
extends CharacterBody2D
## 焰虱（带星怪物）：黑暗迷宫里的敌对红源。
##
## 状态机：
##   DORMANT  潜伏——静止在暗处，只留一点微光（星标），红种子随时间回充到满
##   CHASE    追击——感光（扫 light_source 组），追最近的光源（玩家/火把），满亮
##   FROZEN   冻结——被赋予蓝后定身，灯保持亮（活物冻结=定身，不碎裂），限时解冻
##   RETREAT  耗竭——红被吸空后熄灯逃跑，跑远后转回 DORMANT 重新充电
##
## 交互（colorable 契约）：
##   给蓝(apply_color) → 冻结定身；给红 → 无效（它自己是红源，喂食没意义）
##   吸收(absorb_color) → 抢走背上一颗红种子，吸空则耗竭逃跑
##   碰到玩家 → 抢玩家 1 颗红（没有红就击退）
##
## 碰撞：CharacterBody2D，collision_layer=0（不挡人）、collision_mask=2（撞墙），与萤虫一致。
## 玩家/跟班可穿过它，接触判定用距离不用物理。
## ⚠️ 同萤虫：不要加 is_frozen()（player._water_at_mouse 会误判成水格崩溃）。

const Rules := preload("res://scripts/element/element_rules.gd")

enum State { DORMANT, CHASE, FROZEN, RETREAT }

@export_group("种子")
@export var max_seeds: int = 3
@export var recharge_interval: float = 30.0   # 潜伏时补 1 颗红的时长

@export_group("感知 / 追击")
@export var sense_radius: float = 2400.0      # 感光半径（追这个范围内的最近光源）
@export var near_radius: float = 90.0         # 近身必醒
@export var chase_speed: float = 150.0        # 基础追击速度
@export var speed_per_seed: float = 25.0      # 每颗红加的速度（吸红=削它）
@export var contact_radius: float = 40.0      # 碰到玩家的距离判定
@export var steal_cooldown: float = 1.0       # 抢红冷却
@export var retreat_distance: float = 400.0   # 耗竭后跑多远才转潜伏

@export_group("冻结")
@export var freeze_duration: float = 10.0     # 冻结持续时长（到期解冻）

@export_group("发光")
@export var light_radius: float = 360.0
@export var glint_radius: float = 60.0

@export_group("视觉")
@export var glow_color: Color = Color(1.0, 0.35, 0.15)
@export var frozen_color: Color = Color(0.4, 0.65, 1.0)
@export var dim_color: Color = Color(0.3, 0.3, 0.3)
@export var hit_radius: float = 52.0

@onready var visual: Node2D = $Visual
@onready var light: LightSource = $Light

var _state: int = State.DORMANT
var _seeds: int = 0
var _freeze_timer: float = 0.0
var _recharge_timer: float = 0.0
var _steal_cd: float = 0.0
var _player: Player = null
var _gems: Array[Node2D] = []


func _ready() -> void:
	add_to_group("colorable")
	collision_layer = 0
	collision_mask = 2
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_player = get_tree().get_first_node_in_group("player") as Player
	for i in 3:
		_gems.append(get_node_or_null("Gem%d" % i) as Node2D)
	_seeds = max_seeds
	_refresh()


func _physics_process(delta: float) -> void:
	_steal_cd = maxf(0.0, _steal_cd - delta)
	match _state:
		State.DORMANT:
			_dormant(delta)
		State.CHASE:
			_chase(delta)
		State.FROZEN:
			_frozen(delta)
		State.RETREAT:
			_retreat(delta)


# —— 状态行为 ——
func _dormant(delta: float) -> void:
	velocity = Vector2.ZERO
	# 回充：缺多少补多少，补到满为止。
	if _seeds < max_seeds:
		_recharge_timer += delta
		if _recharge_timer >= recharge_interval:
			_recharge_timer = 0.0
			_seeds += 1
			_refresh()
	# 感光 / 近身 → 醒。
	if _nearest_light() != null or _player_near():
		_state = State.CHASE
		_refresh()


func _chase(_delta: float) -> void:
	var target := _nearest_light()
	if target == null:
		_state = State.DORMANT   # 目标消失（灯灭了 / 太远）
		_refresh()
		return
	var dir := global_position.direction_to(target.global_position)
	velocity = dir * (chase_speed + speed_per_seed * float(_seeds))
	move_and_slide()
	# 碰到玩家：抢红；没红可抢就击退。
	if _steal_cd <= 0.0 and _player != null and is_instance_valid(_player):
		if global_position.distance_to(_player.global_position) < contact_radius:
			_steal_cd = steal_cooldown
			if not _player.steal_element("burn", 1):
				_player.knockback(dir, 400.0)


func _frozen(delta: float) -> void:
	velocity = Vector2.ZERO
	_freeze_timer -= delta
	if _freeze_timer <= 0.0:
		_state = State.CHASE if _nearest_light() != null else State.DORMANT
		_refresh()


func _retreat(_delta: float) -> void:
	var away := Vector2.RIGHT
	if _player != null and is_instance_valid(_player):
		away = global_position - _player.global_position
		if away.length() < 1.0:
			away = Vector2.from_angle(randf() * TAU)
	velocity = away.normalized() * chase_speed * 0.6
	move_and_slide()
	# 离玩家够远（或玩家没了）→ 潜伏充电。
	if _player == null or not is_instance_valid(_player) \
			or global_position.distance_to(_player.global_position) > retreat_distance:
		_state = State.DORMANT
		_refresh()


# —— 感知 ——
func _nearest_light() -> Node2D:
	var best: Node2D = null
	var best_d := sense_radius
	for src in get_tree().get_nodes_in_group("light_source"):
		if not (src is LightSource):
			continue
		if not _is_player_light(src):
			continue
		var d := global_position.distance_to((src as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = src
	return best


## 只有玩家自带的微光才算追猎目标；火把/其它燃烧光不再吸引它。
func _is_player_light(src: Node) -> bool:
	var cur: Node = src.get_parent()
	while cur != null:
		if cur.is_in_group("player"):
			return true
		cur = cur.get_parent()
	return false


func _player_near() -> bool:
	return _player != null and is_instance_valid(_player) \
		and global_position.distance_to(_player.global_position) < near_radius


# —— colorable 契约 ——
func has_color() -> bool:
	return _seeds > 0


func contains_point(world_pos: Vector2) -> bool:
	return global_position.distance_to(world_pos) <= hit_radius


func apply_color(_c: Color, color_name: String = "", _from_pos: Vector2 = Vector2.INF) -> bool:
	# 给蓝 → 冻结定身；给红 → 无效（它是红源，喂食没意义）。同状态重复给返回 false 不耗种子。
	var element: String = Rules.element_for_color_name(color_name)
	if element == "freeze" and _state != State.FROZEN:
		_state = State.FROZEN
		_freeze_timer = freeze_duration
		_refresh()
		return true
	return false


func absorb_color() -> Dictionary:
	if _seeds <= 0:
		return {"element": "", "color": Color.WHITE, "color_name": ""}
	_seeds -= 1
	if _seeds <= 0:
		_state = State.RETREAT   # 吸空 → 熄灯逃跑
	_refresh()
	var cfg: Dictionary = Rules.config("burn")
	return {
		"element": "burn",
		"color": cfg.get("color", Color.WHITE),
		"color_name": cfg.get("color_name", ""),
		"amount": 1,
	}


func _refresh() -> void:
	# 追击态（红光大亮）才算热源：能开火驱动机关；潜伏/冻结/耗竭都不是。
	if _state == State.CHASE:
		add_to_group("heat_source")
	else:
		remove_from_group("heat_source")
	# 光始终在 light_source 组（潜伏/耗竭=微光星标，追击/冻结=满亮），靠调半径区分。
	if light != null:
		var full: bool = _state == State.CHASE or _state == State.FROZEN
		light.radius = light_radius if full else glint_radius
	if visual != null:
		var tint: Color = dim_color
		if _state == State.CHASE:
			tint = glow_color
		elif _state == State.FROZEN:
			tint = frozen_color
		visual.self_modulate = tint
	# 背上星形种子：剩几颗亮几颗。
	for i in _gems.size():
		if _gems[i] != null:
			_gems[i].visible = i < _seeds
