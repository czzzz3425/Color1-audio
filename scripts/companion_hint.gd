class_name CompanionHint
extends Node2D
## 跟班提醒点：玩家（带跟班）走进 radius 内，跟班主动说一句 cue。
## 放法：关卡里加一个 Node2D，挂本脚本，填 cue（指向 companion.dialogue 里的 ~ 标题）。
## 默认一次性触发；要在场景里反复提醒可另接逻辑（当前不需要）。

@export var cue: String = ""
@export var radius: float = 96.0

var _triggered := false


func _ready() -> void:
	add_to_group("companion_hint")


func can_trigger() -> bool:
	return cue != "" and not _triggered


func trigger() -> String:
	_triggered = true
	return cue
