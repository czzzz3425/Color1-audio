shader_type canvas_item;
render_mode blend_mix;

// ---- 冰雪色温渐变 ----
uniform vec3 ice_core : source_color = vec3(0.9, 0.98, 1.0);  // 核心：极寒亮白（高光）
uniform vec3 ice_mid  : source_color = vec3(0.2, 0.6, 0.9);   // 中段：晶体冰蓝
uniform vec3 ice_edge : source_color = vec3(0.02, 0.1, 0.25); // 边缘：深邃冷暗蓝（冰的阴影/厚度）

uniform float tint_amount : hint_range(0.0, 1.0) = 0.75; // 冰封覆盖力度
uniform vec3  glow_color  : source_color = vec3(0.2, 0.7, 1.0);
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.8;

// ---- 附魔扩散 ----
// 进度由脚本 tween `enchant_progress`（0→1）驱动——TIME 是全局的，多次赋予之间无法重播。
uniform float enchant_progress : hint_range(0.0, 1.0) = 0.0;
uniform float enchant_speed  : hint_range(0.05, 2.0)  = 0.35;   // 保留：脚本按 1/speed 秒换算播完时长
uniform float enchant_offset : hint_range(0.0, 1.0)   = 0.0;    // 兼容保留（不再参与进度）
uniform float enchant_width  : hint_range(0.01, 0.3)  = 0.06;
uniform float enchant_radius : hint_range(0.2, 1.0)   = 0.7071;
uniform float front_intensity : hint_range(0.0, 5.0)  = 3.0;

// ---- 冰晶几何参数 ----
uniform float ice_scale      : hint_range(1.0, 20.0) = 6.0;  // 冰块碎块的大小（越小块越大）
uniform float crack_width    : hint_range(0.01, 0.2) = 0.05; // 裂纹的粗细
uniform float frost_amount   : hint_range(0.0, 1.0)  = 0.6;  // 表面霜尘的斑驳感
uniform float ice_distortion : hint_range(0.0, 0.5)  = 0.15; // 边缘冰棱的锯齿度

// --- 哈希与噪声工具 ---
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// --- Voronoi (泰森多边形) 算法：用于生成真实的碎冰裂纹 ---
// 返回 F1 (到最近边界的距离) 和 F2 (到次近边界的距离)
vec2 voronoi(vec2 x) {
    vec2 n = floor(x);
    vec2 f = fract(x);
    float f1 = 8.0;
    float f2 = 8.0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 g = vec2(float(i), float(j));
            vec2 o = vec2(hash(n + g), hash(n + g + vec2(13.0, 7.0))); // 随机偏移
            vec2 r = g + o - f;
            float d = dot(r, r); // 距离平方
            if (d < f1) {
                f2 = f1;
                f1 = d;
            } else if (d < f2) {
                f2 = d;
            }
        }
    }
    return vec2(sqrt(f1), sqrt(f2));
}

// 基础平滑噪声（用于边缘轮廓扭曲和冰面斑驳）
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float a0 = tex.a;

    // 扩散进度（由 enchant_progress 显式驱动）
    float progress = clamp(enchant_progress, 0.0, 1.0);
    float sweep = progress * (1.0 + enchant_width * 2.0);

    vec2  c     = UV - vec2(0.5);
    float coord = clamp(length(c) / enchant_radius, 0.0, 1.0);

    // ---- 冰锋边缘扭曲 (静止的霜冻边缘) ----
    float edge_noise = noise(UV * ice_scale * 0.5); // 不随 TIME 变化
    float crystal_edge = smoothstep(0.2, 0.8, edge_noise);
    float distorted_coord = coord - (crystal_edge - 0.5) * ice_distortion;

    // 冰封遮罩
    float enchant_mask = smoothstep(sweep + enchant_width, sweep - enchant_width, distorted_coord);
    
    // 冰锋前沿
    float d = (distorted_coord - sweep) / enchant_width;
    float front = exp(-d * d) * step(progress, 0.999);

    // ---- 生成真实冰裂纹 (Voronoi) ----
    vec2 v_coords = UV * ice_scale;
    vec2 vor = voronoi(v_coords);
    
    // 提取裂纹：距离边界 F2-F1 越近，越是裂纹
    float crack_dist = vor.y - vor.x;
    // 锐化裂纹，形成锋利的多边形边缘
    float cracks = 1.0 - smoothstep(0.0, crack_width, crack_dist);
    
    // 用噪声稍微打破死板的 Voronoi 网格，让它更自然
    float surface_noise = noise(UV * ice_scale * 4.0);
    cracks *= smoothstep(0.1, 0.6, surface_noise + 0.4);

    // ---- 本体颜色与冰的层次感 ----
    float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    
    // 暗角/厚度：越靠近边缘和裂纹，越暗沉
    float depth_shadow = smoothstep(0.0, 0.3, crack_dist); 
    float center_heat = clamp(1.0 - (distorted_coord / max(sweep, 0.1)), 0.0, 1.0);
    
    // 混合三层颜色
    vec3 ice_color = mix(ice_edge, ice_mid, center_heat);
    // 用裂纹压暗内部，产生立体厚度
    ice_color *= mix(0.4, 1.0, depth_shadow);
    
    // 原图融合
    vec3 tinted = ice_color * (0.5 + lum); 
    vec3 body_color = mix(tex.rgb, tinted, tint_amount * enchant_mask);

    // ---- 添加霜花与高光 ----
    // 1. 裂纹中心高光（白霜沿着裂隙蔓延）
    vec3 frost_glow = ice_core * cracks * frost_amount;
    
    // 2. 随机的高频霜斑
    float frost_speckle = step(0.7, surface_noise) * frost_amount * 0.4;
    
    // 3. 静止的斜向反光（模拟玻璃/冰面的环境光折射）
    float sheen = smoothstep(0.4, 0.0, abs(UV.x + UV.y - 0.8)) * 0.3;

    body_color += (frost_glow + ice_core * frost_speckle + ice_mid * sheen) * enchant_mask;

    // ---- 轮廓辉光 ----
    vec2 texel = TEXTURE_PIXEL_SIZE;
    float edge_field = 0.0;
    float norm = 0.0;
    const int RINGS = 4;

    for (int i = 1; i <= RINGS; i++) {
        float t = float(i) / float(RINGS);
        float r = t * 4.0; 
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
    raw_glow = pow(raw_glow, 1.5);
    float glow_mask = raw_glow * enchant_mask;

    vec3 glow = glow_color * glow_intensity * glow_mask;

    // ---- 最终叠加 ----
    float front_visible = clamp(a0 + raw_glow, 0.0, 1.0);
    vec3 front_glow = ice_core * front * front_intensity * front_visible;

    COLOR = vec4(
        body_color + glow + front_glow,
        max(a0, glow_mask * 0.6) + front * front_visible * 0.8
    );
}