shader_type canvas_item;

// Enchantment outline shader for inventory items
// Adapted from godotshaders.com colorful-outline

uniform float outline_width : hint_range(0.0, 10.0) = 2.0;
uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 1.0, 1.0);
uniform float outline_alpha : hint_range(0.0, 1.0) = 0.8;

void fragment() {
	vec4 original_color = texture(TEXTURE, UV);

	// If pixel is already opaque, keep it as-is
	if (original_color.a > 0.1) {
		COLOR = original_color;
	} else {
		// Check surrounding pixels for edges
		vec2 texture_size = vec2(textureSize(TEXTURE, 0));
		vec2 pixel_size = 1.0 / texture_size;

		float outline = 0.0;
		float search_range = outline_width;

		// Sample surrounding pixels
		for (float x = -search_range; x <= search_range; x += 1.0) {
			for (float y = -search_range; y <= search_range; y += 1.0) {
				if (x == 0.0 && y == 0.0) continue;

				vec2 offset = vec2(x, y) * pixel_size;
				float sample_alpha = texture(TEXTURE, UV + offset).a;

				if (sample_alpha > 0.1) {
					outline = 1.0;
					break;
				}
			}
			if (outline > 0.0) break;
		}

		// Apply outline color if edge detected
		if (outline > 0.0) {
			COLOR = vec4(outline_color.rgb, outline_color.a * outline_alpha);
		} else {
			COLOR = vec4(0.0);
		}
	}
}
