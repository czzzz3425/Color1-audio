shader_type canvas_item;
render_mode blend_add; // 叠加发光，风元素感

uniform float stretch : hint_range(1.0, 10.0) = 5.0;
uniform float brightness : hint_range(0.0, 3.0) = 1.5;
uniform float tail_fade : hint_range(0.0, 1.0) = 0.6; // 尾部更淡

void vertex() {
    // 沿粒子本地 Y 轴拉长，形成流线
    VERTEX.y *= stretch;
}

void fragment() {
    vec2 uv = UV - 0.5;
    float dist = length(uv);

    // 径向柔边
    float alpha = smoothstep(0.5, 0.0, dist);

    // 头部亮、尾部淡，制造“拖尾”感
    float head_to_tail = smoothstep(-0.5, 0.5, uv.y);
    alpha *= mix(1.0, tail_fade, head_to_tail);

    COLOR.a *= alpha;
    COLOR.rgb *= brightness;
    COLOR.g *= 1.05;
    COLOR.b *= 1.1;
}