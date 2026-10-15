shader_type canvas_item;

// 光线数量：越多越密
uniform float ray_count : hint_range(2.0, 64.0) = 12.0;

// 光线粗细：越小越细
uniform float ray_width : hint_range(0.01, 1.0) = 0.35;

// 中心留空半径：小于这个距离完全不画光线
uniform float inner_radius : hint_range(0.0, 0.5) = 0.15;

// 内渐隐宽度：光线从 inner_radius 到 inner_radius + inner_fade_width 逐渐出现
uniform float inner_fade_width : hint_range(0.0, 0.3) = 0.05;

// 光线最大半径：超过这个距离完全不画
uniform float outer_radius : hint_range(0.1, 1.0) = 0.5;

// 外渐隐宽度：光线从 outer_radius - outer_fade_width 到 outer_radius 逐渐消失
uniform float outer_fade_width : hint_range(0.0, 0.5) = 0.15;

// 光线颜色
uniform vec4 ray_color : source_color = vec4(1.0, 0.9, 0.5, 1.0);

// 整体亮度
uniform float intensity : hint_range(0.0, 2.0) = 1.0;

// 旋转速度：0 表示静止
uniform float rotate_speed : hint_range(-2.0, 2.0) = 0.0;

// 闪烁速度：0 表示不闪烁
uniform float flicker_speed : hint_range(0.0, 10.0) = 0.0;

void fragment() {
    vec4 item_tint = COLOR;
    // 把 UV 平移到以中心为原点，范围 -0.5 ~ 0.5
    vec2 uv = UV - vec2(0.5);

    // 距离和角度
    float dist = length(uv);
    float angle = atan(uv.y, uv.x);

    // 旋转
    angle += TIME * rotate_speed;

    // 生成放射条纹
    float rays = sin(angle * ray_count);
    rays = smoothstep(1.0 - ray_width, 1.0, rays);

    // 内渐隐：中心留空，从 inner_radius 开始逐渐出现
    float inner_fade = smoothstep(inner_radius, inner_radius + inner_fade_width, dist);

    // 外渐隐：从 outer_radius - outer_fade_width 开始逐渐消失
    float outer_fade = 1.0 - smoothstep(outer_radius - outer_fade_width, outer_radius, dist);

    // 合并两端渐隐
    float fade = inner_fade * outer_fade;

    // 闪烁（可选）
    float flicker = 1.0;
    if (flicker_speed > 0.0) {
        flicker = 0.5 + 0.5 * sin(TIME * flicker_speed);
    }

    // 最终透明度
    float alpha = rays * fade * intensity * flicker;

    // 输出颜色
    COLOR = vec4(ray_color.rgb, ray_color.a * alpha) * item_tint;
}
