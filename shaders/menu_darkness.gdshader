shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform vec2 viewport_size = vec2(1152.0, 648.0);
uniform vec2 light_position = vec2(700.0, 320.0);
uniform float light_radius = 0.0;
uniform float release : hint_range(0.0, 1.0) = 0.0;

// x/y: normalized position, z: age, w: active. Drops stay where they land.
uniform vec4 drops[40];

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), u.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), u.x), u.y);
}

float fibers(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1) * 0.28 + noise(p * 4.3) * 0.17;
}

void fragment() {
	vec2 pixel = UV * viewport_size;
	float scale = viewport_size.y;
	// Paper grain stays still; staggered pencil strokes appear over the real scene.
	vec2 warp = vec2(fibers(pixel * 0.012), fibers(pixel * 0.012 + 39.7)) - 0.5;
	vec2 soaked_pixel = pixel + warp * scale * 0.085;
	float field = 0.0;
	for (int i = 0; i < 40; i++) {
		float age = drops[i].z;
		float spread = 1.0 - exp(-age * 2.4);
		float fade = 1.0 - smoothstep(2.5, 4.2, age);
		float arrival = smoothstep(0.0, 0.24, age);
		float radius = mix(0.008, 0.125, spread) * scale;
		vec2 offset = soaked_pixel - drops[i].xy * viewport_size;
		float r2 = radius * radius;
		field += drops[i].w * arrival * fade * r2 / max(dot(offset, offset) + r2 * 0.22, 1.0);
	}
	vec2 release_offset = soaked_pixel - light_position;
	field += light_radius * light_radius / max(dot(release_offset, release_offset) + 1.0, 1.0);
	float grain = fibers(pixel * 0.3);
	vec3 paper = vec3(0.90, 0.88, 0.82) + (grain - 0.5) * 0.032;
	vec3 scene = texture(scene_texture, SCREEN_UV).rgb;
	float luminance = dot(scene, vec3(0.299, 0.587, 0.114));
	// Follow the existing drawing rather than opening a hole into a white image.
	float graphite = 1.0 - smoothstep(0.12, 0.90, luminance);
	vec2 stroke_cell = floor(vec2(pixel.x + pixel.y * 0.6, pixel.y) / vec2(16.0, 3.0));
	float stroke_order = hash(stroke_cell);
	float progress = smoothstep(0.04, 1.6, field);
	float strokes = smoothstep(stroke_order * 0.70, stroke_order * 0.70 + 0.30, progress);
	float hatch = 1.0 - smoothstep(0.25, 0.75, abs(sin((pixel.x * 0.74 + pixel.y) * 1.3)));
	float left_margin = smoothstep(viewport_size.x * 0.28, viewport_size.x * 0.43, pixel.x);
	float pencil = graphite * strokes * mix(0.38, 0.86, progress) * (0.82 + grain * 0.18);
	vec3 drawing = paper - vec3(0.69, 0.68, 0.63) * pencil * left_margin;
	// Faint construction hatching precedes the complete contours.
	drawing -= vec3(0.07, 0.065, 0.055) * hatch * progress * (1.0 - progress) * graphite * left_margin;
	float settled = smoothstep(0.5, 0.95, progress) * left_margin;
	vec3 pigment = mix(vec3(0.52, 0.66, 0.48), vec3(0.72, 0.57, 0.38), fibers(pixel * 0.006));
	drawing = mix(drawing, drawing * mix(vec3(1.0), pigment, 0.075 * luminance), settled);
	// Existing colored art gradually returns; monochrome art stays drawn on paper.
	float saturation = max(scene.r, max(scene.g, scene.b)) - min(scene.r, min(scene.g, scene.b));
	drawing = mix(drawing, scene * paper, settled * smoothstep(0.05, 0.35, saturation) * 0.65);
	COLOR = vec4(mix(drawing, scene, release), 1.0);
}
