extends SceneTree
## Builds res://main.tscn from code. Run once:
##   godot --headless --path . --script res://tools/build_scene.gd
## After that, edit main.tscn in the editor as normal (this script is only a starting point).

const PX := 1.0 / 32.0  # world units per sprite pixel: 32 px = 1 unit, same for every actor

var scene_root: Node3D


func _init() -> void:
	scene_root = Node3D.new()
	scene_root.name = "Look"
	scene_root.set_script(load("res://scripts/look.gd"))

	_environment()
	_sun()
	_camera()
	_ground()
	_backdrop()
	_props()
	_actors()
	_tilt_shift()

	_own(scene_root)
	var ps := PackedScene.new()
	var err := ps.pack(scene_root)
	if err == OK:
		err = ResourceSaver.save(ps, "res://main.tscn")
	print("build_scene: ", "OK" if err == OK else "ERROR %d" % err)
	quit()


func _own(n: Node) -> void:
	for c in n.get_children():
		c.owner = scene_root
		_own(c)


func _add(parent: Node, child: Node, nm: String) -> Node:
	child.name = nm
	parent.add_child(child)
	return child


func _tex(path: String) -> Texture2D:
	return load(path) as Texture2D


# ---------------------------------------------------------------- environment
func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.96, 0.66, 0.5)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_sky_affect = 0.0
	we.environment = env
	_add(scene_root, we, "WorldEnvironment")


func _sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 40.0
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	_add(scene_root, sun, "Sun")


func _camera() -> void:
	var cam := Camera3D.new()
	cam.attributes = CameraAttributesPractical.new()
	cam.current = true
	cam.far = 200.0
	_add(scene_root, cam, "Camera3D")


# ---------------------------------------------------------------- world
func _pixel_mat(tex: Texture2D, shaded: bool, fog := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not shaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = not fog
	return m


func _ground() -> void:
	var tex := _tex("res://art/grass.png")
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	# nearest + mipmaps: crisp up close, no shimmering stripes far away
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = 1.0
	# keep 32 px per world unit, like the characters
	m.uv1_scale = Vector3(60.0 / (tex.get_width() * PX), 60.0 / (tex.get_height() * PX), 1)
	mi.material_override = m
	mi.position = Vector3(0, 0, -15)
	_add(scene_root, mi, "Ground")

	# dirt path across the battlefield: two overlapping strips
	var dtex := _tex("res://art/dirt.png")
	var dm := StandardMaterial3D.new()
	dm.albedo_texture = dtex
	dm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	dm.alpha_scissor_threshold = 0.5
	dm.roughness = 1.0
	var depth := dtex.get_height() * PX
	dm.uv1_scale = Vector3(40.0 / (dtex.get_width() * PX), 1, 1)
	var zs := [0.95, -0.55]
	for i in zs.size():
		var strip := MeshInstance3D.new()
		var sp := PlaneMesh.new()
		sp.size = Vector2(40, depth)
		strip.mesh = sp
		strip.material_override = dm
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		strip.position = Vector3(0, 0.003 * (i + 1), zs[i])
		_add(scene_root, strip, "DirtPath%d" % (i + 1))


func _backdrop() -> void:
	var bd := _add(scene_root, Node3D.new(), "Backdrop")
	# name, texture, z, bottom y, world width, fog
	_flat_layer(bd, "Sky", "res://art/bg_sky.png", -70.0, -24.0, 62.0, false)
	_flat_layer(bd, "Mountains", "res://art/bg_far.png", -42.0, -1.2, 44.0, true)
	_flat_layer(bd, "TreeLine", "res://art/bg_hor.png", -20.0, -0.2, 22.0, true)


func _flat_layer(parent: Node, nm: String, path: String, z: float, bottom: float, width: float, fog: bool) -> void:
	var tex := _tex(path)
	var h := width * tex.get_height() / tex.get_width()
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, h)
	mi.mesh = q
	mi.material_override = _pixel_mat(tex, false, fog)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, bottom + h * 0.5, z)
	_add(parent, mi, nm)


func _props() -> void:
	var props := _add(scene_root, Node3D.new(), "Props")
	var rock := StandardMaterial3D.new()
	rock.albedo_texture = _tex("res://art/rock.png")
	rock.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	rock.uv1_triplanar = true
	rock.uv1_world_triplanar = true
	rock.uv1_scale = Vector3.ONE  # one 32 px tile per world unit
	rock.roughness = 0.95

	# name, size, position, y rotation, z tilt
	var boxes := [
		["RockA", Vector3(1.3, 0.7, 1.0), Vector3(3.7, 0.35, -2.4), 25.0, 0.0],
		["RockB", Vector3(1.0, 0.5, 0.9), Vector3(-3.9, 0.25, -2.8), -15.0, 0.0],
		["RockC", Vector3(0.6, 0.35, 0.6), Vector3(0.7, 0.17, -4.6), 40.0, 0.0],
		["RockD", Vector3(0.9, 0.55, 0.8), Vector3(4.1, 0.27, 2.2), 10.0, 0.0],
		["RuinPillarA", Vector3(0.8, 2.8, 0.8), Vector3(-4.6, 1.4, -5.5), 12.0, 0.0],
		["RuinPillarB", Vector3(0.8, 1.9, 0.8), Vector3(5.0, 0.9, -6.5), -20.0, 8.0],
	]
	for b in boxes:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = b[1]
		mi.mesh = bm
		mi.material_override = rock
		mi.position = b[2]
		mi.rotation_degrees = Vector3(0, b[3], b[4])
		_add(props, mi, b[0])

	# standing pixel sprites that catch light and cast shadows (placeholder art)
	_standee(props, "TreeA", "res://art/tree_a.png", Vector3(-6.0, 0, -9.0), 2.2)
	_standee(props, "TreeB", "res://art/tree_b.png", Vector3(6.2, 0, -10.0), 2.4)
	_standee(props, "TreeC", "res://art/tree_a.png", Vector3(2.4, 0, -12.5), 2.0)
	_standee(props, "BushA", "res://art/grass_a.png", Vector3(-3.0, 0, 3.4), 1.0)
	_standee(props, "BushB", "res://art/grass_b.png", Vector3(3.2, 0, 4.2), 1.0)
	_standee(props, "BushC", "res://art/grass_a.png", Vector3(0.4, 0, 6.0), 1.0)


