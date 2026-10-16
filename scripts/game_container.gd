extends Node2D
## 常驻根节点（GameContainer）：持有玩家与房间容器。
## 启动时初始化 SceneManager 并进入起始房间。玩家常驻，不放在房间内。

@export var start_room: String = "res://scenes/level_1.tscn"
@export var start_entrance: String = "spawn"
@export var show_main_menu := true

@export_group("主菜单美术")
## 完整标题图（含「失色 / 招领处」），推荐透明 PNG；留空时显示文字占位。
@export var menu_title_texture: Texture2D
## 标题图片在菜单中的显示区域，等比缩放，不拉伸。
@export var menu_title_size := Vector2(280, 160)
## 菜单统一字体；可替换为其他已获授权的中文手写字体。
@export var menu_font: Font = preload("res://art/fonts/LXGWWenKaiLite-Regular.ttf")

@onready var player: Node2D = $Player
@onready var room_container: Node2D = $RoomContainer
@onready var pcam: PhantomCamera2D = $MainPCam as PhantomCamera2D


func _ready() -> void:
	if show_main_menu:
		var menu := preload("res://scripts/main_menu.gd").new()
		add_child(menu)
		menu.prepare(self)
	SceneManager.setup(player, room_container)
	if pcam != null:
		pcam.follow_target = player
	SceneManager.change_room(start_room, start_entrance)
