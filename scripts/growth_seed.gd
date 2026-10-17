class_name GrowthSeed
extends Node2D
## 藤种：绿(grow)激活 → 朝 grow_dir 长出一段可站立的藤蔓（改写空间通行性）。
##
## 这是「绿改写空间」的涌现载体——藤蔓是玩家/规则造出来的新地形：
##   · 成桥：藤蔓横跨水/坑/缺口，玩家踩上去（实心障碍 layer 2）跨过原本不可走的地方。
##   · 藤封锁：藤蔓长在通道里 = 新增障碍挡路。
##   · 可反作用：红烧掉藤蔓（桥毁/路开），蓝冻住藤蔓（固化，烧不掉）。
##
## 绿(grow)   → 长藤蔓（NONE→GROWN）。已长/已冻再给绿无效（不耗种子）。
## 红(burn)   → 烧藤蔓（GROWN→NONE）。没长或冻住都烧不掉（不耗种子）。
## 蓝(freeze) → 冻藤蔓（GROWN→FROZEN）。冻住的藤蔓烧不掉。
## 吸收(右击) → GROWN 收回藤蔓返绿种子（可反复搭桥/改方向）；FROZEN 解冻返蓝种子。
##
## 需要子节点：SeedVisual（种子标记 Polygon2D）、Vine（StaticBody2D 藤蔓桥，
## 内含 VineVisual Polygon2D + VineCollision CollisionShape2D）。
## 藤蔓始终沿种子局部 +X 延伸；要朝别的方向，改 grow_dir（或直接旋转本节点）。
## ⚠️ 不要定义 is_frozen()（player._water_at_mouse 会误判成水格崩溃）。

const Rules := preload("res://scripts/element/element_rules.gd")

@export_group("生长")
## 藤蔓延伸方向（单位向量，屏幕坐标 y 向下）。默认向右。
@export var grow_dir := Vector2.RIGHT
@export_range(32.0, 1024.0, 8.0) var vine_length := 256.0
@export_range(8.0, 128.0, 4.0) var vine_thickness := 40.0
## 增殖：藤蔓末端碰到相邻藤种时自动连锁（绿蔓延）。0 = 不连锁。
@export_range(0.0, 512.0, 8.0) var chain_radius := 96.0

@export_group("视觉")
@export var seed_color := Color(0.62, 0.46, 0.3)
@export var vine_color := Color(0.35, 0.8, 0.4)
@export var frozen_color := Color(0.4, 0.65, 1.0)
@export var hit_radius := 56.0

@export_group("状态")
@export var state_id: String = ""

var seed_visual: Sprite2D
var vine: StaticBody2D
var vine_visual: Sprite2D
var vine_collision: CollisionShape2D

var _grown := false
var _frozen := false
var _vine_cells: Array = []   # 藤蔓覆盖的格子快照（{pos, walkable, flow}），收回时恢复
var _bridged_water: Array = []   # 被藤桥覆盖的深水 WaterCell（临时禁用碰撞），收回时恢复


func _ready() -> void:
	add_to_group("colorable")
	add_to_group("stateful")
	add_to_group("growth_seed")
	if state_id == "":
		state_id = name
	if grow_dir == Vector2.ZERO:
		grow_dir = Vector2.RIGHT
	grow_dir = grow_dir.normalized()
	rotation = grow_dir.angle()   # 整个种子朝向 grow_dir，藤蔓在局部 +X 延伸
	seed_visual = get_node_or_null("SeedVisual") as Sprite2D
	vine = get_node_or_null("Vine") as StaticBody2D
	if vine != null:
		vine_visual = vine.get_node_or_null("VineVisual") as Sprite2D
		vine_collision = vine.get_node_or_null("VineCollision") as CollisionShape2D
		vine.position = Vector2.ZERO
		vine.rotation = 0.0
		# 藤桥跨水/坑时不设物理碰撞：通行性由 set_bridged + HeightMap 接管，
		# 否则这层 layer 2 会横在桥中段挡住玩家（只能走第一格）。
		# 桥两侧的深水碰撞仍在，玩家不会从侧面掉出去。
		vine.collision_layer = 0
		vine.collision_mask = 0
		if vine_collision != null:
			vine_collision.position = Vector2(vine_length * 0.5, 0.0)
			vine_collision.set_deferred("disabled", true)
		if vine_visual != null:
			vine_visual.centered = true
			vine_visual.rotation = -PI * 0.5
			vine_visual.position = Vector2(vine_length * 0.5, 0.0)
			# 贴图版：按贴图原始尺寸把藤蔓图拉伸到 vine_length × vine_thickness，
			# 左端锚在种子处（centered=true，position.x=长度一半），随 vine.scale.x 生长。
			var tex := vine_visual.texture
			var tex_size := tex.get_size() if tex != null else Vector2(vine_thickness, vine_length)
			vine_visual.scale = Vector2(vine_thickness / tex_size.x, vine_length / tex_size.y)
		vine.scale = Vector2(0.001, 1.0)   # 收拢：scale.x=0 会触发警告，用 0.001 近似
	_apply_visual()


