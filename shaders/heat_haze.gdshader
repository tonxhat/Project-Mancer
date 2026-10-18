// HEAT HAZE: bends whatever is behind it with flowing noise (hot air over fire / explosions).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float strength = 0.012;
uniform vec2 speed = vec2(0.0, -0.6);
uniform vec2 tiling = vec2(1.5, 2.0);
uniform float edge = 0.45;
instance uniform float fade = 1.0;

void fragment() {
	vec2 n = vec2(texture(noise_tex, UV * tiling + TIME * speed).r,
	              texture(noise_tex, UV * tiling * 1.3 - TIME * speed * 0.7 + 0.37).r) - 0.5;
	float m = smoothstep(0.0, edge, UV.x) * smoothstep(0.0, edge, 1.0 - UV.x)
	        * smoothstep(0.0, edge, UV.y) * smoothstep(0.0, edge, 1.0 - UV.y);
	vec2 suv = SCREEN_UV + n * strength * m * fade;
	ALBEDO = textureLod(screen_tex, suv, 0.0).rgb;
	ALPHA = m * fade;
}
