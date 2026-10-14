@tool
class_name CharacterPortrait
extends Resource
## 角色立绘配置：角色名必须与 .dialogue 文件冒号前的名字一致。

@export var character_name: String = ""
@export var portrait: Texture2D
## 角色从屏幕哪一侧滑入；两侧可以同时保留一个角色。
@export_enum("左侧", "右侧") var side: int = 0
## 相对于立绘区域的尺寸倍率，图片始终保持比例。
@export_range(0.3, 3.0, 0.05, "or_greater") var size_multiplier: float = 1.0
@export var flip_h: bool = false
## 相对默认站位的 UI 像素偏移：X 正数向右，Y 正数向下。
## 滑入终点、说话切换和窗口大小变化都会保留此偏移。
@export var position_offset := Vector2.ZERO
