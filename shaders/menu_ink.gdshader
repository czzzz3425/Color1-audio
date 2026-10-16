shader_type canvas_item;
render_mode unshaded;

uniform vec4 stains[12]; // local x/y, remaining strength, hue
uniform float awaken : hint_range(0.0, 1.0) = 0.0;
uniform float outline_width : hint_range(0.4, 2.0) = 1.0;
varying vec2 ink_position;

void vertex() {
	ink_position = VERTEX;
}

void fragment() {
	vec4 glyph = COLOR * texture(TEXTURE, UV);
	// Erode the original glyph to remove its interior; alpha exposes the real paper.
	vec2 step_uv = TEXTURE_PIXEL_SIZE * outline_width;
	float interior = texture(TEXTURE, UV).a;
	interior = min(interior, texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a);
	interior = min(interior, texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a);
	interior = min(interior, texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a);
	interior = min(interior, texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a);
	interior = min(interior, texture(TEXTURE, UV + step_uv * 0.7071).a);
	interior = min(interior, texture(TEXTURE, UV - step_uv * 0.7071).a);
	interior = min(interior, texture(TEXTURE, UV + vec2(step_uv.x, -step_uv.y) * 0.7071).a);
	interior = min(interior, texture(TEXTURE, UV + vec2(-step_uv.x, step_uv.y) * 0.7071).a);
	float contour = max(0.0, texture(TEXTURE, UV).a - interior);
	float pencil_grain = 0.90 + 0.10 * sin(ink_position.x * 2.1 + ink_position.y * 3.7);
	float coverage = awaken;
	vec3 pigment = vec3(0.28, 0.43, 0.30);
	for (int i = 0; i < 12; i++) {
		float wash = (1.0 - smoothstep(8.0, 85.0, distance(ink_position, stains[i].xy))) * stains[i].z;
		vec3 tint = 0.36 + 0.16 * cos(6.28318 * (stains[i].w + vec3(0.0, 0.33, 0.67)));
		pigment = mix(pigment, tint, wash);
		coverage = max(coverage, wash);
	}
	COLOR = vec4(mix(vec3(0.22, 0.25, 0.20), pigment, coverage) * glyph.rgb, contour * COLOR.a * pencil_grain);
}
