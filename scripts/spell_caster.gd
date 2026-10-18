extends Node3D
## SPELL CASTER — put this under a hero (pixel_actor). Call cast() to play:
##   1. charge: charge pose, light grows at the hands, sparks gather
##   2. release: attack pose, short flash at the hand
##   3. travel: a glowing spell flies to the target, lighting the ground under it
##   4. impact: big flash of the element's colour, burst of sparks, target flashes and shakes
## Colours and brightness per element live in scripts/elements.gd.

const EL := preload("res://scripts/elements.gd")
const KIT := preload("res://scripts/vfx_kit.gd")
const HD := preload("res://scripts/vfx_hd.gd")
const SPARK := preload("res://art/spark.png")

@export_enum("Earth", "Water", "Air", "Fire", "Lightning", "Ice", "Magma") var element := "Fire"
## The character this spell hits (a pixel_actor).
@export var target: NodePath
## Where the hands are while charging, from the feet (x = forward, y = up, z = toward camera).
@export var charge_hand := Vector3(0.7, 0.75, 0.25)
## Where the casting hand is at the moment of release.
@export var release_hand := Vector3(0.9, 1.1, 0.25)
## Height on the target where the spell lands.
@export var target_height := 0.75

@export_group("Timing")
@export var charge_time := 0.8
@export var charge_row := 2
@export var release_row := 1
@export var release_fps := 12.0
## Frame of the release row where the hand thrusts forward (counting from 0).
@export var release_frame := 3
@export var travel_time := 0.32
## How high the spell arcs on its way (0 = straight line).
@export var arc := 0.35

var _busy := false


func cast() -> void:
	if _busy:
		return
	var to: Vector3 = await cast_part()
	var sp: Dictionary = EL.spell(element)
	var tgt := get_node_or_null(target) as Node3D
	_impact(to, sp["color"], sp)
	if tgt and tgt.has_method("hit"):
		tgt.call("hit", sp["color"])


## Charge, release and fly — everything except the impact. Returns where the spell landed.
## Used by cast() and by combo_caster.gd (two spells meet, then the combo explodes).
func cast_part() -> Vector3:
	_busy = true
	var actor := get_parent()
	var sp: Dictionary = EL.spell(element)
	var col: Color = sp["color"]

	# 1 — charge
	actor.call("play_row", charge_row, 10.0, false)
	var hand := _light(col, 0.0, 3.2)
	hand.position = charge_hand
	add_child(hand)
	var gather := _sparks(col, sp["glow"], 14, 0.45, false)
	gather.position = charge_hand
	add_child(gather)
	gather.emitting = true
	var tw := create_tween()
	tw.tween_property(hand, "light_energy", float(sp["charge"]), charge_time).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(charge_time).timeout

	# 2 — release
	gather.emitting = false
	actor.call("play_row", release_row, release_fps, true)
	await get_tree().create_timer(release_frame / release_fps).timeout
	hand.position = release_hand
	hand.light_energy = float(sp["charge"]) * 2.2
	var fade := create_tween()
	fade.tween_property(hand, "light_energy", 0.0, 0.22)
	fade.tween_callback(hand.queue_free)
	_free_later(gather, 1.0)

	# 3 — travel
	var tgt := get_node_or_null(target) as Node3D
	var from := (actor as Node3D).global_position + release_hand
	var to := from + Vector3(3.0, 0.0, 0.0)
	if tgt:
		to = tgt.global_position + Vector3(0.0, target_height, 0.3)
	var bolt := _projectile(col, sp)
	if KIT.cfg(get_tree(), "style", "Sprite") == "HD":
		bolt.get_node("Core").visible = element == "Earth"   # earth keeps its real rock
		bolt.get_node("Trail").visible = false
		HD.dress_projectile(bolt, element)
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = from
	(bolt.get_node("Trail") as CPUParticles3D).emitting = true
	if bolt.has_node("HDTrail"):
		(bolt.get_node("HDTrail") as CPUParticles3D).emitting = true
	var steps := 12
	for i in steps:
		var k := float(i + 1) / steps
		var p := from.lerp(to, k) + Vector3.UP * sin(k * PI) * arc
		var mv := bolt.create_tween()
		mv.tween_property(bolt, "global_position", p, travel_time / steps)
		await mv.finished

	# arrived: hide the flying spell (the impact is played by whoever called this)
	var trail := bolt.get_node("Trail") as CPUParticles3D
	trail.emitting = false
	bolt.get_node("Core").visible = false
	bolt.get_node("Light").visible = false
	if bolt.has_node("HDCore"):
		bolt.get_node("HDCore").visible = false
		(bolt.get_node("HDTrail") as CPUParticles3D).emitting = false
	_free_later(bolt, 0.6)
	_busy = false
	return to


