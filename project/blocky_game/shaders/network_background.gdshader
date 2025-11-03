/**
 * Starfield Background Shader - Optimized for "The Long Nights"
 * 
 * Replaced: network_background.gdshader (archived as ARCHIVED_network_background.gdshader)
 * Date: November 3, 2025
 * 
 * Credits: Adapted from "The Art of Code" tutorial by Martijn Steinrucken
 * Original: https://godotshaders.com/shader/starfield-parallax-shader/
 * 
 * Optimizations for performance:
 * - Reduced layers from 8 to 5 for better performance
 * - Adjusted scale and depth for less intensity
 * - Slower rotation and twinkle speed
 * - Darker overall appearance for subtle background
 * 
 * Performance: Medium (comparable to original network shader)
 */

shader_type canvas_item;

uniform vec2 VIEWPORT_SIZE = vec2(1920, 1080);

// Reduced from 8 layers to 5 for better performance
#define NUM_LAYERS 5.0

mat2 Rot(float theta) {
    float cosa = cos(theta);
    float sina = sin(theta);
    return mat2(
        vec2(cosa, -sina),
        vec2(sina,  cosa)
    );
}

float Star(vec2 uv, float flare) {
    float d = length(uv);
    float m = .015 / d;  // Slightly smaller stars

    float rays = max(0.0, 1.0 - abs(uv.x * uv.y * 10000.0));
    m += rays * flare * 0.6;  // Reduced flare intensity
    uv *= Rot(PI / 4.0);
    rays = max(0.0, 1.0 - abs(uv.x * uv.y * 10000.0));
    m += rays * 0.2 * flare;  // Further reduced secondary rays

    m *= smoothstep(1.0, 0.2, d);
    return m;
}

float Hash21(vec2 p) {
    p = fract(p * vec2(123.23, 456.34));
    p += dot(p, p + 45.45);
    return fract(p.x * p.y);	
}

vec3 StarLayer(vec2 uv) {
    vec3 col = vec3(0.0);
    vec2 gv = fract(uv) - 0.5;
    vec2 id = floor(uv);

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 offset = vec2(float(x), float(y));
            float n = Hash21(id + offset);
            float size = fract(n * 534.0);
            float star = Star(gv - offset - vec2(n - 0.5, fract(n * 165.0) - 0.5), 
                            smoothstep(0.9, 0.1, size) * 0.8);  // Reduced flare
            
            // Subtle color variations (cooler tones for night theme)
            vec3 colors = sin(vec3(0.2, 0.4, 0.9) * fract(n * 2434.0) * 123.0) * 0.4 + 0.6;
            colors *= vec3(0.8, 0.9, 1.2 + size);  // Cooler, blue-tinted
            
            // Slower twinkling
            star *= sin(TIME * 1.5 + n * 18.3) * 0.4 + 0.7;
            col += star * size * colors;
        }
    }
    return col;
}

void fragment() {
    vec2 fragCoord = UV * VIEWPORT_SIZE;
    vec2 uv = (fragCoord - 0.5 * VIEWPORT_SIZE) / VIEWPORT_SIZE.y;
    
    // Slower rotation for more subtle effect
    float t = TIME * 0.03;
    uv *= Rot(t);

    vec3 col = vec3(0.0);

    for (float i = 0.0; i < 1.0; i += 1.0 / NUM_LAYERS) {
        float depth = fract(i + t);
        float scale = mix(18.0, 0.5, depth);  // Adjusted scale for less density
        float fade = depth * smoothstep(1.0, 0.9, depth);
        col += StarLayer(uv * scale + i * 343.0) * fade;
    }

    // Darker output for subtle background (0.4 instead of 1.0 alpha)
    COLOR = vec4(col * 0.5, 0.4);
}
