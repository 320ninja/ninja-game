shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Newari building facade — warm brick walls, dark timber window frames,
// oil-lamp lit rooms.  No cool blue glass anywhere.

uniform vec3 wall_colour : source_color = vec3(0.60, 0.28, 0.16);  // Newari red brick default
uniform vec3 timber_colour : source_color = vec3(0.18, 0.11, 0.06); // dark timber frames
uniform vec3 shopfront_colour : source_color = vec3(0.84, 0.56, 0.10); // saffron/ochre shop
uniform vec3 window_lit_colour : source_color = vec3(1.0, 0.76, 0.38); // warm oil-lamp yellow
uniform float building_height = 12.0;
uniform float floor_height = 3.4;
uniform float window_span = 2.6;
uniform float lit_ratio = 0.28;
uniform float seed = 0.0;

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos  = VERTEX;
	local_normal = NORMAL;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.3) * 43758.5453);
}

void fragment() {
	bool is_wall = abs(local_normal.y) < 0.5;
	bool is_top  = local_normal.y > 0.5;

	// Top faces: dark timber (Newari buildings have flat dark rooftops).
	if (is_top) {
		ALBEDO     = timber_colour * 1.3;
		ROUGHNESS  = 0.92;
		METALLIC   = 0.0;
		return;
	}

	if (!is_wall) {
		ALBEDO = timber_colour;
		ROUGHNESS = 0.95;
		return;
	}

	// Wall face.
	float horiz = abs(local_normal.x) > 0.5 ? local_pos.z : local_pos.x;
	// Shift so row 0 starts at the building base.
	float vert  = local_pos.y + building_height * 0.5;

	vec2 cell   = vec2(floor(horiz / window_span), floor(vert / floor_height));
	vec2 f      = vec2(fract(horiz / window_span), fract(vert / floor_height));
	int  floor_i = int(floor(vert / floor_height));

	vec3  albedo = wall_colour;
	float rough  = 0.88;
	float metal  = 0.0;
	float emit   = 0.0;

	// Ground floor: saffron shopfront with door-panel detail.
	if (floor_i == 0) {
		bool is_shutter = f.x > 0.10 && f.x < 0.90 && f.y > 0.08 && f.y < 0.72;
		if (is_shutter) {
			// Colour bands: alternate the shop hue slightly per cell.
			float hv = hash(vec2(cell.x, 0.0));
			vec3 shop = mix(shopfront_colour,
				vec3(shopfront_colour.r * 0.80, shopfront_colour.g * 0.60, 0.05),
				hv * 0.4);
			albedo = shop;
			rough  = 0.78;
		} else {
			albedo = timber_colour * 1.5;  // timber pillars/frame
		}
	}
	// Floor divider band: dark timber joist.
	else if (f.y < 0.09) {
		albedo = timber_colour * 1.4;
		rough  = 0.90;
	}
	// Upper-floor windows: warm timber frames with warm-lit interior.
	else {
		bool in_window = f.x > 0.14 && f.x < 0.86 && f.y > 0.18 && f.y < 0.82;
		if (in_window) {
			if (hash(cell) < lit_ratio) {
				// Lit room — warm oil-lamp glow.
				albedo = window_lit_colour;
				emit   = 1.0;
				rough  = 0.60;
			} else {
				// Unlit — dark timber interior.
				albedo = timber_colour * 0.6;
				rough  = 0.92;
			}
		}
		// Window frame: thin timber border.
		else if (f.x > 0.08 && f.x < 0.92 && f.y > 0.12 && f.y < 0.88) {
			albedo = timber_colour * 1.6;
			rough  = 0.90;
		}
	}

	ALBEDO    = albedo;
	ROUGHNESS = rough;
	METALLIC  = metal;
	EMISSION  = window_lit_colour * emit * 1.6;
}
