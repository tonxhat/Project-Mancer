// COMBO BLUR (ComboCinematic) — everything outside an ellipse around the hero + target is blurred,
// so the other heroes and monsters drop out of focus while the combo plays.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 center = vec2(0.5, 0.5);   // screen UV
uniform vec2 radius = vec2(0.22, 0.3);  // screen UV
uniform float softness = 0.6;
uniform float amount = 3.5;             // blur strength (mip level)
uniform float strength = 0.0;           // 0..1 fade

void fragment() {
	vec2 d = (SCREEN_UV - center) / radius;
	float m = smoothstep(1.0, 1.0 + softness, length(d)) * strength;
	float lod = amount * m;
	vec2 px = 1.0 / vec2(textureSize(screen_tex, 0)) * exp2(lod);
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb * 0.4;
	c += textureLod(screen_tex, SCREEN_UV + vec2(px.x, 0.0), lod).rgb * 0.15;
	c += textureLod(screen_tex, SCREEN_UV - vec2(px.x, 0.0), lod).rgb * 0.15;
	c += textureLod(screen_tex, SCREEN_UV + vec2(0.0, px.y), lod).rgb * 0.15;
	c += textureLod(screen_tex, SCREEN_UV - vec2(0.0, px.y), lod).rgb * 0.15;
	COLOR = vec4(c, clamp(m * 3.0, 0.0, 1.0));
}
