shader_type spatial;
render_mode unshaded, blend_mix, depth_test_inverted, depth_draw_never;
stencil_mode read, write, compare_not_equal, 1;

uniform vec3 shadow_colour:source_color = vec3(0.7,0.7,0.9);
uniform sampler2D main_texture:source_color;

void vertex() {
	// Billboard effect: make sprite always face camera while keeping Y-axis vertical
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]
	);
}

void fragment() {
	// Sample the texture to get alpha channel
	vec4 sample = texture(main_texture, UV);

	// Discard transparent pixels so silhouette matches sprite shape
	if (sample.a < 0.5) {
		discard;
	}

	ALBEDO = shadow_colour;
	ALPHA = sample.a;
}
