@tool
extends Node3D
## ACTOR LOOK PANEL (week 3) — put on the "Actors" node.
## Controls how every character and monster under it is drawn:
## rim light from the sun, contact shadows under the feet, and a pixel-size check.
## Change the values in the Inspector; every actor updates at once.

const ACTOR_SHADER := preload("res://shaders/actor_pixel.gdshader")

@export_group("Rim light")
@export var rim_enabled := true:
	set(v):
		rim_enabled = v
		_apply()
## Colour of the bright edge (warm = sunset, cool = moonlight).
@export var rim_color := Color(1.0, 0.85, 0.6):
	set(v):
		rim_color = v
		_apply()
## Above ~1.5 the edge starts to glow (bloom).
@export_range(0.0, 4.0, 0.05) var rim_strength := 1.0:
	set(v):
		rim_strength = v
		_apply()
## How much the TOP edges light up compared to the sun side (0 = side only).
@export_range(0.0, 1.0, 0.05) var rim_top := 0.4:
	set(v):
		rim_top = v
		_apply()
## Edge thickness in picture pixels.
@export_range(1, 3, 1) var rim_width := 1:
	set(v):
		rim_width = v
		_apply()
## The edge follows the Sun node automatically. Turn off to set the side by hand.
@export var rim_follows_sun := true
## Used when "Rim Follows Sun" is off: x = right(+)/left(-), y = top(+)/bottom(-).
@export var rim_side := Vector2(1, 0.5)

@export_group("Shadows on actors")
## How dark shadows from trees, clouds and the sun get ON the characters, compared
## with the ground. 1 = same as the ground, 0.45 = clearly lighter, 0 = none.
@export_range(0.0, 1.0, 0.01) var shadow_on_actors := 0.45:
	set(v):
		shadow_on_actors = v
		_apply()

@export_group("Contact shadow")
## Darkness of the soft shadow blob under each actor's feet.
@export_range(0.0, 1.0, 0.01) var contact_darkness := 0.55:
	set(v):
		contact_darkness = v
		_apply()
## Size of the blob (1 = default).
@export_range(0.2, 3.0, 0.05) var contact_size := 1.0:
	set(v):
		contact_size = v
		_apply()

@export_group("Pixel rules")
## World units per art pixel. Every actor should share ONE size so pixels match.
@export var pixel_size := 0.03125:
	set(v):
		pixel_size = v
		_apply()
## Force every actor's Pixel Size to the value above.
@export var lock_pixel_size := true:
	set(v):
		lock_pixel_size = v
		_apply()

var _mats := {}


func _ready() -> void:
	_apply()
	child_entered_tree.connect(func(_n): _apply.call_deferred())


func _actors() -> Array[Sprite3D]:
	var out: Array[Sprite3D] = []
	for c in get_children():
		if c is Sprite3D:
			out.append(c)
	return out


func _apply() -> void:
	if not is_node_ready():
		return
	for s in _actors():
		if lock_pixel_size:
			s.pixel_size = pixel_size
		var key := s.texture.resource_path if s.texture else ""
		if not _mats.has(key):
			var m := ShaderMaterial.new()
			m.shader = ACTOR_SHADER
			m.set_shader_parameter("texture_albedo", s.texture)
			_mats[key] = m
		var m: ShaderMaterial = _mats[key]
		m.set_shader_parameter("rim_color", rim_color)
		m.set_shader_parameter("rim_strength", rim_strength if rim_enabled else 0.0)
		m.set_shader_parameter("rim_width", rim_width)
		m.set_shader_parameter("rim_top", rim_top)
		m.set_shader_parameter("actor_shadow", shadow_on_actors)
		s.material_override = m
		var cs := s.get_node_or_null("ContactShadow") as Decal
		if cs:
			cs.modulate.a = contact_darkness
			cs.size = Vector3(1.5, 1.0, 0.8) * Vector3(contact_size, 1.0, contact_size)
	_update_rim_dir()
	update_configuration_warnings()


func _process(_delta: float) -> void:
	_update_rim_dir()


func _update_rim_dir() -> void:
	var side := rim_side
	if rim_follows_sun:
		var sun: DirectionalLight3D = null
		for n in get_parent().get_children():
			if n is DirectionalLight3D:
				sun = n
				break
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		if sun and cam:
			var to_sun := sun.global_basis.z.normalized()   # light shines along -Z
			side = Vector2(to_sun.dot(cam.global_basis.x), to_sun.dot(cam.global_basis.y))
	for s in _actors():
		var x := side.x * (-1.0 if s.flip_h else 1.0)
		# picture y runs downward, so "top" is negative
		s.set_instance_shader_parameter("rim_dir", Vector2(x, -side.y))


func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	for s in _actors():
		var sc := s.scale
		if absf(sc.x - sc.y) > 0.01:
			w.append("%s: Scale x (%.2f) and y (%.2f) differ, so its pixels are stretched. Use the same value for both." % [s.name, sc.x, sc.y])
	return w
