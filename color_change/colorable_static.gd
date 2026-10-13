class_name ColorableStatic
extends ColorableBase
## 可上色静态体（带 "Visual" Sprite2D 贴图，如树/木条）：colorable_sprite 的「带碰撞」版本。
## 被赋予红则燃烧蔓延、烧尽后 Visual 碎裂并整体销毁（含碰撞）；赋予蓝则冻结。
## 上色/状态视觉反馈交给 ElementBehavior 的 VFX（火焰/冰霜）+ 烧尽碎裂，本脚本不接管贴图材质。
## 例外：勾选 burn_down 的物体（枯木等燃料），给红后由本脚本驱动 Visual 材质溶解烧毁。

@onready var visual: Sprite2D = $Visual

## 烧毁模式：给红后 Visual 溶解烧尽并整体销毁（枯木等燃料）。默认关，普通树/木条不受影响。
@export var burn_down := false
## 烧毁溶解时长（秒，默认 2）。
@export var burn_duration := 2.0

var _burn_tween: Tween
var _burning_away := false


func _ready() -> void:
	super._ready()
	# 开局预置红色（initial_color_name = "红"）时同样烧毁。
	if burn_down and _behavior.current_element() == "burn":
		_start_burn_down()


## 注入视觉中心与碎裂目标：Visual 贴图中心在根原点上方（position 即偏移），碎裂就碎这张贴图。
func _configure_behavior(behavior: ElementBehavior) -> void:
	behavior.visual_center = visual.position
	behavior.shatter_target = visual
	# 溶解烧毁燃料用溶解 shader 表现燃烧，不叠加火焰粒子 VFX。
	behavior.play_burn_vfx = not burn_down


func contains_point(world_pos: Vector2) -> bool:
	return visual.get_rect().has_point(visual.to_local(world_pos))


## 给红（burn）时启动烧毁溶解；其它元素不接管材质。
func _apply_visual(_c: Color, _origin: Vector2) -> void:
	if burn_down and _behavior != null and _behavior.current_element() == "burn":
		_start_burn_down()


## 吸收颜色（熄灭）时打断烧毁，恢复完整树体。
func _reset_visual() -> void:
	_cancel_burn_down()


func _start_burn_down() -> void:
	if _burning_away or not (visual.material is ShaderMaterial):
		return
	_burning_away = true
	# 树正在烧没，先移除碰撞，让玩家可通行。
	if has_node("CollisionShape2D"):
		($CollisionShape2D as CollisionShape2D).set_deferred("disabled", true)
	# 复制材质，避免共享 ShaderMaterial 互相影响。
	visual.material = (visual.material as ShaderMaterial).duplicate() as ShaderMaterial
	# 溶解 0 → 1，烧尽后整体销毁（含行为组件/光/火）。
	_burn_tween = create_tween()
	_burn_tween.tween_property(visual.material, "shader_parameter/dissolve", 1.0, burn_duration)
	_burn_tween.tween_callback(queue_free)


func _cancel_burn_down() -> void:
	if not _burning_away:
		return
	_burning_away = false
	if _burn_tween and _burn_tween.is_valid():
		_burn_tween.kill()
	_burn_tween = null
	if visual.material is ShaderMaterial:
		(visual.material as ShaderMaterial).set_shader_parameter("dissolve", 0.0)
	if has_node("CollisionShape2D"):
		($CollisionShape2D as CollisionShape2D).set_deferred("disabled", false)
