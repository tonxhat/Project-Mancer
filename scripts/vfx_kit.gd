extends RefCounted
## VFX KIT (week 4) — the building blocks every spell uses when it lands:
## light flash with shadows, glowing ground patch, floating motes, sun dim,
## camera shake, and the two combo effects (lava pool, steam cloud).
## All functions are static: VfxKit.impact_light(root, ...) etc.

const SPARK := preload("res://art/spark.png")
const TEX := {
	"spark": preload("res://art/spark.png"),
	"drop": preload("res://art/vfx/drop.png"),
	"flake": preload("res://art/vfx/flake.png"),
	"puff": preload("res://art/vfx/puff.png"),
	"dot": preload("res://art/vfx/dot.png"),
}
const SPRITE_SHADER := preload("res://shaders/vfx_sprite.gdshader")
## Pixel-art hit sheets (12 frames in a row) from the Mancer prototype.
const HIT_SHEETS := ["Earth", "Water", "Air", "Fire", "Ice", "Lightning", "Magma", "Steam",
	"Sand", "Bio", "Explosion", "Time", "Weather", "Crystal", "Nether", "Death"]
## Per-sheet glow trim: white/pale effects bloom too much at the same glow.
const SHEET_GLOW := {"Steam": 0.35, "Air": 0.7, "Ice": 0.8, "Weather": 0.8, "Earth": 1.3, "Sand": 1.2}
const GROUND := preload("res://art/vfx/ground_glow.png")
## Emission must be black outside the glow, or the whole decal box lights up.
const GROUND_EMIT := preload("res://art/vfx/ground_glow_emit.png")


## Settings from the VFX node (or defaults if the scene has none).
static func cfg(tree: SceneTree, key: String, fallback: Variant) -> Variant:
	var n := tree.get_first_node_in_group("vfx_settings")
	if n == null:
		return fallback
	return n.get(key)


## A burst of light at the hit point: lights the target, the heroes and the ground,
## and (optionally) makes everything cast a shadow away from the explosion.
static func impact_light(root: Node, at: Vector3, col: Color, energy: float, rng: float, time: float) -> OmniLight3D:
	var t := root.get_tree()
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = rng
	l.omni_attenuation = 1.2
	l.shadow_enabled = cfg(t, "impact_shadows", true)
	l.light_energy = energy * float(cfg(t, "light_strength", 1.0))
	root.add_child(l)
	l.global_position = at
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)
	return l


## Glowing patch on the ground (lights the grass pixels, then fades).
static func ground_glow(root: Node, at: Vector3, col: Color, size: float, strength: float, time: float) -> Decal:
	if not cfg(root.get_tree(), "ground_glow", true):
		return null
	var d := Decal.new()
	d.texture_albedo = GROUND
	d.texture_emission = GROUND_EMIT
	d.modulate = Color(col.r, col.g, col.b, 0.9)
	d.emission_energy = strength
	d.albedo_mix = 0.15
	d.size = Vector3(size, 1.2, size * 0.7)
	d.cull_mask = 1   # ground and props only, not the characters (layer 2)
	root.add_child(d)
	d.global_position = Vector3(at.x, 0.3, at.z)
	var tw := d.create_tween()
	tw.tween_property(d, "emission_energy", 0.0, time).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(d, "modulate:a", 0.0, time).set_ease(Tween.EASE_IN)
	tw.tween_callback(d.queue_free)
	return d


## Glowing pixel material (brighter than white, so Glow blooms it).
static func glow_mat(tex: Texture2D, col: Color, glow: float, billboard := BaseMaterial3D.BILLBOARD_PARTICLES) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.albedo_color = Color(col.r * glow, col.g * glow, col.b * glow)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.billboard_mode = billboard
	m.disable_fog = true
	return m


## Pops to full size at once, then shrinks away — small sparks that vanish fast.
static func _pop_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(0.6, 0.8))
	c.add_point(Vector2(1.0, 0.0))
	return c


static func _fade_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(0.12, 1.0))
	c.add_point(Vector2(0.75, 0.9))
	c.add_point(Vector2(1.0, 0.0))
	return c