# ------------------------------------------------------------------ pieces
func _light(col: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	return l


## Material that is brighter than white (HDR), so the Glow effect makes it bloom.
func _glow_mat(col: Color, glow: float) -> StandardMaterial3D:
	glow *= float(KIT.cfg(get_tree(), "spell_glow", 1.0))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = SPARK
	m.albedo_color = Color(col.r * glow, col.g * glow, col.b * glow)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.disable_fog = true
	return m


func _sparks(col: Color, glow: float, amount: int, life: float, burst: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.2, 0.2)
	q.material = _glow_mat(col, glow)
	p.mesh = q
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.one_shot = burst
	p.explosiveness = 1.0 if burst else 0.0
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	if burst:
		p.direction = Vector3.UP
		p.spread = 180.0
		p.initial_velocity_min = 1.5
		p.initial_velocity_max = 4.0
		p.gravity = Vector3(0, -5.0, 0)
		p.damping_min = 2.0
		p.damping_max = 4.0
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.4
	else:
		# gather: sparks drift inward/up around the hand
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.45
		p.direction = Vector3.UP
		p.spread = 30.0
		p.initial_velocity_min = 0.2
		p.initial_velocity_max = 0.6
		p.gravity = Vector3.ZERO
		p.radial_accel_min = -3.0
		p.radial_accel_max = -2.0
		p.scale_amount_min = 0.4
		p.scale_amount_max = 0.8
	return p


func _projectile(col: Color, sp: Dictionary) -> Node3D:
	var bolt := Node3D.new()
	bolt.name = "Spell_" + element
	var core := MeshInstance3D.new()
	core.name = "Core"
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if element == "Earth":
		# earth: a real rock chunk that catches the sun, wrapped in amber dust
		var b := BoxMesh.new()
		b.size = Vector3(0.34, 0.3, 0.3)
		var rock := StandardMaterial3D.new()
		rock.albedo_texture = load("res://art/rock.png")
		rock.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		rock.uv1_scale = Vector3(0.35, 0.35, 0.35)
		b.material = rock
		core.mesh = b
		var spin := core.create_tween().set_loops()
		spin.tween_property(core, "rotation", Vector3(TAU, TAU * 0.6, 0.0), 0.4).from(Vector3.ZERO)
	else:
		var q := QuadMesh.new()
		q.size = Vector2(0.45, 0.45)
		var m := _glow_mat(col, sp["glow"])
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		q.material = m
		core.mesh = q
	bolt.add_child(core)
	var l := _light(col, sp["travel"], 3.6)
	l.name = "Light"
	bolt.add_child(l)
	var trail := _sparks(col, sp["glow"] * 0.7, 26, 0.3, false)
	trail.name = "Trail"
	trail.emission_sphere_radius = 0.08
	trail.radial_accel_min = 0.0
	trail.radial_accel_max = 0.0
	bolt.add_child(trail)  # starts emitting once the spell is in the scene
	return bolt


func _impact(at: Vector3, col: Color, sp: Dictionary) -> void:
	# 4 — impact: flash that lights everything (and casts shadows), sparks,
	# glowing ground, floating motes, sun dips, camera shakes
	var root := get_tree().current_scene
	var style: String = KIT.cfg(get_tree(), "style", "Sprite")
	if style == "HD":
		HD.impact(root, at, element, float(KIT.cfg(get_tree(), "hd_size", 1.0)))
		return
	if style == "Sprite":
		# pixel-art hit animation of this element + light, ground glow, small round sparks
		KIT.impact_light(root, at + Vector3(0, 0.2, 0.5), col, sp["impact"], 6.5, 0.7)
		KIT.sprite_hit(root, at, element, 1.0)
		KIT.ground_glow(root, at, col, 2.2, 3.0, 1.0)
		KIT.motes(root, at, EL.motes(element), 0.8)
		KIT.dim_sun(root, sp.get("dim", 0.2))
		KIT.shake(root, 1.0)
		return
	KIT.impact_light(root, at + Vector3(0, 0.2, 0.5), col, sp["impact"], 6.5, 0.5)
	KIT.burst(root, at, col, minf(sp["glow"], 2.2), 28, 4.0, 5.0)
	KIT.ground_glow(root, at, col, 2.2, 3.0, 1.0)
	KIT.motes(root, at, EL.motes(element), 1.2)
	KIT.dim_sun(root, sp.get("dim", 0.2))
	KIT.shake(root, 1.0)


func _shake_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var tw := cam.create_tween()
	for a in [0.06, -0.05, 0.035, -0.02, 0.0]:
		tw.tween_property(cam, "h_offset", a, 0.035)


func _free_later(n: Node, t: float) -> void:
	get_tree().create_timer(t).timeout.connect(n.queue_free)
