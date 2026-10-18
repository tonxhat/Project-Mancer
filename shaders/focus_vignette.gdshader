// FOCUS VIGNETTE: darkens the whole screen a little, except soft ovals around
// the characters and monsters. The ovals follow the actors every frame
// (positions are sent in by scripts/focus_vignette.gd).
shader_type canvas_item;

const int MAX_SPOTS = 8;
// x, y = centre on screen (0..1), z, w = oval half-width / half-height (screen-height units)
uniform vec4 spots[MAX_SPOTS];
uniform int spot_count = 0;
uniform float aspect = 1.7778;            // screen width / height
uniform vec4 shade_color : source_color = vec4(0.05, 0.03, 0.1, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.35;  // darkness away from the actors
uniform float softness : hint_range(0.01, 2.0) = 0.6;  // how gently the clear oval fades out
uniform float edge_strength : hint_range(0.0, 1.0) = 0.2; // extra darkening in the screen corners

void fragment() {
	vec2 p = vec2(SCREEN_UV.x * aspect, SCREEN_UV.y);
	float clear = 0.0;
	for (int i = 0; i < MAX_SPOTS; i++) {
		if (i >= spot_count) break;
		vec4 s = spots[i];
		vec2 d = (p - vec2(s.x * aspect, s.y)) / max(s.zw, vec2(0.001));
		float r = length(d);                         // 1.0 = edge of the clear oval
		clear = max(clear, 1.0 - smoothstep(1.0, 1.0 + softness * 2.0, r));
	}
	vec2 c = SCREEN_UV - 0.5;
	float corner = smoothstep(0.35, 0.85, length(c * vec2(1.0, 1.2)));
	float dark = strength * (1.0 - clear) + edge_strength * corner;
	COLOR = vec4(shade_color.rgb, clamp(dark, 0.0, 1.0));
}
