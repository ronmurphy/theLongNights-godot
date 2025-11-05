shader_type canvas_item;

// The color to replace white/gray with
uniform vec4 target_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// How close a color needs to be to match (0.0 = exact match, higher = more tolerance)
uniform float color_tolerance : hint_range(0.0, 0.2) = 0.05;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Define the colors we want to replace
	vec3 white = vec3(1.0, 1.0, 1.0);      // #FFFFFF
	vec3 light_gray = vec3(0.8, 0.8, 0.8); // #CCCCCC
	
	// Calculate distance from white and light gray
	float dist_white = distance(tex_color.rgb, white);
	float dist_gray = distance(tex_color.rgb, light_gray);
	
	// If the pixel is close to white or light gray, replace it
	if (dist_white < color_tolerance) {
		// Replace white with target color
		COLOR = vec4(target_color.rgb, tex_color.a);
	}
	else if (dist_gray < color_tolerance) {
		// Replace light gray with a darker version of target color (for shadows)
		COLOR = vec4(target_color.rgb * 0.8, tex_color.a);
	}
	else {
		// Keep original color (skin, hair, etc.)
		COLOR = tex_color;
	}
}
