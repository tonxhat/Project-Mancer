extends SceneTree
## One-time: adds the week-2 Atmosphere node to the existing res://main.tscn,
## keeping every position and colour already in the scene.
##   godot --headless --path . --script res://tools/add_week2.gd

const PX := 1.0 / 32.0


func _init() -> void:
	var ps := load("res://main.tscn") as PackedScene
	var root := ps.instantiate()
	if root.get_node_or_null("Atmosphere"):
		root.get_node("Atmosphere").free()

	var atm := Node3D.new()
	atm.name = "Atmosphere"
	atm.set_script(load("res://scripts/atmosphere.gd"))
	root.add_child(atm)

	_dust(atm)
	_shafts(atm, root.get_node("Sun") as DirectionalLight3D)
	_clouds(atm)

	var bushes: Array[NodePath] = []
	var trees: Array[NodePath] = []
	for n in root.get_node("Props").get_children():
		if n is Sprite3D:
			if String(n.name).begins_with("Tree"):
				trees.append(NodePath("../Props/" + n.name))
			else:
				bushes.append(NodePath("../Props/" + n.name))
	atm.set("bushes", bushes)
	atm.set("trees", trees)

	_own(atm, root)
	var out := PackedScene.new()
	var err := out.pack(root)
	if err == OK:
		err = ResourceSaver.save(out, "res://main.tscn")
	print("add_week2: ", "OK" if err == OK else "ERROR %d" % err, "  bushes=", bushes.size(), " trees=", trees.size())
	root.free()
	quit()


func _own(n: Node, owner_node: Node) -> void:
	n.owner = owner_node
	for c in n.get_children():
		_own(c, owner_node)


func _dust(parent: Node) -> void:
	var p := CPUParticles3D.new()
	p.name = "Dust"
	var q := QuadMesh.new()
	q.size = Vector2(1.5 * PX, 1.5 * PX)  # tiny specks
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(1.2, 0.95, 0.6)
	q.material = m
	p.mesh = q
	p.amount = 40
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(5.5, 1.4, 3.0)
	p.direction = Vector3(1.0, 0.25, 0.0)
	p.spread = 55.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.18
	p.gravity = Vector3(0.0, 0.015, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var c := Curve.new()  # fade in, hold, fade out
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(0.15, 1.0))
	c.add_point(Vector2(0.8, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = c
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0.0, 1.5, -0.5)
	parent.add_child(p)


func _shafts(parent: Node, sun: DirectionalLight3D) -> void:
	var g := Node3D.new()
	g.name = "LightShafts"
	parent.add_child(g)
	# beams run back up toward the sun
	var up := sun.transform.basis.z.normalized()  # Sun sits directly under the root
	var toward_cam := Vector3(0, 0, 1)
	var n := (toward_cam - up * up.dot(toward_cam)).normalized()
	var x := up.cross(n).normalized()
	var basis := Basis(x, up, n)
	var shader := load("res://shaders/light_shaft.gdshader")
	# name, centre, width, length, seed
	var beams := [
		["ShaftA", Vector3(1.4, 3.4, -5.0), 2.0, 6.0, 0.0],
		["ShaftB", Vector3(4.0, 3.6, -7.0), 1.5, 6.5, 1.0],
		["ShaftC", Vector3(-2.2, 3.2, -6.5), 1.2, 5.5, 2.0],
	]
	for b in beams:
		var mi := MeshInstance3D.new()
		mi.name = b[0]
		var q := QuadMesh.new()
		q.size = Vector2(b[2], b[3])
		mi.mesh = q
		var sm := ShaderMaterial.new()
		sm.shader = shader
		mi.material_override = sm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.transform = Transform3D(basis, b[1])
		g.add_child(mi)
		mi.set_instance_shader_parameter("seed", b[4])


func _clouds(parent: Node) -> void:
	var g := Node3D.new()
	g.name = "CloudShadows"
	g.position = Vector3(0.0, 4.0, -5.0)
	parent.add_child(g)
	var tex := load("res://art/cloud_shadow.png")
	for nm in ["A", "B"]:
		var d := Decal.new()
		d.name = nm
		d.size = Vector3(26.0, 10.0, 26.0)
		d.texture_albedo = tex
		d.modulate = Color(0.12, 0.1, 0.22, 0.45)
		d.cull_mask = 1  # ground and props; characters stay clean
		d.upper_fade = 0.05
		d.lower_fade = 0.05
		g.add_child(d)
