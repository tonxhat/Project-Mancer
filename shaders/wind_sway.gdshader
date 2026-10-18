// Wind sway for flat pixel-art props (bushes, grass tufts, trees) standing in 3D.
// The bottom stays planted, the top leans with the wind. The lean moves in whole
// sprite pixels, so it reads as pixel-art animation instead of smooth stretching.
// Shadows sway too, because the shadow pass runs the same vertex code.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D texture_albedo : source_color, filter_nearest;

// Shared by every swaying prop (set from the Atmosphere panel).
uniform float wind_strength = 1.0;
uniform float wind_speed = 1.0;

// Per object (set automatically from the Atmosphere panel).
instance uniform float sway = 0.12;      // how far the top leans, in world units
instance uniform float px = 0.03125;     // one sprite pixel in world units
instance uniform float phase = 0.0;      // offset so props don't move in sync

void vertex() {
	float top = 1.0 - UV.y;                       // 0 at the feet, 1 at the top
	vec3 root = NODE_POSITION_WORLD;
	float t = TIME * wind_speed;
	float gust = sin(t * 0.55 + root.x * 0.12) * 0.5 + 0.5;          // slow gusts
	float wave = sin(t * 2.0 + root.x * 0.7 + root.z * 0.45 + phase) * 0.7
	           + sin(t * 3.3 + root.x * 1.3 + phase * 1.7) * 0.3;    // fast flutter
	float lean = (0.35 + 0.65 * gust) * (0.25 + 0.75 * (wave * 0.5 + 0.5));
	float d = lean * sway * wind_strength * top * top;
	d = floor(d / px + 0.5) * px;                  // whole pixels only
	VERTEX.x += d;
}

void fragment() {
	vec4 c = texture(texture_albedo, UV);
	ALBEDO = c.rgb * COLOR.rgb;    // COLOR = the sprite's Modulate tint
	ALPHA = c.a * COLOR.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
}
