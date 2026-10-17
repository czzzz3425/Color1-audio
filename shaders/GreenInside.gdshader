shader_type canvas_item;
render_mode blend_mix;

// 本体生命绿反光（暖绿：偏黄、不刺眼）
uniform vec3  tint        : source_color         = vec3(0.62, 0.95, 0.38);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.4;

// 沿轮廓的描边辉光（暖绿光晕）
uniform vec3  glow_color   : source_color           = vec3(0.78, 1.0, 0.55);
uniform float glow_radius  : hint_range(0.5, 8.0)   = 3.0;
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.8;
uniform float glow_falloff : hint_range(0.5, 4.0)   = 2.0;
uniform float glow_pulse_speed : hint_range(0.0, 2.0) = 0.18;
uniform float glow_pulse_amp   : hint_range(0.0, 0.2) = 0.06;

// 附魔：中心向外扩散，只播一遍。
// 进度由脚本 tween `enchant_progress`（0→1）驱动——TIME 是全局的，多次赋予之间无法重播。
uniform float enchant_progress : hint_range(0.0, 1.0) = 0.0;
uniform float enchant_speed  : hint_range(0.05, 2.0)  = 0.35;   // 保留：脚本按 1/speed 秒换算播完时长
uniform float enchant_offset : hint_range(0.0, 1.0)   = 0.0;    // 兼容保留（不再参与进度）
uniform float enchant_width  : hint_range(0.01, 0.3)  = 0.06;
uniform float enchant_radius : hint_range(0.2, 1.0)   = 0.7071;
uniform vec3  enchant_front_color     : source_color   = vec3(0.92, 1.0, 0.78);
uniform float enchant_front_intensity : hint_range(0.0, 3.0) = 2.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float a0 = tex.a;

    // ---- 一次性附魔进度：0 → 1 后定格（由 enchant_progress 显式驱动）----
    float progress = clamp(enchant_progress, 0.0, 1.0);
    float sweep = progress * (1.0 + enchant_width * 2.0);

    // 中心扩散：coord=0 在中心，coord=1 在最外圈
    vec2  c     = UV - vec2(0.5);
    float coord = clamp(length(c) / enchant_radius, 0.0, 1.0);

    // 已附魔区域
    float enchant_mask = smoothstep(sweep + enchant_width, sweep - enchant_width, coord);

    // 前沿亮环（progress 到 1 时自动消失）
    float d = (coord - sweep) / enchant_width;
    float front = exp(-d * d) * step(progress, 0.999);

    // ---- 本体生命绿（只在附魔区域内出现）----
    float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    vec3 tinted = tint * lum * 1.2;
    vec3 body_color = mix(tex.rgb, tinted, tint_amount * enchant_mask);

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

    // 完成后的呼吸脉动持续存在
    float bright = 1.0 + sin(TIME * glow_pulse_speed) * glow_pulse_amp;
    vec3 glow = glow_color * glow_intensity * bright * glow_mask;

    // ---- 前沿亮环，只在本体或轮廓附近显现 ----
    float front_visible = clamp(a0 + raw_glow, 0.0, 1.0);
    vec3 front_glow = enchant_front_color * front * enchant_front_intensity * front_visible;

    COLOR = vec4(
        body_color + glow + front_glow,
        max(a0, glow_mask * 0.6) + front * front_visible * 0.5
    );
}