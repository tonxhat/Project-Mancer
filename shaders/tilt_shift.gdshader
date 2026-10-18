// Tilt-shift lens: blurs the top and bottom of the screen so the battle in the
// middle looks like a miniature diorama (the Octopath "HD-2D" lens look).
// Screen-space, so it is cheap and works on Forward+, Mobile and the web (Compatibility).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// Blur fades to zero at this height from the top (0 = top edge, 1 = bottom edge).
uniform float top_clear : hint_range(0.0, 1.0) = 0.28;
// Blur starts at this height and is strongest at the bottom edge.
uniform float bottom_clear : hint_range(0.0, 1.0) = 0.70;
// Strength of the blur.
uniform float strength : hint_range(0.0, 6.0) = 2.6;

void fragment() {
	float y = SCREEN_UV.y;
	float top_amount = 1.0 - smoothstep(0.0, top_clear, y);
	float bottom_amount = smoothstep(bottom_clear, 1.0, y);
	float lod = max(top_amount, bottom_amount) * strength;
	// a few taps at that blur level keep it soft instead of blocky
	vec2 px = SCREEN_PIXEL_SIZE * exp2(lod) * 0.75;
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb * 0.4;
	c += textureLod(screen_tex, SCREEN_UV + vec2(px.x, px.y), lod).rgb * 0.15;
	c += textureLod(screen_tex, SCREEN_UV + vec2(-px.x, px.y), lod).rgb * 0.15;
	c += textureLod(screen_tex, SCREEN_UV + vec2(px.x, -px.y), lod).rgb * 0.15;
	c += textureLod(screen_tex, SCREEN_UV + vec2(-px.x, -px.y), lod).rgb * 0.15;
	COLOR = vec4(c, 1.0);
}
