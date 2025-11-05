shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

// The color to replace white/gray with
uniform vec4 target_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// How close a color needs to be to match (0.0 = exact match, higher = more tolerance)
uniform float color_tolerance : hint_range(0.0, 0.2) = 0.05;

// The texture
uniform sampler2D texture_albedo : source_color, filter_nearest;

void fragment() {
	// Sample the texture
	vec4 tex_color = texture(texture_albedo, UV);
	
	// Discard fully transparent pixels first
	if (tex_color.a < 0.1) {
		discard;
	}
	
	// Check if this is a neutral color (grayscale - equal R, G, B)
	// This identifies white/gray clothing colors
	float r = tex_color.r;
	float g = tex_color.g;
	float b = tex_color.b;
	
	// Calculate how "neutral" the color is (low variance = grayscale)
	float max_diff = max(max(abs(r - g), abs(g - b)), abs(r - b));
	
	// Calculate brightness (average of RGB)
	float brightness = (r + g + b) / 3.0;
	
	// If it's neutral (grayscale) AND bright enough (light gray/white clothes)
	// Threshold: max_diff < 0.10 means nearly equal RGB (more forgiving for compression)
	// Threshold: brightness > 0.60 means light colored (catches more light grays)
	if (max_diff < 0.10 && brightness > 0.60) {
		// This is white/light gray clothing - colorize it!
		// Use brightness to determine how dark the tinted color should be
		// brightness 1.0 = pure white -> full target color
		// brightness 0.6 = medium gray -> darker target color
		float color_intensity = (brightness - 0.60) / 0.40; // Normalize 0.60-1.0 to 0.0-1.0
		ALBEDO = target_color.rgb * mix(0.5, 1.0, color_intensity);
		ALPHA = tex_color.a;
	}
	else {
		// Keep original color (skin, hair, colored details, etc.)
		ALBEDO = tex_color.rgb;
		ALPHA = tex_color.a;
	}
}
