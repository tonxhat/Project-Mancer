extends RefCounted
## VFX HD (week 4.5) — high-resolution, AAA-style spell effects that sit on top of the
## pixel world, the same way Octopath's spells are smooth, glowing, non-pixel effects.
## Recipe per hit (from studying realtimevfx.com breakdowns + the references):
##   anticipation flash -> star burst + streak sparks -> dark spikes for contrast
##   -> shockwave ring on the ground -> heat haze -> smoke that erodes away -> scorch mark.

const ADD := preload("res://shaders/vfx_add.gdshader")
const BLEND := preload("res://shaders/vfx_blend.gdshader")
const HAZE := preload("res://shaders/heat_haze.gdshader")
const KIT := preload("res://scripts/vfx_kit.gd")

const T := {
	"flare": preload("res://art/vfx_hd/flare_01.png"),
	"glow": preload("res://art/vfx_hd/light_01.png"),
	"star": preload("res://art/vfx_hd/star_06.png"),
	"star2": preload("res://art/vfx_hd/star_08.png"),
	"spark": preload("res://art/vfx_hd/spark_05.png"),
	"trace": preload("res://art/vfx_hd/trace_01.png"),
	"smoke": preload("res://art/vfx_hd/smoke_05.png"),
	"smoke2": preload("res://art/vfx_hd/smoke_08.png"),
	"ring": preload("res://art/vfx_hd/circle_03.png"),
	"twirl": preload("res://art/vfx_hd/twirl_02.png"),
	"scorch": preload("res://art/vfx_hd/scorch_02.png"),
	"flame": preload("res://art/vfx_hd/flame_05.png"),
	"cloud": preload("res://art/vfx_hd/noise_cloud.png"),
	"streak": preload("res://art/vfx_hd/noise_streak.png"),
	"erode": preload("res://art/vfx_hd/noise_erode.png"),
}

## Colour ramps per element: dark/transparent end -> body colour -> white-hot core.
const RAMPS := {
	"Fire":      [Color(0, 0, 0), Color(0.55, 0.06, 0.02), Color(1.0, 0.38, 0.06), Color(1.0, 0.78, 0.32), Color(1, 0.97, 0.85)],
	"Magma":     [Color(0, 0, 0), Color(0.5, 0.04, 0.01), Color(1.0, 0.3, 0.04), Color(1.0, 0.7, 0.25), Color(1, 0.95, 0.8)],
	"Water":     [Color(0, 0, 0), Color(0.02, 0.1, 0.45), Color(0.08, 0.42, 1.0), Color(0.45, 0.85, 1.0), Color(0.92, 1, 1)],
	"Ice":       [Color(0, 0, 0), Color(0.05, 0.25, 0.5), Color(0.3, 0.7, 1.0), Color(0.7, 0.95, 1.0), Color(1, 1, 1)],
	"Lightning": [Color(0, 0, 0), Color(0.2, 0.08, 0.55), Color(0.45, 0.4, 1.0), Color(0.75, 0.8, 1.0), Color(1, 1, 1)],
	"Earth":     [Color(0, 0, 0), Color(0.35, 0.18, 0.05), Color(0.85, 0.55, 0.2), Color(1.0, 0.85, 0.55), Color(1, 0.97, 0.9)],
	"Air":       [Color(0, 0, 0), Color(0.05, 0.3, 0.22), Color(0.3, 0.85, 0.6), Color(0.75, 1.0, 0.85), Color(1, 1, 1)],
}
## Dark ramps for the contrast shapes (smoke, wisps, spikes).
const DARK := {
	"Fire": Color(0.12, 0.03, 0.02), "Magma": Color(0.1, 0.03, 0.02), "Water": Color(0.02, 0.04, 0.12),
	"Ice": Color(0.05, 0.08, 0.14), "Lightning": Color(0.05, 0.03, 0.12), "Earth": Color(0.12, 0.08, 0.05),
	"Air": Color(0.05, 0.1, 0.08),
}

static var _ramp_cache := {}


static func ramp(element: String) -> GradientTexture1D:
	if _ramp_cache.has(element):
		return _ramp_cache[element]
	var cols: Array = RAMPS.get(element, RAMPS["Fire"])
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.55, 0.8, 1.0])
	g.colors = PackedColorArray(cols)
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 128
	_ramp_cache[element] = t
	return t


static func dark_ramp(element: String) -> GradientTexture1D:
	var key := "dark_" + element
	if _ramp_cache.has(key):
		return _ramp_cache[key]
	var c: Color = DARK.get(element, DARK["Fire"])
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(c.r, c.g, c.b, 0.0), Color(c.r, c.g, c.b, 0.85), Color(c.r * 2.5, c.g * 2.5, c.b * 2.5, 0.95)])
	var t := GradientTexture1D.new()
	t.gradient = g
	_ramp_cache[key] = t
	return t


