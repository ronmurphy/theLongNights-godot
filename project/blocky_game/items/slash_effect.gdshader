shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

// Animation uniforms
uniform float progress : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float time_scale : hint_range(0.0, 8.0, 0.01) = 4.0;

// Shape uniforms
uniform sampler2D base_noise : hint_default_white, filter_linear_mipmap;
uniform float zoom : hint_range(0.0, 2.0, 0.01) = 0.6;
uniform float rotate_all : hint_range(0.0, 360.0, 0.1) = 285.0;

// Color uniforms
uniform vec4 slash_color : source_color = vec4(0.8, 0.9, 1.0, 1.0);  // Light blue/white
uniform float emission_strength : hint_range(0.0, 5.0, 0.1) = 2.0;

varying float LIFETIME;

vec2 polar_coordinates(vec2 uv, vec2 center, float zoomm) {
	vec2 dir = uv - center;
	float radius = length(dir) * 2.0;
	float angle = atan(dir.y, dir.x) * 1.0 / (3.14159 * 2.0);
	return mod(vec2(radius * zoomm, angle), 1.0);
}

vec2 rotate(vec2 uv, vec2 pivot, float angle) {
	mat2 rotation = mat2(vec2(sin(angle), -cos(angle)),
						vec2(cos(angle), sin(angle)));
	uv -= pivot;
	uv = uv * rotation;
	uv += pivot;
	return uv;
}

float easeOutExpo(float x) {
	return x == 1.0 ? 1.0 : 1.0 - pow(2.0, -10.0 * x);
}

void vertex() {
	LIFETIME = mod(TIME * time_scale, 1.0);
}

void fragment() {
	float p = easeOutExpo(LIFETIME);

	vec2 aUV = polar_coordinates(rotate(UV, vec2(0.5), radians(rotate_all)), vec2(0.5), zoom);
	vec4 noise = texture(base_noise, aUV - vec2(0.0, p));

	// Create slash shape
	float slash_mask = noise.r;
	slash_mask *= (1.0 - abs(UV.x - 0.5) * 2.0);  // Width gradient
	slash_mask *= smoothstep(0.0, 0.1, p) * smoothstep(1.0, 0.7, p);  // Fade in/out

	// Apply color
	vec3 final_color = slash_color.rgb * slash_mask;

	ALBEDO = final_color;
	EMISSION = final_color * emission_strength;
	ALPHA = clamp(slash_mask * slash_color.a, 0.0, 1.0);
}
