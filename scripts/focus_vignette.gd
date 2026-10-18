@tool
extends CanvasLayer
## FOCUS VIGNETTE — darkens the scene slightly everywhere except around the
## characters and monsters, so the eye goes to the fight.
## Drop focus_vignette.tscn into ANY scene. It finds the actors by itself:
##   1. everything listed in "Extra Targets", plus
##   2. every Sprite3D directly under the node named in "Actors Root" (default ../Actors).
## Adjust the look here in the Inspector. Press F5 to see it (it does not show in the 3D editor view).

@export var enabled := true:
	set(v):
		enabled = v
		_apply()
## Darkness of everything away from the actors. 0 = off.
@export_range(0.0, 1.0, 0.01) var strength := 0.35:
	set(v):
		strength = v
		_apply()
## Extra darkening in the four screen corners (classic vignette).
@export_range(0.0, 1.0, 0.01) var edge_strength := 0.2:
	set(v):
		edge_strength = v
		_apply()
## Colour of the shade (purple-blue looks like evening shadow, black looks harsh).
@export var shade_color := Color(0.05, 0.03, 0.1):
	set(v):
		shade_color = v
		_apply()
## Size of the clear area around each actor (1 = about the actor's own height).
@export_range(0.2, 3.0, 0.05) var focus_size := 1.0
## How gently the clear area fades into the shade.
@export_range(0.01, 2.0, 0.01) var softness := 0.6:
	set(v):
		softness = v
		_apply()
## Oval shape: below 1 = taller than wide, above 1 = wider than tall.
@export_range(0.3, 2.0, 0.05) var focus_width := 0.8
## Node whose Sprite3D children are the actors.
@export var actors_root := NodePath("../Actors")
## Any other nodes to keep lit (a boss, a treasure chest...).
@export var extra_targets: Array[NodePath] = []

@onready var _rect := $Shade as ColorRect


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	_rect.visible = enabled
	var m := _rect.material as ShaderMaterial
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("edge_strength", edge_strength)
	m.set_shader_parameter("shade_color", shade_color)
	m.set_shader_parameter("softness", softness)


func _targets() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var root := get_node_or_null(actors_root)
	if root:
		for c in root.get_children():
			if c is Sprite3D and (c as Sprite3D).visible:
				out.append(c)
	for p in extra_targets:
		var n := get_node_or_null(p) as Node3D
		if n and not out.has(n):
			out.append(n)
	return out


func _process(_delta: float) -> void:
	if not enabled:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var spots := PackedVector4Array()
	for t in _targets():
		if spots.size() >= 8:
			break
		var h := 1.8
		if t is Sprite3D:
			var s := t as Sprite3D
			if s.texture:
				h = float(s.texture.get_height()) / maxf(s.vframes, 1) * s.pixel_size * s.global_basis.get_scale().y
		var feet := t.global_position
		var head := feet + Vector3.UP * h
		if cam.is_position_behind(feet):
			continue
		var a := cam.unproject_position(feet) / vs
		var b := cam.unproject_position(head) / vs
		var screen_h := absf(a.y - b.y)
		var r := screen_h * 0.6 * focus_size
		spots.append(Vector4((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, r * focus_width, r))
	var n := spots.size()
	while spots.size() < 8:
		spots.append(Vector4.ZERO)
	var m := _rect.material as ShaderMaterial
	m.set_shader_parameter("spots", spots)
	m.set_shader_parameter("spot_count", n)
	m.set_shader_parameter("aspect", vs.x / maxf(vs.y, 1.0))
