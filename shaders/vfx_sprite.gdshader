// PIXEL-ART HIT EFFECT (sprite sheet from the Mancer battle prototype).
// Always faces the camera, stays crisp (nearest filter + alpha cut), and the bright
// pixels are pushed above 1.0 so the scene's Glow makes them bloom.
shader_type spatial;
// depth_test_disabled: never cut by the ground, the target or props — always shown whole.
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;

uniform sampler2D tex : source_color, filter_nearest;
// How hard the effect glows. 0 = flat pixels, 1.5 = soft bloom, 3+ = blazing.
uniform float glow = 1.5;
instance uniform float fade = 1.0;

void vertex() {
	mat4 w = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * w;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 c = texture(tex, UV);
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	ALBEDO = c.rgb * (1.0 + glow * lum * lum * 2.0);
	ALPHA = step(0.5, c.a) * fade;   // hard pixel edges, drawn after the scene
}