## 视觉统一刷新：种子发芽变绿、藤蔓按 frozen/grown 换色。
func _apply_visual() -> void:
	if seed_visual != null:
		seed_visual.modulate = vine_color if _grown else seed_color
	if vine_visual != null:
		vine_visual.modulate = frozen_color if _frozen else vine_color


## 直接设藤蔓终态（restore 用）；生长/收回动画走 _grow_vine/_shrink_vine。
func _set_vine(on: bool) -> void:
	_restore_vine_cells()
	if vine == null:
		return
	vine.scale = Vector2(1.0 if on else 0.001, 1.0)
	if vine_collision != null:
		vine_collision.set_deferred("disabled", not on)
	if on:
		_capture_vine_cells()


func _grow_vine() -> void:
	_grown = true
	if vine == null:
		return
	if vine_collision != null:
		vine_collision.set_deferred("disabled", false)
	var t := create_tween()
	t.tween_property(vine, "scale:x", 1.0, 0.4)
	_apply_visual()
	_capture_vine_cells()   # 藤桥改写通行性：覆盖深水/坑，让玩家能站上来
	# 增殖：藤桥展开后连锁相邻藤种（异步，避免深递归，视觉上依次蔓延）。
	get_tree().create_timer(0.45).timeout.connect(_chain)


func _shrink_vine() -> void:
	_grown = false
	_frozen = false
	_restore_vine_cells()   # 藤桥收回/烧掉：恢复格子原通行性
	if vine == null:
		return
	var t := create_tween()
	t.tween_property(vine, "scale:x", 0.001, 0.3)
	t.tween_callback(_on_shrink_done)
	_apply_visual()


func _on_shrink_done() -> void:
	if vine_collision != null:
		vine_collision.set_deferred("disabled", true)


## 增殖：藤蔓末端附近有未生长的相邻藤种时，连锁激活它（绿蔓延成链）。
func _chain() -> void:
	if chain_radius <= 0.0 or not _grown:
		return
	var tip := global_position + grow_dir * vine_length
	for obj in get_tree().get_nodes_in_group("growth_seed"):
		if obj == self:
			continue
		if not GameState.is_in_current_scene(obj):
			continue
		var other := obj as GrowthSeed
		if other == null or not is_instance_valid(other):
			continue
		if bool(other.get("_grown")):
			continue
		if tip.distance_to(other.global_position) <= chain_radius:
			other.apply_color(Color(0.35, 0.85, 0.4), "绿", tip)


## 快照藤蔓覆盖的格子并改写为可站 + 断流。藤蔓是「造出来的地形」，得改 HeightMap
## 通行性——光有物理碰撞，玩家 _update_water_wade 仍会判成掉水里（被冲走）。
func _capture_vine_cells() -> void:
	_vine_cells.clear()
	var start := global_position
	var end := global_position + grow_dir * vine_length
	var steps := maxi(1, int(vine_length / (HeightMap.CELL * 0.5)))
	var perp := Vector2(-grow_dir.y, grow_dir.x).normalized()
	var half := vine_thickness * 0.5
	var seen: Dictionary = {}   # grid(Vector2i) -> true，同格只记第一次（未修改前）的原值
	for i in range(steps + 1):
		var base := start.lerp(end, float(i) / float(steps))
		# 沿桥宽采样（中心 + 两侧），覆盖整条桥的通行性，避免玩家在桥边缘擦到未桥接的水。
		for off in [-half, 0.0, half]:
			var p: Vector2 = base + perp * float(off)
			var grid := Vector2i(floor(p.x / HeightMap.CELL), floor(p.y / HeightMap.CELL))
			if seen.has(grid):
				continue
			seen[grid] = true
			_vine_cells.append({
				"grid": grid,
				"walkable": HeightMap.is_walkable(p),
				"flow": HeightMap.flow_at(p),
			})
			HeightMap.set_walkable(p, true)
			HeightMap.set_flow(p, 0)
	_bridge_water()