## Floating motes that hang in the air after a hit, with a soft light in the middle
## so they keep lighting the target and ground while they float.
static func motes(root: Node, at: Vector3, m: Dictionary, light_energy: float) -> void:
	var t := root.get_tree()
	var mult: float = cfg(t, "motes_amount", 1.0)
	var life: float = cfg(t, "motes_time", 2.6)
	if mult <= 0.0:
		return
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	var tex: Texture2D = TEX.get(m["tex"], SPARK)
	var px := 1.0 / 32.0
	q.size = Vector2(tex.get_width(), tex.get_height()) * px
	q.material = glow_mat(tex, m["color"], m["glow"])
	p.mesh = q
	p.amount = maxi(int(m["amount"] * mult), 1)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.scale_amount_curve = _pop_curve()
	p.lifetime_randomness = 0.4
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	match m["motion"]:
		"ember":
			p.direction = Vector3.UP
			p.spread = 35.0
			p.initial_velocity_min = 0.3
			p.initial_velocity_max = 1.0
			p.gravity = Vector3(0.15, 0.35, 0)
			p.damping_min = 0.4
			p.damping_max = 0.8
		"snow":
			p.direction = Vector3.UP
			p.spread = 80.0
			p.initial_velocity_min = 0.4
			p.initial_velocity_max = 1.2
			p.gravity = Vector3(0.1, -0.35, 0)
			p.damping_min = 1.2
			p.damping_max = 2.0
		"pop":
			p.direction = Vector3.UP
			p.spread = 180.0
			p.initial_velocity_min = 1.2
			p.initial_velocity_max = 2.6
			p.damping_min = 4.0
			p.damping_max = 6.0
			p.gravity = Vector3(0, -0.5, 0)
		"dust":
			p.direction = Vector3.UP
			p.spread = 90.0
			p.initial_velocity_min = 0.3
			p.initial_velocity_max = 1.0
			p.gravity = Vector3(0.12, -0.25, 0)
			p.damping_min = 1.0
			p.damping_max = 1.6
		"swirl":
			p.direction = Vector3.UP
			p.spread = 90.0
			p.initial_velocity_min = 0.4
			p.initial_velocity_max = 0.9
			p.gravity = Vector3.ZERO
			p.tangential_accel_min = 2.0
			p.tangential_accel_max = 3.0
			p.orbit_velocity_min = 0.0
		_:  # spark
			p.direction = Vector3.UP
			p.spread = 180.0
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 4.0
			p.gravity = Vector3.ZERO
			p.damping_min = 5.0
			p.damping_max = 7.0
			p.lifetime = life * 0.6
	root.add_child(p)
	p.global_position = at
	p.emitting = true
	t.create_timer(p.lifetime + 0.5).timeout.connect(p.queue_free)
	# the motes' own glow on the surroundings
	if light_energy > 0.0:
		var l := OmniLight3D.new()
		l.light_color = m["color"]
		l.omni_range = 2.2
		l.shadow_enabled = false
		l.light_energy = light_energy * float(cfg(t, "light_strength", 1.0))
		root.add_child(l)
		l.global_position = at + Vector3(0, 0.3, 0.3)
		var tw := l.create_tween()
		tw.tween_property(l, "light_energy", 0.0, p.lifetime).set_ease(Tween.EASE_IN)
		tw.tween_callback(l.queue_free)


## Pixel-art hit animation (12 frames) that faces the camera and glows.
## sheet = element name from HIT_SHEETS. size multiplies VFX → Sprite Size.
static func sprite_hit(root: Node, at: Vector3, sheet: String, size := 1.0) -> Sprite3D:
	var t := root.get_tree()
	if not sheet in HIT_SHEETS:
		sheet = "Explosion"
	var tex: Texture2D = load("res://art/vfx_sprite/hit_%s.png" % sheet)
	var sp := Sprite3D.new()
	sp.texture = tex
	sp.hframes = 12
	sp.pixel_size = (1.0 / 32.0) * float(cfg(t, "sprite_size", 0.9)) * size
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = SPRITE_SHADER
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("glow", float(cfg(t, "sprite_glow", 1.6)) * float(SHEET_GLOW.get(sheet, 1.0)))
	sp.material_override = m
	m.render_priority = 10
	root.add_child(sp)
	# a little in front of the target, and lifted so the bottom edge stays above the ground
	var half := float(tex.get_height()) * sp.pixel_size * 0.5
	sp.global_position = Vector3(at.x, maxf(at.y, half + 0.05), at.z + 0.6)
	var dur: float = cfg(t, "sprite_time", 1.1)
	var tw := sp.create_tween()
	tw.tween_property(sp, "frame", 11, dur).from(0)
	tw.tween_callback(sp.queue_free)
	return sp


