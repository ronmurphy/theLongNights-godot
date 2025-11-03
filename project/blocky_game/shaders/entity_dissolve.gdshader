shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

// Dissolve shader for entity death effect
// Based on: https://godotshaders.com/shader/2d-vertical-pixel-dissolving-wave/
// Adapted for Sprite3D (spatial shader)

uniform sampler2D texture_albedo : source_color, filter_nearest;
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float wave_height : hint_range(0.0, 1.0) = 0.2;
uniform float wave_speed : hint_range(0.0, 10.0) = 2.0;
uniform float grain_size : hint_range(1.0, 20.0) = 5.0;

// Simple noise function
float noise(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    
    // Create vertical wave effect
    float wave = sin(uv.x * 10.0 + TIME * wave_speed) * wave_height;
    
    // Add grain/pixelation
    vec2 grain_uv = floor(uv * grain_size) / grain_size;
    float grain = noise(grain_uv);
    
    // Calculate dissolve threshold with wave
    float dissolve_threshold = dissolve_amount + wave - 0.5;
    
    // Apply grain to threshold
    dissolve_threshold += (grain - 0.5) * 0.3;
    
    // Sample texture
    vec4 tex = texture(texture_albedo, uv);
    
    // Discard pixels based on dissolve amount
    if (uv.y < dissolve_threshold || tex.a < 0.5) {
        discard;
    }
    
    // Output color
    ALBEDO = tex.rgb;
    ALPHA = tex.a;
}
