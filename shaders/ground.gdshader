shader_type spatial;
render_mode cull_back, diffuse_burley;

// Kathmandu ground — dusty ochre-grey soil with worn stone pavement patches.
// No grid-based lane markings (road geometry handles roads separately).

uniform vec3 soil_colour   : source_color = vec3(0.42, 0.36, 0.26);  // dusty ochre
uniform vec3 stone_colour  : source_color = vec3(0.50, 0.45, 0.36);  // worn stone pavement
uniform vec3 dark_colour   : source_color = vec3(0.28, 0.24, 0.18);  // shadow cracks
uniform float block_size = 46.0;
uniform float world_extent = 780.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth value noise.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = world_pos.xz;

	// Large-scale pavement patchwork.
	float v1 = vnoise(uv * 0.012);
	// Fine-grain surface texture.
	float v2 = vnoise(uv * 0.06);
	// Crack-line detail.
	float v3 = vnoise(uv * 0.22);

	// Blend between soil, stone, and dark crack.
	vec3 col = mix(soil_colour, stone_colour, smoothstep(0.35, 0.65, v1));
	col = mix(col, col * 0.78, smoothstep(0.72, 0.85, v2));  // darker patches
	col = mix(col, dark_colour, smoothstep(0.85, 0.96, v3) * 0.45);  // crack hints

	// Slight warm tint toward the centre of the map (more foot traffic).
	float dist = length(world_pos.xz) / world_extent;
	col = mix(col, col * vec3(1.06, 1.02, 0.95), clamp(1.0 - dist * 1.5, 0.0, 1.0));

	ALBEDO    = col;
	ROUGHNESS = mix(0.90, 0.98, v2);
}
