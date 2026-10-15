shader_type canvas_item;
render_mode blend_mix;

uniform vec4 gold_color : source_color = vec4(1.0, 0.82, 0.35, 1.0);
uniform float pulse_speed : hint_range(0.1, 1.0) = 0.25;
uniform float pulse_amp : hint_range(0.0, 0.3) = 0.08;
uniform float glow_intensity : hint_range(1.0, 3.0) = 1.4;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    if (tex.a < 0.5) {
        discard;
    }

    // 用边缘检测做硬边金色轮廓
    float left   = texture(TEXTURE, UV + vec2(-1.0 / SCREEN_PIXEL_SIZE.x, 0.0)).a;
    float right  = texture(TEXTURE, UV + vec2( 1.0 / SCREEN_PIXEL_SIZE.x, 0.0)).a;
    float up     = texture(TEXTURE, UV + vec2(0.0, -1.0 / SCREEN_PIXEL_SIZE.y)).a;
    float down   = texture(TEXTURE, UV + vec2(0.0,  1.0 / SCREEN_PIXEL_SIZE.y)).a;

    float edge = 1.0 - min(min(left, right), min(up, down));
    edge = smoothstep(0.3, 0.8, edge);

    // 内部很暗，只保留原始亮度
    float inner_dark = 0.35;

    float brightness = 1.0 + sin(TIME * pulse_speed) * pulse_amp;

    vec3 final_color = mix(
        tex.rgb * inner_dark,
        gold_color.rgb * glow_intensity * brightness,
        edge
    );

    COLOR = vec4(final_color, tex.a);
}