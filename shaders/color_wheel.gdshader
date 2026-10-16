shader_type canvas_item;

// 色轮方向盘：只露出「选中颜色」所在的一扇，其余部分压暗；切换颜色时整轮旋转到对应扇区。
// 采样源 TEXTURE 是 1100×1100 的色相环（art/ui/色轮.jpg）：红在顶部、蓝在右侧、绿在右下，
// 中心有灰色轮毂、四角是白底，这里用环形遮罩把它们裁掉。

uniform float wheel_rotation : hint_range(-6.28319, 6.28319) = 0.0; // 色轮旋转（弧度，正=顺时针）
uniform float reveal_center : hint_range(-3.14159, 3.14159) = -1.5708; // 显示窗口中心方向（默认顶部）
uniform float wedge_half : hint_range(0.0, 3.14159) = 0.8;    // 显示扇区半角（弧度）
uniform float edge_soft : hint_range(0.0, 0.5) = 0.12;        // 边缘柔和过渡
uniform float dim_alpha : hint_range(0.0, 1.0) = 0.15;        // 非选中区域压暗后的透明度
uniform float inner_radius : hint_range(0.0, 1.0) = 0.36;     // 中心轮毂半径（归一化，遮掉灰毂）
uniform float outer_radius : hint_range(0.0, 1.2) = 0.95;     // 外圈半径（归一化，遮掉四角白底）

void fragment() {
	vec2 p = UV - vec2(0.5);
	float ang = atan(p.y, p.x);
	float r = length(p) * 2.0;

	// 环形遮罩：只留色环，遮掉中心轮毂与四角白底。
	float ring = (1.0 - smoothstep(outer_radius - edge_soft, outer_radius, r))
	           * smoothstep(inner_radius - edge_soft, inner_radius, r);

	// 扇区遮罩：只露出 reveal_center 附近的一扇。
	float d = mod(ang - reveal_center + 3.14159265, 6.28318531) - 3.14159265;
	float wedge = 1.0 - smoothstep(wedge_half - edge_soft, wedge_half + edge_soft, abs(d));

	// 旋转采样：屏幕角度 ang 处取「色轮上 ang - wheel_rotation」处的颜色。
	float tex_ang = ang - wheel_rotation;
	vec2 tex_uv = vec2(0.5) + 0.5 * r * vec2(cos(tex_ang), sin(tex_ang));
	vec4 col = texture(TEXTURE, tex_uv);

	float alpha = ring * mix(dim_alpha, 1.0, wedge);
	COLOR = vec4(col.rgb, alpha);
}
