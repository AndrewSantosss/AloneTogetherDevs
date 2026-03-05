shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 mouse_pos = vec2(0.5); // Naka-normalize (0.0 to 1.0)
uniform float distortion_strength : hint_range(-1.0, 1.0) = 0.2;
uniform float radius : hint_range(0.0, 1.0) = 0.4;

void fragment() {
    vec2 uv = UV;
    
    // Kunin ang vector mula sa mouse papunta sa kasalukuyang pixel
    vec2 dir = uv - mouse_pos;
    float dist = length(dir);
    
    // I-stretch ang UV kapag malapit sa mouse (Fish-eye effect)
    if (dist < radius) {
        float percent = 1.0 - (dist / radius);
        // Dito nangyayari yung "stretch"
        uv -= dir * distortion_strength * percent;
    }
    
    COLOR = texture(TEXTURE, uv);
}