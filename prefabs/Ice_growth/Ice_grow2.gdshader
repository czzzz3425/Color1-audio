// grow.gdshader  ——  结冰版（噪点收尾修复）
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2  grow_dir = vec2(1.0, 0.0);

uniform vec4  ice_color   : source_color = vec4(0.72, 0.88, 1.0, 1.0);
uniform vec4  frost_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float edge_soft     : hint_range(0.001, 0.3) = 0.03;
uniform float glow_strength : hint_range(0.0, 1.0)   = 1.0;

uniform sampler2D noise_texture : hint_default_white, filter_linear, repeat_enable;
uniform float noise_scale    : hint_range(0.5, 20.0) = 5.0;
uniform float noise_strength : hint_range(0.0, 0.5)  = 0.15;

uniform float frost_width     : hint_range(0.0, 0.3) = 0.06;
uniform float ice_tint_amount : hint_range(0.0, 1.0) = 0.5;

// 生长到这个进度开始收尾
uniform float settle_start : hint_range(0.5, 1.0) = 0.85;

float sample_noise(vec2 uv) {
    return texture(noise_texture, uv).r;
}

float fbm(vec2 uv) {
    float v  = sample_noise(uv) * 0.65;
    v += sample_noise(uv * 2.3 + vec2(17.0, 9.0)) * 0.35;
    return v;
}

void fragment() {
    vec4 base = COLOR * texture(TEXTURE, UV);

    vec2 dir = normalize(grow_dir);

    float axis = UV.x * abs(dir.x) + UV.y * abs(dir.y);
    if (dir.x < 0.0 || dir.y < 0.0) {
        axis = 1.0 - axis;
    }

    // 收尾：progress 接近 1 时，噪声幅度衰减到 0
    float settle = 1.0 - smoothstep(settle_start, 1.0, progress);
    float eff_noise = noise_strength * settle;

    float n = fbm(UV * noise_scale);
    float distorted_axis = axis + (n - 0.5) * eff_noise;

    // progress 略微外扩，保证收尾时所有像素都被完全覆盖
    float p = mix(progress, 1.0 + edge_soft, smoothstep(settle_start, 1.0, progress));
    float d = p - distorted_axis;

    float visible = smoothstep(-edge_soft, edge_soft, d);

    // 收尾时也把边缘光一起淡掉，避免残留白光
    float eff_glow = glow_strength * settle;

    float glow = (1.0 - smoothstep(0.0, edge_soft * 3.0, abs(d))) * eff_glow;
    float frost = (1.0 - smoothstep(0.0, frost_width, max(d, 0.0)))
                  * step(0.0, d) * eff_glow;

    vec3 col = base.rgb;
    col = mix(col, ice_color.rgb, visible * ice_tint_amount);
    col = mix(col, frost_color.rgb, clamp(glow + frost * 0.5, 0.0, 1.0));

    float a = clamp(base.a * visible + glow * 0.6, 0.0, 1.0);
    COLOR = vec4(col, a);
}