## 藤桥跨水：禁用脚下深水 WaterCell 的碰撞。「成桥跨水」的关键——光改 HeightMap
## 通行性不够，深水的物理碰撞（layer 2）还在挡路；得像结冰那样把碰撞也关掉。
## 只覆盖未结冰的深水（set_bridged 内部会跳过浅水/冰）。沿藤桥中心线采样命中判断。
func _bridge_water() -> void:
	_bridged_water.clear()
	var start := global_position
	var end := global_position + grow_dir * vine_length
	var steps := maxi(1, int(vine_length / (HeightMap.CELL * 0.5)))
	var perp := Vector2(-grow_dir.y, grow_dir.x).normalized()
	var half := vine_thickness * 0.5
	for obj in get_tree().get_nodes_in_group("colorable"):
		if not is_instance_valid(obj):
			continue
		if not obj.has_method("set_bridged") or not obj.has_method("contains_point"):
			continue
		var hit := false
		for i in range(steps + 1):
			var base := start.lerp(end, float(i) / float(steps))
			for off in [-half, 0.0, half]:
				if bool(obj.call("contains_point", base + perp * float(off))):
					hit = true
					break
			if hit:
				break
		if hit:
			obj.call("set_bridged", true)
			_bridged_water.append(obj)


## 恢复藤蔓覆盖格子的原通行性（收回/烧掉藤蔓后，深水重新挡路）。
func _restore_vine_cells() -> void:
	for c in _vine_cells:
		var grid: Vector2i = c["grid"]
		var walkable: bool = c["walkable"]
		var flow: int = c["flow"]
		var world := Vector2(grid.x * HeightMap.CELL + HeightMap.CELL * 0.5, grid.y * HeightMap.CELL + HeightMap.CELL * 0.5)
		HeightMap.set_walkable(world, walkable)
		HeightMap.set_flow(world, flow)
	_vine_cells.clear()
	for w in _bridged_water:
		if is_instance_valid(w):
			w.call("set_bridged", false)
	_bridged_water.clear()


# —— colorable 契约 ——
func apply_color(_c: Color, color_name: String = "", _from_pos: Vector2 = Vector2.INF) -> bool:
	var element := Rules.element_for_color_name(color_name)
	if element == "grow":
		if _grown:
			return false
		_grow_vine()
		return true
	if element == "burn":
		if not _grown or _frozen:
			return false   # 没长 / 冻住都烧不掉
		_shrink_vine()
		return true
	if element == "freeze":
		if not _grown or _frozen:
			return false
		_frozen = true
		_apply_visual()
		return true
	return false


func has_color() -> bool:
	return _grown


func absorb_color() -> Dictionary:
	if _frozen:
		_frozen = false
		_apply_visual()
		var fcfg := Rules.config("freeze")
		return {"element": "freeze", "color": fcfg["color"], "color_name": fcfg["color_name"], "amount": 1}
	if _grown:
		_shrink_vine()
		var gcfg := Rules.config("grow")
		return {"element": "grow", "color": gcfg["color"], "color_name": gcfg["color_name"], "amount": 1}
	return {"element": "", "color": Color.WHITE, "color_name": ""}


func contains_point(world_pos: Vector2) -> bool:
	if global_position.distance_to(world_pos) <= hit_radius:
		return true
	if _grown:
		var mid := global_position + grow_dir * (vine_length * 0.5)
		return mid.distance_to(world_pos) <= maxf(hit_radius, vine_thickness * 0.5 + 12.0)
	return false


# —— 状态持久化 ——
func save_state() -> Dictionary:
	return {"grown": _grown, "frozen": _frozen}


func restore_state(data: Dictionary) -> void:
	_grown = data.get("grown", false)
	_frozen = data.get("frozen", false)
	_set_vine(_grown)
	_apply_visual()
