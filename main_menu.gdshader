shader_type canvas_item;

// Taasan natin ang alpha at contrast para mas "punchy" ang usok
uniform vec4 smoke_color : source_color = vec4(0.8, 0.8, 0.8, 0.9);
uniform float speed : hint_range(0.0, 1.0) = 0.1;
uniform float density : hint_range(0.1, 2.0) = 0.8;

// Better random function para iwas sa grid artifacts
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Smooth noise function (Bilinear Interpolation)
// Ito ang tatanggal sa pixelations
float smooth_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    // Quintic interpolation curve para sa mas swabe na edges
    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(mix(hash(i + vec2(0.0,0.0)), hash(i + vec2(1.0,0.0)), u.x),
               mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x), u.y);
}

// FBM (Fractal Brownian Motion) para sa detalye ng usok
float fbm(vec2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        v += amp * smooth_noise(p);
        p *= 2.1;
        amp *= 0.5;
    }
    return v;
}

void fragment() {
    // Zoom level: Mas maliit na number, mas malaki/swabe ang ulap
    vec2 uv = UV * 5.0;
    
    // Time-based movement
    float t = TIME * speed;
    
    // Layering ng noise para sa depth
    float n = fbm(uv + vec2(t, t * 0.3));
    n = fbm(uv - vec2(t * 0.2, n)); // Distorted layer
    
    // CONTRAST BOOST: Ginagawang mas solid ang usok
    // Ang 0.2 at 0.8 ang nagdidikta kung gaano "sharp" ang transitions
    float smoke_mask = smoothstep(0.2, 0.8, n * density);
    
    // Fade out sa taas (UV.y) para hindi biglang napuputol ang usok
    float vertical_fade = pow(1.0 - UV.y, 1.5);
    
    vec4 final_color = smoke_color;
    final_color.a *= smoke_mask * vertical_fade;
    
    COLOR = final_color;
}