func _standee(parent: Node, nm: String, path: String, pos: Vector3, scale_mult: float) -> void:
	var s := Sprite3D.new()
	s.texture = _tex(path)
	s.pixel_size = PX * scale_mult
	s.centered = false
	s.offset = Vector2(-s.texture.get_width() * 0.5, 0)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.double_sided = true
	s.position = pos
	_add(parent, s, nm)


# ---------------------------------------------------------------- characters
func _actors() -> void:
	var actors := _add(scene_root, Node3D.new(), "Actors")
	var t := _actor(actors, "Terramancer", "res://art/hero_Earth.png", 6, 3, 33, 72, Vector3(-1.55, 0, 0.75), 0, false)
	var p := _actor(actors, "Pyromancer", "res://art/hero_Fire.png", 6, 3, 31, 68, Vector3(-0.75, 0, -1.15), 0, false)
	var m := _actor(actors, "MagmaBeast", "res://art/mon_magma.png", 10, 1, 40, 76, Vector3(1.75, 0, -0.05), 0, true)
	m.set("frames_in_row", 6)
	m.set("fps", 7.0)
	p.set("fps", 7.0)

	# body lights (aura) by element: Earth has none, Fire and Magma glow on their own
	_aura(t, "Earth", Vector3(0.3, 1.0, 0.45))
	_aura(p, "Fire", Vector3(0.45, 1.0, 0.45))
	_aura(m, "Magma", Vector3(0.0, 0.9, 0.7))

	# spell casters: charge light, glowing spell, impact flash
	_caster(t, "Earth", Vector3(0.75, 0.75, 0.25), Vector3(0.95, 1.1, 0.25))
	_caster(p, "Fire", Vector3(0.7, 0.72, 0.25), Vector3(0.9, 1.1, 0.25))

	# demo loop: heroes take turns casting so the lights can be watched
	var demo := Node.new()
	demo.set_script(load("res://scripts/battle_demo.gd"))
	_add(scene_root, demo, "BattleDemo")
	var paths: Array[NodePath] = [NodePath("../Actors/Terramancer/SpellCaster"), NodePath("../Actors/Pyromancer/SpellCaster")]
	demo.set("casters", paths)


func _aura(actor: Node, element: String, at: Vector3) -> void:
	var l := OmniLight3D.new()
	l.set_script(load("res://scripts/element_light.gd"))
	l.position = at
	_add(actor, l, "Aura")
	l.set("element", element)


func _caster(actor: Node, element: String, charge_hand: Vector3, release_hand: Vector3) -> void:
	var c := Node3D.new()
	c.set_script(load("res://scripts/spell_caster.gd"))
	_add(actor, c, "SpellCaster")
	c.set("element", element)
	c.set("target", NodePath("../../MagmaBeast"))
	c.set("charge_hand", charge_hand)
	c.set("release_hand", release_hand)


func _actor(parent: Node, nm: String, path: String, hf: int, vf: int, fx: int, fy: int, pos: Vector3, row: int, flip: bool) -> Sprite3D:
	var s := Sprite3D.new()
	s.set_script(load("res://scripts/pixel_actor.gd"))
	s.texture = _tex(path)
	s.hframes = hf
	s.vframes = vf
	s.pixel_size = PX
	s.flip_h = flip
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.double_sided = true
	s.layers = 2  # keeps the blob shadow decal off the sprite itself
	s.set("row", row)
	s.set("feet_x", fx)
	s.set("feet_y", fy)
	s.position = pos
	_add(parent, s, nm)

	# soft contact shadow under the feet so nobody floats
	var d := Decal.new()
	d.texture_albedo = _tex("res://art/blob.png")
	d.modulate = Color(0.1, 0.08, 0.16, 0.55)
	d.size = Vector3(1.5, 1.0, 0.8)
	d.cull_mask = 1
	_add(s, d, "ContactShadow")
	return s


# ---------------------------------------------------------------- lens
func _tilt_shift() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1  # above the 3D world; game UI goes on higher layers later
	_add(scene_root, layer, "TiltShift")
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/tilt_shift.gdshader")
	rect.material = sm
	_add(layer, rect, "Blur")
