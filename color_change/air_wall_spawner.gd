extends TileMapLayer
## 空气墙：保留 tilemap 显示的墙格，同时为每个格子生成不可见碰撞。
## 只阻挡玩家，不参与水、结冰、可上色，也不写 HeightMap。

const WORLD_LAYER := 2


func _ready() -> void:
	var size := Vector2(256, 256)
	if tile_set != null:
		size = Vector2(tile_set.tile_size)
	for cell in get_used_cells():
		var body := StaticBody2D.new()
		body.name = "AirWall_%d_%d" % [cell.x, cell.y]
		body.position = map_to_local(cell)
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		var col := CollisionShape2D.new()
		col.name = "Collision"
		var shape := RectangleShape2D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
		add_child(body)
	# 不 clear，保留 tilemap 的可见贴图。
