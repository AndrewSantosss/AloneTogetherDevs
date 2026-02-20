shader_type spatial;

// render_mode: unshaded (glow only), cull_disabled (visible both sides)
render_mode unshaded, cull_disabled;

// --- UNIFORMS PARA SA "DI TATAGOS" (Soft Collision) ---
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform float collision_fade_strength : hint_range(0.0, 5.0) = 1.0;

// --- UNIFORM PARA SA EDGES (Para di mukhang box) ---
uniform float edge_softness : hint_range(0.0, 1.0) = 0.1;

// --- BAGONG UNIFORM PARA SA LIWANAG (Emission) ---
uniform float emission_brightness : hint_range(0.0, 10.0) = 5.0; // Taasan mo ito para mas nakakasilaw

// fire uniforms
uniform float detail_strength = 3.0;
uniform float scroll_speed = 1.2;
uniform float fire_height = 1.0;
uniform float fire_shape = 1.5;
uniform float fire_thickness = 0.55;
uniform float fire_sharpness = 1.0;
uniform float intensity = 1.0;

// noise uniforms
uniform int noise_octaves = 6;
uniform float noise_lacunarity = 3.0;
uniform float noise_gain = 0.5;
uniform float noise_amplitude = 1.0;
uniform float noise_frequency = 1.5;

// 2D Value noise function
float hash(vec2 p) {
    p = fract(p * 0.3183099 + vec2(0.1, 0.1));
    p *= 17.0;
    return fract(p.x * p.y * (p.x + p.y));
}

// 2D Value noise function (smooth)
float noise(vec2 x) {
    vec2 p = floor(x);
    vec2 f = fract(x);

    float n = 
        hash(p)       * (1.0 - f.x) * (1.0 - f.y) +
        hash(p + vec2(1.0, 0.0)) * f.x * (1.0 - f.y) +
        hash(p + vec2(0.0, 1.0)) * (1.0 - f.x) * f.y +
        hash(p + vec2(1.0, 1.0)) * f.x * f.y;

    return n;
}

// Fractional Brownian Motion function (2D)
float fbm(vec2 p) {
    int octaves = noise_octaves;
    float lacunarity = noise_lacunarity;
    float gain = noise_gain;
    float amplitude = noise_amplitude;
    float frequency = noise_frequency;
    float total = 0.0;
    
    for (int i = 0; i < octaves; i++) {
        total += noise(p * frequency) * amplitude;
        frequency *= lacunarity;
        amplitude *= gain;
    }

    return total * 0.5;
}

void fragment() {
    vec2 uv = UV;

    // modified_uv for offset and animating UVs for fire    
    vec2 modified_uv = -uv;
    modified_uv.x = mod(modified_uv.x, 1.0) - 0.5;
    modified_uv.y += 0.84; // size vertical
    
    // fire noise scroll effect
    float scroll = scroll_speed * detail_strength * TIME;
    
    // sample noise for fire
    float noise_val = fbm(detail_strength * modified_uv - vec2(0.0, scroll));
    
    // controls the intensity of noise
    float fire_intensity = intensity - 16.0 * fire_sharpness * pow(
        max(
            0.0,
            length(
                modified_uv * vec2((1.0 / fire_thickness) + modified_uv.y * fire_shape, 1.0 / fire_height)
            ) - noise_val * max(0.0, modified_uv.y + 0.25)
        ),
        1.2
    );
    float fire_intensity1 = noise_val * fire_intensity * (1.5 - pow(1.0 * uv.y, 14.0));
    fire_intensity1 = clamp(fire_intensity1, 0.0, 1.0);

    // compute fire color
    vec3 fire_color = vec3(
        1.5 * fire_intensity1,
        1.5 * pow(fire_intensity1, 3.0),
        pow(fire_intensity1, 6.0)
    );

    // add alpha to color
    float alpha = fire_intensity * (1.0 - pow(uv.y, 3.0));

    // --- BORDER MASK ---
    float side_mask = smoothstep(0.0, edge_softness, uv.x) * smoothstep(1.0, 1.0 - edge_softness, uv.x);
    float top_mask = smoothstep(0.0, edge_softness, uv.y);
    float bottom_mask = smoothstep(1.0, 1.0 - edge_softness, uv.y);
    alpha *= side_mask * top_mask * bottom_mask;
    
    // --- SOFT COLLISION ---
    float scene_depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
    vec4 world_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
    world_view.xyz /= world_view.w;
    
    float vertical_depth = -world_view.z;
    float surface_depth = -VERTEX.z;
    float diff = vertical_depth - surface_depth;
    
    float proximity = clamp(diff * collision_fade_strength, 0.0, 1.0);
    alpha *= proximity;
    
    // Final Colors
    vec4 final_color = vec4(
        mix(vec3(0.0), fire_color, alpha),
        alpha
    );
    
    ALBEDO = final_color.rgb;
    ALPHA = final_color.a;
    
    // --- EMISSION LOGIC ---
    // Minumultiply natin ang kulay sa brightness factor para mag-bloom
    EMISSION = final_color.rgb * emission_brightness;
}