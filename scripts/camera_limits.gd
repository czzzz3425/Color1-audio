class_name CameraLimits
extends RefCounted
## 相机边界统一设置：优先设 PhantomCamera2D（group "main_camera"）的 limit，
## 没有 PhantomCamera2D 时回退到玩家身上的原生 Camera2D。
## 关级（room.gd 的 camera_limits）与房级（room_zone.gd 的房间矩形）共用这一处。


## 把相机可视范围 clamp 到 [left, top, right, bottom]（世界坐标，轴对齐）。
static func apply(left: int, top: int, right: int, bottom: int) -> void:
	var pcam := _tree().get_first_node_in_group("main_camera")
	if pcam != null:
		pcam.set("limit_left", left)
		pcam.set("limit_top", top)
		pcam.set("limit_right", right)
		pcam.set("limit_bottom", bottom)
		return

	# 回退：没有 PhantomCamera2D 时，直接设玩家身上的 Camera2D。
	var player := _tree().get_first_node_in_group("player")
	if player == null:
		return
	var cam := player.get_node_or_null("Camera") as Camera2D
	if cam == null:
		return
	cam.limit_left = left
	cam.limit_top = top
	cam.limit_right = right
	cam.limit_bottom = bottom


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree
