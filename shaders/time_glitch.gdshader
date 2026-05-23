shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float color_aberration : hint_range(0.0, 0.05) = 0.003;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.25;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.4;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.08;

// Pseudo-random noise generator
float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // Chromatic Aberration (color offset)
    vec2 r_offset = vec2(color_aberration, 0.0);
    vec2 b_offset = vec2(-color_aberration, 0.0);
    
    float r = texture(screen_texture, uv + r_offset).r;
    float g = texture(screen_texture, uv).g;
    float b = texture(screen_texture, uv + b_offset).b;
    
    vec3 color = vec3(r, g, b);
    
    // Fullscreen Noise / Static
    float noise = rand(uv * TIME) * noise_strength;
    color += vec3(noise);
    
    // Vignette
    float vignette = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    vignette = clamp(pow(16.0 * vignette, vignette_strength), 0.0, 1.0);
    color *= vignette;
    
    // Horizontal Scanlines
    float scanline = sin(uv.y * 240.0 * 3.14159 * 2.0);
    scanline = mix(1.0, (scanline + 1.0) * 0.5, scanline_strength);
    color *= scanline;
    
    COLOR = vec4(color, 1.0);
}
