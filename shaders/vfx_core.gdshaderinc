// VFX CORE (week 4.5, "HD" effects) — shared by vfx_add.gdshader and vfx_blend.gdshader.
// The standard real-time VFX recipe (see realtimevfx.com "bread & butter" techniques):
//   shape texture  x  panning noise (flow)   -> a grey value
//   UV distortion by a second noise           -> the shape wobbles / burns
//   erosion: alpha = smoothstep(erode, erode+soft, value) -> eats away from the dim parts first
//   gradient map: grey value -> colour ramp (white-hot core, coloured body, dark edge)
//   HDR intensity -> bloom.  Soft depth fade where it touches the ground.
// Particles: INSTANCE_CUSTOM.y = age 0..1, so effects erode as they get older.

uniform sampler2D shape_tex : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform sampler2D flow_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D erode_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D gradient : source_color, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

uniform float use_shape = 1.0;          // 1 = multiply by shape_tex
uniform float use_flow = 0.0;           // 1 = multiply by panning flow noise
uniform vec2 flow_tiling = vec2(1.0, 1.0);
uniform vec2 flow_speed = vec2(0.0, 0.0);
uniform vec2 erode_tiling = vec2(1.0, 1.0);
uniform vec2 erode_speed = vec2(0.0, 0.0);
uniform float distort = 0.0;            // UV wobble from erode_tex
uniform float noise_in_value = 0.3;     // how much erode noise breaks up the value (ragged edges)
uniform float erode_soft = 0.12;
uniform float erode_by_age = 0.0;       // particles: how much they erode over their life
uniform float intensity = 2.0;          // HDR multiplier (bloom)
uniform float alpha_mult = 1.0;
uniform float gradient_bias = 0.0;      // shifts the colour ramp (+ = hotter)
uniform float fade_v0 = 0.0;            // fade near uv.y = 0
uniform float fade_v1 = 0.0;            // fade near uv.y = 1
uniform float fade_u = 0.0;             // fade near both u edges
uniform float soft_depth = 0.0;         // soft particles: fade over this distance to geometry behind
uniform int billboard = 0;              // 0 none, 1 face camera, 2 stretch along velocity (particles)
uniform bool is_particles = false;      // INSTANCE_CUSTOM (angle, age) only exists on particles

instance uniform float erode = 0.0;     // 0 = whole, 1 = gone (tweened from scripts)
instance uniform float fade = 1.0;

varying float v_age;

void vertex() {
	v_age = is_particles ? INSTANCE_CUSTOM.y : 0.0;
	if (billboard == 1) {
		mat4 w = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
		float a = is_particles ? INSTANCE_CUSTOM.x : 0.0;
		w = w * mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * w;
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	} else if (billboard == 2) {
		// streak: long axis = particle's Y (aligned to velocity), flat side faces the camera
		vec3 y = MODEL_MATRIX[1].xyz;
		vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz);
		vec3 x = normalize(cross(normalize(y), to_cam)) * length(MODEL_MATRIX[0].xyz);
		vec3 z = normalize(cross(x, y));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(x, 0.0), vec4(y, 0.0), vec4(z, 0.0), MODEL_MATRIX[3]);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

float vfx_value(vec2 uv, out float mask) {
	float n = texture(erode_tex, uv * erode_tiling + TIME * erode_speed).r;
	vec2 duv = uv + (n - 0.5) * distort;
	float shape = mix(1.0, texture(shape_tex, duv).r, use_shape);
	float flow = mix(1.0, texture(flow_tex, duv * flow_tiling + TIME * flow_speed).r * 1.6, use_flow);
	float v = shape * flow * mix(1.0, n * 1.6, noise_in_value);
	mask = 1.0;
	if (fade_v0 > 0.0) mask *= smoothstep(0.0, fade_v0, uv.y);
	if (fade_v1 > 0.0) mask *= smoothstep(0.0, fade_v1, 1.0 - uv.y);
	if (fade_u > 0.0) mask *= smoothstep(0.0, fade_u, uv.x) * smoothstep(0.0, fade_u, 1.0 - uv.x);
	return v * mask;
}

void vfx_fragment(vec2 uv, vec4 col, vec2 screen_uv, vec3 vtx, mat4 inv_proj, out vec3 albedo, out float alpha) {
	float mask;
	float v = vfx_value(uv, mask);
	float e = erode + v_age * erode_by_age + (1.0 - col.a);
	float a = smoothstep(e, e + erode_soft, v);
	vec4 g = texture(gradient, vec2(clamp(v + gradient_bias, 0.01, 0.99), 0.5));
	albedo = g.rgb * col.rgb * intensity;
	alpha = clamp(a * g.a * alpha_mult * fade, 0.0, 1.0);
	if (soft_depth > 0.0) {
		float d = texture(depth_tex, screen_uv).r;
		vec4 p = inv_proj * vec4(screen_uv * 2.0 - 1.0, d, 1.0);
		float scene_z = p.z / p.w;
		alpha *= clamp((vtx.z - scene_z) / soft_depth, 0.0, 1.0);
	}
}
