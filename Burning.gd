extends Sprite2D

@export var burn_duration: float = 2.0   # 燃烧持续时间
@export var auto_burn: bool = false      # 是否自动开始燃烧

func _ready() -> void:
	# 如果多个精灵共用同一个材质，复制一份，避免互相影响
	if material is ShaderMaterial:
		material = material.duplicate() as ShaderMaterial

	# 确保初始状态是完好的
	set_dissolve(0.0)

	if auto_burn:
		await get_tree().create_timer(1.0).timeout
		burn_away()

func set_dissolve(value: float) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("dissolve", value)

func burn_away(duration: float = -1.0) -> void:
	if duration < 0.0:
		duration = burn_duration

	var mat := material as ShaderMaterial
	if not mat:
		push_error("Sprite2D 上没有 ShaderMaterial！")
		return

	# 可选：在这里开启粒子
	# $GPUParticles2D.emitting = true

	var tween := create_tween()
	# 关键：Tween 驱动 ShaderMaterial 的 shader_parameter/dissolve
	tween.tween_property(mat, "shader_parameter/dissolve", 1.0, duration)

	# 燃烧结束后删除节点（按需使用）
	tween.tween_callback(queue_free)

func _unhandled_input(event: InputEvent) -> void:
	# 按空格键测试燃烧
	if event.is_action_pressed("ui_accept"):
		burn_away()
