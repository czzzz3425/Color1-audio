shader_type canvas_item;
render_mode blend_mix;

// 【关键修正】声明屏幕纹理
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float distortion_strength : hint_range(0.0, 0.5) = 0.05; // 扭曲强度
uniform float distortion_speed : hint_range(0.0, 10.0) = 2.0;    // 扭曲流动速度
uniform float portal_radius : hint_range(0.1, 0.5) = 0.48;       // 遮罩半径 (决定传送门大小)

void fragment() {
    // 1. 计算当前像素距离中心的距离
    vec2 center = vec2(0.5);
    float dist = length(UV - center);
    
    // 2. 如果超出了遮罩半径，直接丢弃该像素！(这就不会挡住外面的背景了)
    // 因为你的节点是 Sprite2D，如果你在场景里把节点的 Scale 拉成了椭圆，这里生成的遮罩也会是椭圆
    if (dist > portal_radius) {
        discard;
    }

    // 3. 计算扭曲偏移
    vec2 distortion_offset = vec2(
        sin(UV.y * 15.0 + TIME * distortion_speed),
        cos(UV.x * 15.0 + TIME * distortion_speed)
    ) * distortion_strength;
    
    // 4. 采样并扭曲屏幕画面
    vec2 screen_uv = SCREEN_UV;
    vec4 distorted_screen = texture(screen_texture, screen_uv + distortion_offset);
    
    // 5. 获取你手绘的黑色线条
    vec4 base_color = texture(TEXTURE, UV);
    
    // 6. 组合结果：保留你的黑色线条，其余部分显示扭曲后的背景
    vec3 final_rgb = mix(distorted_screen.rgb, base_color.rgb, base_color.a);
    
    // 7. 边缘平滑 (避免椭圆边缘出现硬邦邦的锯齿)
    float edge_fade = smoothstep(portal_radius, portal_radius - 0.05, dist);
    
    // 8. 输出最终颜色（加入边缘渐变，保证洞口边缘融入背景）
    COLOR = vec4(final_rgb, 1.0 * edge_fade);
}