## Dim the sun for a moment so the spell's light owns the scene.
static func dim_sun(root: Node, amount: float) -> void:
	var t := root.get_tree()
	amount *= float(cfg(t, "scene_dim", 1.0))
	if amount <= 0.0:
		return
	var sun: DirectionalLight3D = null
	for n in root.get_children():
		if n is DirectionalLight3D:
			sun = n
			break
	if sun == null:
		return
	if not sun.has_meta("base_energy"):
		sun.set_meta("base_energy", sun.light_energy)
	var base: float = sun.get_meta("base_energy")
	var low := base * clampf(1.0 - amount, 0.0, 1.0)
	if sun.has_meta("dim_tween"):
		var old: Tween = sun.get_meta("dim_tween")
		if old and old.is_valid():
			old.kill()
	var tw := sun.create_tween()
	tw.tween_property(sun, "light_energy", low, 0.08)
	tw.tween_interval(0.25)
	tw.tween_property(sun, "light_energy", base, float(cfg(t, "dim_recover", 1.2))).set_trans(Tween.TRANS_SINE)
	sun.set_meta("dim_tween", tw)


static func shake(root: Node, power: float) -> void:
	power *= float(cfg(root.get_tree(), "shake", 1.0))
	var cam := root.get_viewport().get_camera_3d()
	if cam == null or power <= 0.0:
		return
	var tw := cam.create_tween()
	for a in [0.06, -0.05, 0.035, -0.02, 0.0]:
		tw.tween_property(cam, "h_offset", a * power, 0.035)
	var tv := cam.create_tween()
	for a in [-0.03, 0.025, -0.012, 0.0]:
		tv.tween_property(cam, "v_offset", a * power, 0.04)


## A one-shot burst of glowing sparks.
static func burst(root: Node, at: Vector3, col: Color, glow: float, amount: int, speed: float, grav: float, size := 0.12, life := 0.55) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = glow_mat(SPARK, col, glow)
	p.mesh = q
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -grav, 0)
	p.damping_min = 1.0
	p.damping_max = 2.5
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = c
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	root.add_child(p)
	p.global_position = at
	p.emitting = true
	root.get_tree().create_timer(life + 0.6).timeout.connect(p.queue_free)
	return p


# ------------------------------------------------------------------ combos
## LAVA (Earth + Fire): the ground glows like a lava pool, a big pixel magma burst,
## small embers, and a flickering orange light holds the scene.
static func lava(root: Node, at: Vector3, c: Dictionary) -> void:
	var col: Color = c["color"]
	var linger: float = c["linger"]
	var ground := Vector3(at.x, 0.05, at.z)
	impact_light(root, at + Vector3(0, 0.4, 0.6), col, c["impact"], 8.0, 0.7)
	dim_sun(root, c["dim"])
	shake(root, 1.8)
	# pool: emissive decal that swells, then cools
	var pool := ground_glow(root, ground, col, 3.6, 6.0, linger)
	if pool:
		pool.scale = Vector3(0.3, 1, 0.3)
		pool.create_tween().tween_property(pool, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# pixel-art magma burst + small round embers that vanish fast
	sprite_hit(root, ground + Vector3(0, 1.0, 0), "Magma", 1.8)
	motes(root, ground + Vector3(0, 0.5, 0), {"color": col, "glow": 2.6, "motion": "ember", "amount": 20, "tex": "dot"}, 0.0)
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = 5.0
	l.shadow_enabled = cfg(root.get_tree(), "impact_shadows", true)
	root.add_child(l)
	l.global_position = ground + Vector3(0, 0.6, 0.4)
	var base := 4.0 * float(cfg(root.get_tree(), "light_strength", 1.0))
	var steps := int(linger / 0.08)
	var tw := l.create_tween()
	for i in steps:
		var k := 1.0 - float(i) / steps
		tw.tween_property(l, "light_energy", base * k * randf_range(0.7, 1.15), 0.08)
	tw.tween_callback(l.queue_free)


## STEAM (Water + Fire): a big pixel steam burst lit warm from inside by the fire.
static func steam(root: Node, at: Vector3, c: Dictionary) -> void:
	var col: Color = c["color"]
	var linger: float = c["linger"]
	impact_light(root, at + Vector3(0, 0.3, 0.6), Color(1.0, 0.75, 0.5), c["impact"], 7.0, 0.4)
	dim_sun(root, c["dim"])
	shake(root, 1.2)
	# pixel-art steam burst + small round sparks
	sprite_hit(root, at, "Steam", 1.8)
	motes(root, at, {"color": Color(0.9, 0.95, 1.0), "glow": 1.6, "motion": "pop", "amount": 16, "tex": "dot"}, 0.0)
	# warm glow inside the cloud, fading as it cools
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.72, 0.5)
	l.omni_range = 4.0
	l.light_energy = 1.4 * float(cfg(root.get_tree(), "light_strength", 1.0))
	root.add_child(l)
	l.global_position = at + Vector3(0, 0.4, 0.3)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, linger * 0.8).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)
