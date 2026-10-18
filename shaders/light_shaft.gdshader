// Soft beam of sunlight (god ray) on a flat quad. Additive, no lighting cost.
// Fades out at both ends and both sides, and slowly shimmers like light through leaves.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 beam_color : source_color = vec4(1.0, 0.82, 0.55, 1.0);
uniform float intensity = 0.45;
uniform float shimmer_speed = 0.35;
instance uniform float seed = 0.0;

void fragment() {
	float across = sin(UV.x * PI);                      // soft sides
	across *= across;
	float along = smoothstep(0.0, 0.35, UV.y) * (1.0 - smoothstep(0.5, 0.95, UV.y));  // UV.y 0 = sun end; fades out before the ground
	float t = TIME * shimmer_speed + seed * 13.0;
	float stripes = 0.65 + 0.35 * sin(UV.x * 9.0 + t * 2.0 + seed * 5.0) * sin(UV.x * 4.0 - t);
	float breathe = 0.75 + 0.25 * sin(t * 1.3 + seed * 7.0);
	float a = across * along * stripes * breathe * intensity;
	ALBEDO = beam_color.rgb * a;
}
