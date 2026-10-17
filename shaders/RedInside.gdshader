shader_type canvas_item;
render_mode blend_mix;

// ---- 火焰色温渐变 (核心修改：三层色温) ----
uniform vec3 fire_core : source_color = vec3(1.0, 0.98, 0.75); // 核心：亮白黄
uniform vec3 fire_mid  : source_color = vec3(1.0, 0.45, 0.05); // 中段：亮橘色
uniform vec3 fire_edge : source_color = vec3(0.5, 0.05, 0.0);  // 边缘：暗红色

uniform float tint_amount : hint_range(0.0, 1.0) = 0.5;
uniform vec3  glow_color  : source_color = vec3(1.0, 0.4, 0.1);
uniform float glow_intensity : hint_range(0.0, 2.0) = 1.2;

// ---- 附魔扩散 ----
// 进度由脚本 tween `enchant_progress`（0→1）驱动——TIME 是全局的，多次赋予之间无法重播。
uniform float enchant_progress : hint_range(0.0, 1.0) = 0.0;
uniform float enchant_speed  : hint_range(0.05, 2.0)  = 0.35;   // 保留：脚本按 1/speed 秒换算播完时长
uniform float enchant_offset : hint_range(0.0, 1.0)   = 0.0;    // 兼容保留（不再参与进度）
uniform float enchant_width  : hint_range(0.01, 0.3)  = 0.12;
uniform float enchant_radius : hint_range(0.2, 1.0)   = 0.7071;
uniform float front_intensity : hint_range(0.0, 5.0)  = 3.0; // 火线亮度

// ---- 火焰动态与形状 ----
uniform float fire_distortion : hint_range(0.0, 1.0) = 0.35; // 火焰扭曲度
uniform float fire_speed      : hint_range(0.0, 5.0) = 2.0;  // 燃烧速度
uniform float fire_scale      : hint_range(1.0, 20.0) = 8.0; // 火焰大小
uniform float ember_amount    : hint_range(0.0, 1.0) = 0.5;  // 表面余烬斑驳程度

// --- 噪声与噪声扭曲 (Domain Warping) ---
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

// 扭曲噪声：让火焰有流动的形状
float distorted_fbm(vec2 p) {
    vec2 q = vec2(fbm(p), fbm(p + vec2(5.2, 1.3)));
    return fbm(p + 4.0 * q);
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float a0 = tex.a;

    float progress = clamp(enchant_progress, 0.0, 1.0);
    float sweep = progress * (1.0 + enchant_width * 2.0);

    // 中心扩散距离
    vec2  c     = UV - vec2(0.5);
    float coord = clamp(length(c) / enchant_radius, 0.0, 1.0);

    // ---- 火焰形状计算 ----
    // 把UV纵向拉长(Y轴乘以0.5)，模拟火苗向上延伸的形状
    vec2 noise_uv = UV * fire_scale * vec2(1.0, 0.5);
    noise_uv.y -= TIME * fire_speed; // 向上流动
    
    // 采样带有扭曲的噪声，让火舌参差不齐
    float n = distorted_fbm(noise_uv);
    
    // 将圆环边界加上噪声扭曲
    float distorted_coord = coord - (n - 0.5) * fire_distortion;

    // 燃烧遮罩：扫过的地方开始燃烧
    float enchant_mask = smoothstep(sweep + enchant_width, sweep - enchant_width, distorted_coord);
    
    // 火线前沿（最亮的部分）
    float d = (distorted_coord - sweep) / enchant_width;
    float front = exp(-d * d) * step(progress, 0.999);

    // ---- 本体颜色计算 (根据热力值产生渐变) ----
    float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    
    // 计算热力值：越靠近中心越热(1.0)，越靠近边缘越冷(0.0)
    // 加上噪声让色温分布不均匀，产生火焰斑驳感
    float heat = clamp(1.0 - (distorted_coord / max(sweep, 0.1)) + (n - 0.5) * 0.3, 0.0, 1.0);
    
    // 三层颜色混合
    vec3 fire_color = mix(fire_edge, fire_mid, smoothstep(0.0, 0.5, heat));
    fire_color = mix(fire_color, fire_core, smoothstep(0.5, 1.0, heat));
    
    // 用热力值染色本体
    vec3 tinted = fire_color * (0.5 + lum); 
    vec3 body_color = mix(tex.rgb, tinted, tint_amount * enchant_mask);

    // ---- 表面余烬游走效果 (让内部有忽明忽暗的斑块) ----
    float ember = smoothstep(0.4, 0.6, n) * enchant_mask * ember_amount;
    body_color += fire_mid * ember * 0.8;

    // ---- 轮廓辉光 ----
    vec2 texel = TEXTURE_PIXEL_SIZE;
    float edge_field = 0.0;
    float norm = 0.0;
    const int RINGS = 4; // 降低圈数节省性能，因为颜色已经很复杂了

    for (int i = 1; i <= RINGS; i++) {
        float t = float(i) / float(RINGS);
        float r = t * 4.0; // 固定基础半径
        float w = pow(1.0 - t, 2.0);
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
    raw_glow = pow(raw_glow, 1.2);
    float glow_mask = raw_glow * enchant_mask;

    // 辉光也使用高温色
    vec3 glow = glow_color * glow_intensity * glow_mask;

    // ---- 最终叠加 ----
    float front_visible = clamp(a0 + raw_glow, 0.0, 1.0);
    vec3 front_glow = fire_core * front * front_intensity * front_visible;

    COLOR = vec4(
        body_color + glow + front_glow,
        max(a0, glow_mask * 0.6) + front * front_visible * 0.8
    );
}