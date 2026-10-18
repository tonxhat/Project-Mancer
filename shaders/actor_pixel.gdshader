// ACTOR PIXEL SHADER (week 3)
// Draws a pixel-art sprite in the lit 3D world, plus:
//  - RIM LIGHT: a 1-3 pixel bright edge on the side facing the sun, so characters
//    pop off the background (the Octopath "outline of light" look).
//  - HIT FLASH: a glowing flash in the spell's colour when hit.
// rim_dir and flip are set per actor by scripts/actor_look.gd from the Sun's direction.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D texture_albedo : source_color, filter_nearest, repeat_disable;
uniform vec3 rim_color : source_color = vec3(1.0, 0.85, 0.6);
uniform float rim_strength = 1.0;
uniform int rim_width : hint_range(1, 3) = 1;
uniform float rim_top = 0.4;
// How dark shadows (trees, clouds, other characters) get ON the characters, compared
// to the ground: 1 = same as the ground, 0.45 = a lot lighter, 0 = no shadow on them.
uniform float actor_shadow : hint_range(0.0, 1.0) = 0.45;   // how much the top edges light up compared to the sun side

instance uniform vec2 rim_dir = vec2(1.0, -0.5);  // in picture pixels, toward the sun
instance uniform vec4 flash = vec4(0.0);          // rgb = colour, a = amount
// TURN GLOW (party battle): a glowing outline around the sprite. rgb = colour, a = strength (0 = off)
instance uniform vec4 outline = vec4(0.0);
// x = thickness in sprite pixels (1-4), y = corner roundness 0..1 (set by the TurnGlow node)
instance uniform vec2 outline_shape = vec2(2.0, 0.5);

void fragment() {
	vec4 c = texture(texture_albedo, UV);
	ALBEDO = c.rgb * COLOR.rgb;
	ALPHA = c.a;
	float edge = 0.0;
	if (outline.a > 0.001 && c.a < 0.5) {
		vec2 px = 1.0 / vec2(textureSize(texture_albedo, 0));
		int ow = int(clamp(outline_shape.x, 1.0, 4.0));
		float lim = float(ow) * (1.0 + clamp(outline_shape.y, 0.0, 1.0));
		for (int x = -4; x <= 4; x++) {
			for (int y = -4; y <= 4; y++) {
				if (abs(x) > ow || abs(y) > ow || float(abs(x) + abs(y)) > lim) continue;
				edge = max(edge, step(0.5, texture(texture_albedo, UV + vec2(float(x), float(y)) * px).a));
			}
		}
	}
	ALPHA_SCISSOR_THRESHOLD = 0.5;

	// rim: this pixel is solid, and the pixel next to it toward the sun is empty
	vec2 ts = 1.0 / vec2(textureSize(texture_albedo, 0));
	vec2 d = vec2(sign(rim_dir.x), sign(rim_dir.y));
	vec2 w = abs(rim_dir) / max(abs(rim_dir.x) + abs(rim_dir.y), 0.001);
	float rim = 0.0;
	for (int i = 1; i <= 3; i++) {
		if (i > rim_width) break;
		float ex = step(texture(texture_albedo, UV + vec2(d.x * ts.x * float(i), 0.0)).a, 0.5);
		float ey = step(texture(texture_albedo, UV + vec2(0.0, d.y * ts.y * float(i))).a, 0.5);
		rim = max(rim, max(ex * w.x, ey * w.y * rim_top));
	}
	EMISSION = rim_color * rim_strength * rim * c.a + flash.rgb * flash.a * c.a;
	if (edge > 0.0) {
		ALBEDO = vec3(0.0);
		ALPHA = 1.0;
		EMISSION = outline.rgb * outline.a;
	}
}

void light() {
	float att = ATTENUATION;
	if (LIGHT_IS_DIRECTIONAL) {
		att = mix(1.0, att, actor_shadow);   // soften sun shadows on the sprite only
	}
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * att * LIGHT_COLOR / PI;
}
