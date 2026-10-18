extends SceneTree
## Builds stages/<id>.tscn from tools/stages.json.
## Run: godot --headless --path . --script tools/build_stage.gd -- <id>
## (Only for creating a stage the first time. After that, arrange it by hand in Godot.)

func _init() -> void:
	var id: String = OS.get_cmdline_user_args()[0]
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/stages.json"))[id]
	var root := Node3D.new()
	root.name = id.capitalize()
	root.set_script(load("res://scripts/stage_preset.gd"))
	for k in cfg["preset"]:
		var v = cfg["preset"][k]
		if v is Array:
			v = Color(v[0], v[1], v[2])
		root.set(k, v)
	var art := "res://art/stages/%s/" % id

	# ground + path
	var g := _plane(root, "Ground", Vector2(60, 60), Vector3(0, 0, -15))
	var gm := StandardMaterial3D.new()
	var gt: Texture2D = load(art + "ground.png")
	gm.albedo_texture = gt
	var gu: float = cfg.get("ground_uv", 60.0 * 32.0 / gt.get_width())   # 32 texture pixels per metre, like Verdant Field
	gm.uv1_scale = Vector3(gu, gu, 1)
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	gm.roughness = 1.0
	g.material_override = gm
	var pm := StandardMaterial3D.new()
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	pm.alpha_scissor_threshold = 0.5
	# one wide lane (as wide as the old two lanes together), pixels stay 32 per metre
	var pfile := art + ("path_wide.png" if ResourceLoader.exists(art + "path_wide.png") else "path.png")
	var pt: Texture2D = load(pfile)
	pm.albedo_texture = pt
	pm.uv1_scale = Vector3(40.0 * 32.0 / pt.get_width(), 1, 1)
	var path_h := pt.get_height() / 32.0
	pm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	var pi := _plane(root, "Path", Vector2(40, path_h), Vector3(0, 0.003, 0.2))
	pi.material_override = pm
	pi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# backdrop panoramas (same placement as Verdant Field)
	var bd := Node3D.new(); bd.name = "Backdrop"; root.add_child(bd); bd.owner = root
	for b in [["Sky", "sky.png", Vector2(270, 30), Vector3(0, 16.1, -70), true],
			["Far", "far.png", Vector2(103.5, 11.5), Vector3(0, 3.12, -42), false],
			["Hor", "hor.png", Vector2(57.6, 6.4), Vector3(0, 1.92, -20), false]]:
		var mi := MeshInstance3D.new()
		mi.name = b[0]
		var q := QuadMesh.new(); q.size = b[2]; mi.mesh = q
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.disable_fog = b[4]
		m.albedo_texture = load(art + b[1])
		m.uv1_scale = Vector3(3, 1, 1)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bd.add_child(mi); mi.owner = root
		mi.position = b[3]

	# props
	var props := Node3D.new(); props.name = "Props"; root.add_child(props); props.owner = root
	var rm := StandardMaterial3D.new()
	rm.albedo_texture = load(art + "rock.png")
	rm.roughness = 0.95
	rm.uv1_scale = Vector3(0.205, 0.205, 0.205)
	rm.uv1_triplanar = true
	rm.uv1_world_triplanar = true
	rm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	for r in cfg.get("rocks", []):
		var mi := MeshInstance3D.new()
		mi.name = r["name"]
		var bx := BoxMesh.new(); bx.size = Vector3(r["size"][0], r["size"][1], r["size"][2]); mi.mesh = bx
		mi.material_override = rm
		props.add_child(mi); mi.owner = root
		mi.position = Vector3(r["pos"][0], r["size"][1] * 0.5 + r["pos"][1], r["pos"][2])
		mi.rotation_degrees = Vector3(r.get("rx", 0.0), r.get("ry", 0.0), r.get("rz", 0.0))
	for s in cfg.get("sprites", []):
		var sp := Sprite3D.new()
		sp.name = s["name"]
		var tex: Texture2D = load(art + s["tex"])
		sp.texture = tex
		sp.centered = false
		sp.offset = Vector2(-tex.get_width() * 0.5, 0)
		sp.pixel_size = s.get("px", 0.0625)
		sp.shaded = true
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		props.add_child(sp); sp.owner = root
		sp.position = Vector3(s["pos"][0], s["pos"][1], s["pos"][2])
		var sc: Array = s.get("scale", [1, 1])
		sp.scale = Vector3(sc[0], sc[1], 1)
		if s.has("tint"):
			sp.modulate = Color(s["tint"][0], s["tint"][1], s["tint"][2])
		if s.get("sway", 0.0) > 0.0:
			sp.set_meta("sway", s["sway"])
	for l in cfg.get("lights", []):
		var ol := OmniLight3D.new()
		ol.name = l["name"]
		ol.light_color = Color(l["color"][0], l["color"][1], l["color"][2])
		ol.light_energy = l["energy"]
		ol.omni_range = l["range"]
		ol.shadow_enabled = false
		if l.get("flicker", 0.0) > 0.0:
			ol.set_script(load("res://scripts/flicker_light.gd"))
			ol.set("flicker", l["flicker"])
		root.add_child(ol); ol.owner = root
		ol.position = Vector3(l["pos"][0], l["pos"][1], l["pos"][2])

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://stages/%s.tscn" % id)
	print("saved stage ", id, " err=", err)
	quit()


func _plane(root: Node, n: String, size: Vector2, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var pl := PlaneMesh.new(); pl.size = size; mi.mesh = pl
	root.add_child(mi); mi.owner = root
	mi.position = pos
	return mi
