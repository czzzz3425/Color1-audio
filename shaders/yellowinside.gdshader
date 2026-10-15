shader_type canvas_item;
render_mode blend_mix;

// 本体暗金反光
uniform vec3 gold_tint : source_color = vec3(1.0, 0.78, 0.30);
uniform float gold_amount : hint_range(0.0, 1.0) = 0.4;
uniform float scan_speed : hint_range(0.0, 2.0) = 0.25;

// 外部柔和辉光
uniform vec3 glow_color : source_color = vec3(1.0, 0.92, 0.62);
uniform float glow_radius : hint_range(0.5, 5.0) = 2.5;
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.8;
uniform float glow_pulse_speed : hint_range(0.0, 2.0) = 0.18;
uniform float glow_pulse_amp : hint_range(0.0, 0.2) = 0.06;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // 本体暗金
    float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    vec3 gold = gold_tint * lum * 1.2;
    vec3 body_color = mix(tex.rgb, gold, gold_amount);

    float scan = smoothstep(0.96, 1.0, sin(UV.x * 6.28 + TIME * scan_speed));
    body_color += gold_tint * scan * 0.35;

    // 柔和外部辉光
    vec2 ps = SCREEN_PIXEL_SIZE;
    float r = glow_radius;
    float a0 = tex.a;

    float glow_accum = 0.0;
    float sample_count = 0.0;

    for (float i = 1.0; i <= 4.0; i += 1.0) {
        float offset = r * i * 0.75;
        glow_accum += texture(TEXTURE, UV + vec2( offset,  0.0) * ps).a;
        glow_accum += texture(TEXTURE, UV + vec2(-offset,  0.0) * ps).a;
        glow_accum += texture(TEXTURE, UV + vec2( 0.0,  offset) * ps).a;
        glow_accum += texture(TEXTURE, UV + vec2( 0.0, -offset) * ps).a;
        glow_accum += texture(TEXTURE, UV + vec2( offset,  offset) * ps).a;
        glow_accum += texture(TEXTURE, UV + vec2(-offset, -offset) * ps).a;
        glow_accum += texture(TEXTURE, UV + vec2( offset, -offset) * ps).a;
        glow_accum += texture(TEXTURE, UV + vec2(-offset,  offset) * ps).a;
        sample_count += 8.0;
    }

    float avg_a = glow_accum / max(sample_count, 1.0);
    float glow_mask = max(0.0, avg_a - a0);
    glow_mask = smoothstep(0.02, 0.25, glow_mask);

    float bright = 1.0 + sin(TIME * glow_pulse_speed) * glow_pulse_amp;
    vec3 glow = glow_color * glow_intensity * bright * glow_mask;

    vec3 final_rgb = body_color + glow;
    float final_a = max(a0, glow_mask * 0.45);

    COLOR = vec4(final_rgb, final_a);
}