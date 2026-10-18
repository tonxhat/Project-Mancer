// Additive glowing effects (fire, magic, sparks, flashes). See vfx_core.gdshaderinc.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/vfx_core.gdshaderinc"

void fragment() {
	vec3 c; float a;
	vfx_fragment(UV, COLOR, SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, c, a);
	ALBEDO = c;
	ALPHA = a;
}
