shader_type canvas_item;
render_mode blend_mix;

// 本体暗金反光
uniform vec3  gold_tint   : source_color         = vec3(1.0, 0.78, 0.30);
uniform float gold_amount : hint_range(0.0, 1.0) = 0.4;
uniform float scan_speed  : hint_range(0.0, 2.0) = 0.25;

// 沿轮廓的描边辉光
uniform vec3  glow_color   : source_color           = vec3(1.0, 0.92, 0.62);
uniform float glow_radius  : hint_range(0.5, 8.0)   = 3.0;
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.8;
uniform float glow_falloff : hint_range(0.5, 4.0)   = 2.0;
uniform float glow_pulse_speed : hint_range(0.0, 2.0) = 0.18;
uniform float glow_pulse_amp   : hint_range(0.0, 0.2) = 0.06;

// 附魔：中心向外扩散，只播一遍
uniform float enchant_speed  : hint_range(0.05, 2.0)  = 0.35;  // 播完所需时间 = 1/speed 秒
uniform float enchant_offset : hint_range(0.0, 1.0)   = 0.0;   // 起始相位（错开多个实例）
uniform float enchant_width  : hint_range(0.01, 0.3)  = 0.06;  // 前沿过渡宽度
uniform float enchant_radius : hint_range(0.2, 1.0)   = 0.7071; // 扩散半径归一化
uniform vec3  enchant_front_color     : source_color   = vec3(1.0, 1.0, 1.0);
uniform float enchant_front_intensity : hint_range(0.0, 3.0) = 2.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float a0 = tex.a;

    // ---- 一次性附魔进度：0 → 1 后定格 ----
    float progress = clamp(TIME * enchant_speed + enchant_offset, 0.0, 1.0);
    // 过冲一点，保证最后整张图 mask 完全为 1（角落也彻底附魔）
    float sweep = progress * (1.0 + enchant_width * 2.0);

    // 中心扩散：coord=0 在中心，coord=1 在最外圈
    vec2  c     = UV - vec2(0.5);
    float coord = clamp(length(c) / enchant_radius, 0.0, 1.0);

    // 已附魔区域
    float enchant_mask = smoothstep(sweep + enchant_width, sweep - enchant_width, coord);

    // 前沿亮环（只在附魔进行中出现；progress=1 时前沿早已离开，自然消失）
    float d = (coord - sweep) / enchant_width;
    float front = exp(-d * d) * step(progress, 0.999); // 进度封顶后强制归零

    // ---- 本体暗金（只在附魔区域内出现）----
    float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    vec3 gold = gold_tint * lum * 1.2;
    vec3 body_color = mix(tex.rgb, gold, gold_amount * enchant_mask);

    float scan = smoothstep(0.96, 1.0, sin(UV.x * 6.2831853 + TIME * scan_speed));
    body_color += gold_tint * scan * 0.35 * enchant_mask;

    // ---- 沿轮廓的描边辉光 ----
    vec2 texel = TEXTURE_PIXEL_SIZE;
    float edge_field = 0.0;
    float norm = 0.0;
    const int RINGS = 6;

    for (int i = 1; i <= RINGS; i++) {
        float t = float(i) / float(RINGS);
        float r = t * glow_radius;
        float w = pow(1.0 - t, glow_falloff);
        float rd = r * 0.70710678;

        edge_field += texture(TEXTURE, UV + vec2( r,  0.0) * texel).a * w;
        edge_field += texture(TEXTURE, UV + vec2(-r,  0.0) * texel).a * w;
        edge_field += texture(TEXTURE, UV + vec2( 0.0,  r) * texel).a * w;
        edge_field += texture(TEXTURE, UV + vec2( 0.0, -r) * texel).a * w;
        edge_field += texture(TEXTURE, UV + vec2( rd,  rd) * texel).a * w;
        edge_field += texture(TEXTURE, UV + vec2(-rd,  rd) * texel).a * w;
        edge_field += texture(TEXTURE, UV + vec2( rd, -rd) * texel).a * w;
        edge_field += texture(TEXTURE, UV + vec2(-rd, -rd) * texel).a * w;
        norm += 8.0 * w;
    }
    edge_field /= max(norm, 0.0001);

    float raw_glow = clamp(edge_field - a0, 0.0, 1.0);
    raw_glow = pow(raw_glow, 1.5);

    float glow_mask = raw_glow * enchant_mask;

    // 完成后的呼吸保持：progress=1 时仍继续脉动
    float bright = 1.0 + sin(TIME * glow_pulse_speed) * glow_pulse_amp;
    vec3 glow = glow_color * glow_intensity * bright * glow_mask;

    // ---- 前沿亮环，只在本体或轮廓辉光附近显现 ----
    float front_visible = clamp(a0 + raw_glow, 0.0, 1.0);
    vec3 front_glow = enchant_front_color * front * enchant_front_intensity * front_visible;

    COLOR = vec4(
        body_color + glow + front_glow,
        max(a0, glow_mask * 0.6) + front * front_visible * 0.5
    );
}