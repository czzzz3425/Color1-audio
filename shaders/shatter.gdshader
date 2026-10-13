shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 shards = vec2(6.0, 6.0);
uniform float seed_value = 0.0;
uniform float fall_strength = 0.7;
uniform float drift_strength = 0.25;
uniform float rotation_strength = 0.7;
// 每个格子中心的最大随机偏移 (0=规则网格, 1=非常不规则)
uniform float cell_jitter : hint_range(0.0, 1.0) = 0.9;
// 裂纹高光宽度 (UV 单位)
uniform float crack_width : hint_range(0.0, 0.2) = 0.015;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	return vec2(hash21(p), hash21(p + vec2(19.19, 7.77)));
}

// 找最近的抖动 Voronoi 单元
// 返回: 单元 id (整数化坐标)
// 输出: center = 该单元中心 (UV 空间)
//       edge_dist = 到单元边界的近似距离 (UV 空间)
vec2 voronoi_cell(vec2 uv, out vec2 center, out float edge_dist) {
	vec2 g = uv * shards;
	vec2 cell = floor(g);
	vec2 best = cell;
	vec2 best_c = cell + 0.5;
	float min_d = 1e10;
	float second_d = 1e10;

	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 n = cell + vec2(float(x), float(y));
			vec2 h = hash22(n + vec2(seed_value, seed_value * 1.7));
			vec2 pt = n + 0.5 + (h - 0.5) * cell_jitter;
			vec2 d = pt - g;
			float dd = dot(d, d);
			if (dd < min_d) {
				second_d = min_d;
				min_d = dd;
				best = n;
				best_c = pt;
			} else if (dd < second_d) {
				second_d = dd;
			}
		}
	}
	center = best_c / shards;
	// 到 Voronoi 边界的距离 ≈ (d2 - d1) / 2，再换算到 UV 单位
	edge_dist = (sqrt(second_d) - sqrt(min_d)) * 0.5 / max(shards.x, 0.001);
	return best;
}

void fragment() {
	vec2 uv = UV;

	vec2 center;
	float edge0;
	vec2 id = voronoi_cell(uv, center, edge0);

	// 每块碎片独立的随机数
	float h1 = hash21(id + vec2(seed_value + 1.0,   seed_value + 5.3));
	float h2 = hash21(id + vec2(seed_value + 71.17, seed_value + 2.3));
	float h3 = hash21(id + vec2(seed_value + 137.29, seed_value + 9.1));
	float h4 = hash21(id + vec2(seed_value + 233.51, seed_value + 41.7));

	// 各碎片错峰启动
	float delay = h1 * 0.45;
	float t = clamp((progress - delay) / max(1.0 - delay, 0.001), 0.0, 1.0);
	float tt = t * t;  // 加速坠落

	// 旋转
	float rot = (h2 - 0.5) * 2.0 * rotation_strength * t;
	float cr = cos(rot);
	float sr = sin(rot);

	// 从画面中心向外的"炸开"方向
	vec2 outward = center - vec2(0.5);
	float ol = length(outward);
	outward = ol > 0.0001 ? outward / ol : vec2(0.0);

	// 位移 = 向外炸开 + 随机水平漂移 + 重力下落
	float hx = (h3 - 0.5) * 2.0;
	vec2 offset = vec2(
		hx * drift_strength * t + outward.x * drift_strength * t * (0.7 + h4 * 0.8),
		fall_strength * tt + outward.y * drift_strength * t * 0.3
	);

	// 把当前像素逆变换回源坐标
	vec2 rel = uv - center - offset;
	vec2 src_rel = vec2(cr * rel.x + sr * rel.y, -sr * rel.x + cr * rel.y);
	vec2 src = center + src_rel;

	vec4 col = vec4(0.0);

	// 判断 src 是否还在同一块碎片内
	vec2 src_center;
	float src_edge;
	vec2 src_id = voronoi_cell(src, src_center, src_edge);

	if (all(lessThan(abs(src_id - id), vec2(0.5)))) {
		col = texture(TEXTURE, src);

		// 碎片边缘的裂纹高光：在 progress 早期出现，中后期淡出
		float crack_glow = (1.0 - smoothstep(0.0, crack_width, src_edge))
			* smoothstep(0.0, 0.06, progress)
			* (1.0 - smoothstep(0.2, 0.5, progress));
		col.rgb += crack_glow * 0.8 * col.a;

		// 逐块淡出
		col.a *= 1.0 - t;
	}

	COLOR = col;
}