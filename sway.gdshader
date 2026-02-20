shader_type spatial;
// disable culling so back of leaves are visible, ensure opaque depth for shadows
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D grass_texture : filter_nearest, source_color;

// Added these variables so you can adjust them in the Inspector
uniform float sway_speed = 1.0;
uniform float sway_strength = 0.05; // Try increasing this if objects are large
uniform float sway_phase_len = 8.0; // Controls how "tight" the waves are

void vertex() {
    // NORMAL calculation helps lighting look correct on flat sprites
    NORMAL = vec3(0.0, 1.0, 0.0);

    // Calculate world position for varied movement
    float strength = (1.0 - UV.y) * sway_strength;

    // Apply movement using the new uniforms
    VERTEX.x += sin(NODE_POSITION_WORLD.x * sway_phase_len + TIME * sway_speed) * strength;
    VERTEX.z += cos(NODE_POSITION_WORLD.z * sway_phase_len + TIME * (sway_speed * 0.7)) * (strength * 0.7);
}

void fragment() {
    vec4 albedo_tex = texture(grass_texture, UV);
    ALBEDO = albedo_tex.rgb;
    ALPHA = albedo_tex.a;

    // IMPORTANT: This cuts out the transparent parts of the PNG
    ALPHA_SCISSOR_THRESHOLD = 0.5;
}