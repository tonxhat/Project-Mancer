// Alpha-blended effects (dark smoke, shadow wisps, debris) — the dark shapes that make
// the bright parts read as bright. See vfx_core.gdshaderinc.
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
#include "res://shaders/vfx_core.gdshaderinc"

void fragment() {
	vec3 c; float a;
	vfx_fragment(UV, COLOR, SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, c, a);
	ALBEDO = c;
	ALPHA = a;
}
