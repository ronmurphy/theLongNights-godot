shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

// Animation uniforms
uniform float time_scale : hint_range(0.0, 8.0, 0.01) = 3.0;

// Shape uniforms
uniform sampler2D base_noise : hint_default_white, filter_linear_mipmap;
uniform float noise_scale : hint_range(0.0, 5.0, 0.01) = 2.0;

// Color uniforms
uniform vec4 impact_color : source_color = vec4(0.8, 0.6, 0.4, 1.0);  // Dust/stone color
uniform float emission_strength : hint_range(0.0, 5.0, 0.1) = 2.5;

varying float LIFETIME;

float easeOutQuad(float x) {
	return 1.0 - (1.0 - x) * (1.0 - x);
}

float easeOutCubic(float x) {
	return 1.0 - pow(1.0 - x, 3.0);
}

void vertex() {
	LIFETIME = mod(TIME * time_scale, 1.0);
}

void fragment() {
	float progress = easeOutCubic(LIFETIME);

	// Radial distance from center
	vec2 centered_uv = UV - vec2(0.5);
	float dist = length(centered_uv) * 2.0;

	// Create expanding ring
	float ring_width = 0.3;
	float ring_center = progress;
	float ring = 1.0 - abs(dist - ring_center) / ring_width;
	ring = clamp(ring, 0.0, 1.0);

	// Sample noise for texture
	vec2 noise_uv = UV * noise_scale + vec2(0.0, progress * 0.5);
	float noise = texture(base_noise, noise_uv).r;

	// Combine ring with noise
	float shockwave = ring * noise;

	// Fade out over time
	float fade = smoothstep(0.0, 0.1, progress) * smoothstep(1.0, 0.6, progress);
	shockwave *= fade;

	// Apply color
	vec3 final_color = impact_color.rgb * shockwave;

	ALBEDO = final_color;
	EMISSION = final_color * emission_strength;
	ALPHA = clamp(shockwave * impact_color.a, 0.0, 1.0);
}