## Build a VFX material. p = any shader parameters to override.
static func mat(additive: bool, shape: Texture2D, grad: Texture2D, p := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ADD if additive else BLEND
	m.set_shader_parameter("shape_tex", shape)
	m.set_shader_parameter("gradient", grad)
	m.set_shader_parameter("flow_tex", T["streak"])
	m.set_shader_parameter("erode_tex", T["erode"])
	for k in p:
		m.set_shader_parameter(k, p[k])
	return m


static func _fade_out(node: GeometryInstance3D, delay: float, time: float, free_after := true) -> void:
	var tw := node.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(func(v): node.set_instance_shader_parameter("erode", v), 0.0, 1.0, time)
	if free_after:
		tw.tween_callback(node.queue_free)


static func quad(root: Node, at: Vector3, size: float, m: Material, billboard := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if billboard:
		m.set_shader_parameter("billboard", 1)
	root.add_child(mi)
	mi.global_position = at
	return mi


static func particles(root: Node, at: Vector3, m: Material, size: Vector2, amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = size
	(m as ShaderMaterial).set_shader_parameter("is_particles", true)
	q.material = m
	p.mesh = q
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(p)
	p.global_position = at
	root.get_tree().create_timer(life + 0.8).timeout.connect(p.queue_free)
	return p


# ------------------------------------------------------------------ hit
## A full HD impact. power 1 = normal spell, 2 = big.
static func impact(root: Node, at: Vector3, element: String, power := 1.0) -> void:
	var tree := root.get_tree()
	var g := ramp(element)
	var s := power
	# 1. flash: star burst + soft glow, pops in, erodes out
	var glow := quad(root, at + Vector3(0, 0, 0.5), 2.6 * s, mat(true, T["glow"], g, {"intensity": 2.5, "gradient_bias": 0.25, "noise_in_value": 0.0}))
	_fade_out(glow, 0.05, 0.3)
	var star := quad(root, at + Vector3(0, 0, 0.6), 0.4 * s, mat(true, T["star"], g, {"intensity": 5.0, "gradient_bias": 0.15, "noise_in_value": 0.15}))
	star.rotation.z = randf() * TAU
	var tw := star.create_tween()
	tw.tween_property(star, "scale", Vector3.ONE * 8.0, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_fade_out(star, 0.06, 0.22)
	# 2. streak sparks flying out, stretched along their velocity
	var sm := mat(true, T["trace"], g, {"billboard": 2, "intensity": 4.0, "gradient_bias": 0.2, "erode_by_age": 0.9, "noise_in_value": 0.0})
	var sp := particles(root, at + Vector3(0, 0, 0.5), sm, Vector2(0.3, 1.3) * s, int(22 * s), 0.45)
	sp.particle_flag_align_y = true
	sp.direction = Vector3(0.3, 0.6, 0.2)
	sp.spread = 180.0
	sp.initial_velocity_min = 4.0 * s
	sp.initial_velocity_max = 8.0 * s
	sp.damping_min = 6.0
	sp.damping_max = 10.0
	sp.gravity = Vector3(0, -3, 0)
	sp.scale_amount_min = 0.5
	sp.scale_amount_max = 1.3
	sp.emitting = true
	# 3. dark spikes behind the flash: the contrast that makes it read as bright
	var dm := mat(false, T["spark"], dark_ramp(element), {"billboard": 2, "intensity": 1.0, "erode_by_age": 1.0, "noise_in_value": 0.2})
	var dk := particles(root, at - Vector3(0, 0, 0.15), dm, Vector2(0.35, 1.3) * s, 7, 0.32)
	dk.particle_flag_align_y = true
	dk.spread = 180.0
	dk.initial_velocity_min = 3.0
	dk.initial_velocity_max = 5.0
	dk.damping_min = 18.0
	dk.damping_max = 24.0
	dk.gravity = Vector3.ZERO
	dk.emitting = true
	# 4. shockwave ring on the ground
	var ground := Vector3(at.x, 0.04, at.z)
	var rm := mat(true, T["ring"], g, {"intensity": 2.5, "noise_in_value": 0.5, "erode_speed": Vector2(0.2, 0.1), "erode_tiling": Vector2(2, 2)})
	var ring := quad(root, ground, 1.0, rm, false)
	ring.rotation.x = -PI / 2.0
	var tr := ring.create_tween()
	tr.tween_property(ring, "scale", Vector3.ONE * 4.0 * s, 0.4).from(Vector3.ONE * 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_fade_out(ring, 0.05, 0.4)
	# 5. smoke that rises and erodes away (alpha blended, dark)
	var smk := mat(false, T["smoke"], dark_ramp(element), {"billboard": 1, "erode_by_age": 1.0, "erode_soft": 0.3, "distort": 0.15, "erode_speed": Vector2(0.05, -0.1), "soft_depth": 0.4})
	var sk := particles(root, at, smk, Vector2(1.4, 1.4) * s, 7, 1.4)
	sk.explosiveness = 0.9
	sk.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sk.emission_sphere_radius = 0.3
	sk.direction = Vector3.UP
	sk.spread = 60.0
	sk.initial_velocity_min = 0.5
	sk.initial_velocity_max = 1.2
	sk.gravity = Vector3(0.2, 0.4, 0)
	sk.damping_min = 1.0
	sk.damping_max = 2.0
	sk.angle_min = 0.0
	sk.angle_max = 360.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 1.6))
	sk.scale_amount_curve = grow
	sk.emitting = true
	# 6. glowing embers that drift
	var em := mat(true, T["glow"], g, {"billboard": 1, "intensity": 4.0, "gradient_bias": 0.3, "erode_by_age": 0.8, "noise_in_value": 0.0})
	var eb := particles(root, at, em, Vector2(0.22, 0.22), int(30 * s), 1.6)
	eb.explosiveness = 0.8
	eb.spread = 180.0
	eb.initial_velocity_min = 1.0
	eb.initial_velocity_max = 3.5
	eb.damping_min = 2.5
	eb.damping_max = 4.0
	eb.gravity = Vector3(0.2, 0.5, 0)
	eb.scale_amount_min = 0.5
	eb.scale_amount_max = 1.5
	eb.emitting = true
	# 7. heat haze over the hit, scorch mark on the ground
	haze(root, at + Vector3(0, 0.3, 0.2), Vector2(2.2, 2.2) * s, 0.9)
	scorch(root, ground, 1.8 * s, 2.5)
	# 8. light the world (+shadows), dim the sun, shake
	var col: Color = (RAMPS.get(element, RAMPS["Fire"]) as Array)[3]
	KIT.impact_light(root, at + Vector3(0, 0.3, 0.6), col, 6.0 * s, 7.0, 0.55)
	KIT.dim_sun(root, 0.35 * s)
	KIT.shake(root, 1.0 * s)


static func haze(root: Node, at: Vector3, size: Vector2, life: float) -> void:
	var m := ShaderMaterial.new()
	m.shader = HAZE
	m.set_shader_parameter("noise_tex", T["cloud"])
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.global_position = at
	var tw := mi.create_tween()
	tw.tween_method(func(v): mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, life)
	tw.tween_callback(mi.queue_free)


static func scorch(root: Node, at: Vector3, size: float, life: float) -> void:
	var d := Decal.new()
	d.texture_albedo = _scorch_tex()
	d.modulate = Color(0.08, 0.05, 0.04, 0.75)
	d.size = Vector3(size, 1.0, size)
	d.cull_mask = 1
	root.add_child(d)
	d.global_position = at + Vector3(0, 0.3, 0)
	d.rotation.y = randf() * TAU
	var tw := d.create_tween()
	tw.tween_interval(life * 0.6)
	tw.tween_property(d, "modulate:a", 0.0, life * 0.4)
	tw.tween_callback(d.queue_free)


static var _scorch_cache: ImageTexture
static func _scorch_tex() -> Texture2D:
	# the scorch mask is grey-only: turn it into white + alpha for the decal
	if _scorch_cache:
		return _scorch_cache
	var img: Image = (T["scorch"] as Texture2D).get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var v := img.get_pixel(x, y).r
			img.set_pixel(x, y, Color(1, 1, 1, v))
	_scorch_cache = ImageTexture.create_from_image(img)
	return _scorch_cache


# ------------------------------------------------------------------ projectile
## Dress a flying spell: a hot glowing core and a soft trail.
static func dress_projectile(bolt: Node3D, element: String) -> void:
	var g := ramp(element)
	var core := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	core.mesh = q
	var m := mat(true, T["flare"], g, {"billboard": 1, "intensity": 4.0, "gradient_bias": 0.2, "noise_in_value": 0.0})
	core.material_override = m
	core.name = "HDCore"
	bolt.add_child(core)
	var tm := mat(true, T["glow"], g, {"billboard": 1, "intensity": 2.5, "erode_by_age": 1.0, "noise_in_value": 0.0, "is_particles": true})
	var tr := CPUParticles3D.new()
	var tq := QuadMesh.new()
	tq.size = Vector2(0.45, 0.45)
	tq.material = tm
	tr.mesh = tq
	tr.amount = 40
	tr.lifetime = 0.35
	tr.local_coords = false
	tr.gravity = Vector3.ZERO
	tr.initial_velocity_min = 0.0
	tr.initial_velocity_max = 0.3
	tr.spread = 180.0
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0.2))
	tr.scale_amount_curve = c
	tr.name = "HDTrail"
	bolt.add_child(tr)
