shader_type canvas_item;
// Pixela lo que hay detrás de este rectángulo (el mundo 3D y el HUD).
// pixel_size = 1 se ve normal; 40 son bloques enormes.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float pixel_size = 1.0;
uniform float darken = 0.0;
uniform vec4 tint : source_color = vec4(0.6, 0.1, 0.15, 1.0);
uniform float tint_amount = 0.0;

void fragment() {
	vec2 block = SCREEN_PIXEL_SIZE * max(pixel_size, 1.0);
	vec2 uv = (floor(SCREEN_UV / block) + 0.5) * block;
	vec3 c = texture(screen_tex, uv).rgb;
	c = mix(c, tint.rgb, tint_amount) * (1.0 - darken);
	COLOR = vec4(c, 1.0);
}
