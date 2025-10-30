shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
stencil_mode write, compare_always, 1;

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
	vec4 sample = texture(main_texture, UV);

	// Discard transparent pixels so they don't write to stencil
	if (sample.a < 0.5) {
		discard;
	}

	ALBEDO.rgb = sample.rgb;
	ALPHA = sample.a;
}
