shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width = 1.0;
uniform int type : hint_range(0, 2) = 2;
uniform int active : hint_range(0,1) = 1;
uniform float threshold : hint_range(0.0, 1.0) = 0.1; // Sensitivity

const vec2[8] DIRECTIONS = {
    vec2(1.0, 0.0), vec2(0.0, 1.0), vec2(-1.0, 0.0), vec2(0.0, -1.0),
    vec2(1.0, 1.0), vec2(-1.0, 1.0), vec2(-1.0, -1.0), vec2(1.0, -1.0)
};

float gtz(float input) { return max(0.0, sign(input)); }

float check_color(sampler2D tex, vec2 from, vec2 size) {
    float result = 0.0;
    vec4 ref_color = texture(tex, from);
    float ref_val = length(ref_color.rgb); // Use length for brightness logic

    for (int i = 0; i < 4 * type; i++) {
        vec4 neighbor_color = texture(tex, from + DIRECTIONS[i] * size * outline_width);
        
        // Compare brightness/color difference
        float dist = distance(ref_color.rgb, neighbor_color.rgb);
        
        if (dist > threshold) {
            result = 1.0;
        }
    }
    return result;
}

void fragment() {
    vec4 original_color = texture(TEXTURE, UV);
    
    if (active > 0) {
        float is_edge = check_color(TEXTURE, UV, TEXTURE_PIXEL_SIZE);
        // Kung edge siya, kulayan ng outline_color, kung hindi, original color
        COLOR = mix(original_color, outline_color, is_edge);
    } else {
        COLOR = original_color;
    }
}