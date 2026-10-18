class_name BossEncounter
extends Node2D
## 一整套可拖拽的 Boss 战斗预制体：Boss + HUD + 运行时导航。
##
## 放置要求：
##   · 场景里需要有一个 "player" 组的玩家节点（Boss 会自动寻找）。
##   · 如果放在 Room 里，使用 Room 已烘焙的导航，不再重复烘焙。
##   · 如果场景里已有 NavigationRegion2D，也直接复用。
##   · 独立拖进普通场景时，围绕本节点自动烘焙一块战斗区域导航。

@export var show_hud := true
## 场景里已有其他 HUD 时，自动隐藏本预制体自带的 HUD，避免叠两层。
@export var hide_if_other_hud := true
@export var auto_nav_bake := true
## 独立烘焙导航时，以本节点为中心的战斗区域半宽/半高。
@export var nav_bounds_half := Vector2(2400.0, 2000.0)
@export var nav_agent_radius := 150.0
@export var nav_cell_size := 64.0

@onready var boss: Node2D = get_node_or_null("Boss") as Node2D
@onready var hud: CanvasLayer = get_node_or_null("HUD") as CanvasLayer
@onready var nav_baker: NavigationRegion2D = get_node_or_null("Nav") as NavigationRegion2D


func _ready() -> void:
	if hud != null:
		hud.visible = show_hud and not (hide_if_other_hud and _has_other_hud())
	if nav_baker == null:
		return
	if not auto_nav_bake or _has_room_ancestor() or _has_existing_nav():
		nav_baker.queue_free()
		nav_baker = null
		return
	var root := get_parent() if get_parent() != null else self
	var half := nav_bounds_half
	nav_baker.call(
		"setup",
		root,
		Rect2(global_position - half, half * 2.0),
		nav_agent_radius,
		nav_cell_size,
		256.0
	)


func _has_other_hud() -> bool:
	for h in get_tree().get_nodes_in_group("hud"):
		if h != hud and is_instance_valid(h):
			return true
	return false


func _has_room_ancestor() -> bool:
	var n: Node = self
	while n != null:
		if n is Room:
			return true
		n = n.get_parent()
	return false


func _has_existing_nav() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return _scan_nav(scene)


func _scan_nav(node: Node) -> bool:
	if node is NavigationRegion2D and node != nav_baker:
		return true
	for child in node.get_children():
		if _scan_nav(child):
			return true
	return false
