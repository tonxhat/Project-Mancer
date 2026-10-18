@tool
extends Node3D
## ATMOSPHERE CONTROL PANEL (week 2)
## Select the node "Atmosphere" and change these values in the Inspector.
## Wind moves the bushes and trees listed below; dust, light shafts and cloud
## shadows are children of this node (move them in the 3D view if you like).

const WIND_SHADER := preload("res://shaders/wind_sway.gdshader")

@export_group("Wind")
@export var wind_enabled := true:
	set(v):
		wind_enabled = v
		_apply()
@export_range(0.0, 3.0, 0.05) var wind_strength := 1.0:
	set(v):
		wind_strength = v
		_apply()
@export_range(0.0, 3.0, 0.05) var wind_speed := 1.0:
	set(v):
		wind_speed = v
		_apply()
## Small plants: how far the top leans, in world units.
@export_range(0.0, 0.6, 0.01) var bush_sway := 0.16:
	set(v):
		bush_sway = v
		_apply()
## Trees lean less than grass.
@export_range(0.0, 0.6, 0.01) var tree_sway := 0.08:
	set(v):
		tree_sway = v
		_apply()
## Plants that sway a lot (bushes, grass tufts).
@export var bushes: Array[NodePath] = []:
	set(v):
		bushes = v
		_apply()
## Plants that sway a little (trees).
@export var trees: Array[NodePath] = []:
	set(v):
		trees = v
		_apply()

@export_group("Dust in the sunlight")
@export var dust_enabled := true:
	set(v):
		dust_enabled = v
		_apply()
@export_range(0, 300, 1) var dust_amount := 40:
	set(v):
		dust_amount = v
		_apply()
## Above 1 the specks glow.
@export_range(0.0, 4.0, 0.05) var dust_brightness := 1.2:
	set(v):
		dust_brightness = v
		_apply()
@export var dust_color := Color(1.0, 0.8, 0.5):
	set(v):
		dust_color = v
		_apply()

@export_group("Light shafts")
@export var shafts_enabled := true:
	set(v):
		shafts_enabled = v
		_apply()
@export_range(0.0, 1.5, 0.01) var shaft_intensity := 0.45:
	set(v):
		shaft_intensity = v
		_apply()
@export var shaft_color := Color(1.0, 0.82, 0.55):
	set(v):
		shaft_color = v
		_apply()

@export_group("Cloud shadows")
@export var clouds_enabled := true:
	set(v):
		clouds_enabled = v
		_apply()
## How dark the passing cloud shadows are. CHANGE IT HERE, not on the A/B decals:
## this panel rewrites the decals every time the scene opens.
@export_range(0.0, 1.0, 0.01) var cloud_darkness := 0.86:
	set(v):
		cloud_darkness = v
		_apply()
## Colour of the cloud shadow (darker / bluer = deeper shade).
@export var cloud_color := Color(0.12, 0.1, 0.22):
	set(v):
		cloud_color = v
		_apply()
## World units per second across the ground.
@export_range(0.0, 3.0, 0.01) var cloud_speed := 0.35

var _cloud_x := 0.0


func _ready() -> void:
	_apply()


func _process(delta: float) -> void:
	# cloud shadows drift with the wind; two decals leapfrog so there is never a gap
	var a := get_node_or_null("CloudShadows/A") as Decal
	var b := get_node_or_null("CloudShadows/B") as Decal
	if a == null or b == null or not clouds_enabled:
		return
	var w := a.size.x
	_cloud_x = fposmod(_cloud_x + delta * cloud_speed * maxf(wind_speed, 0.2), w)
	a.position.x = _cloud_x          # A and B together always cover -w/2 .. +w/2
	b.position.x = _cloud_x - w


func _apply() -> void:
	if not is_node_ready():
		return
	_apply_wind()

	var dust := get_node_or_null("Dust") as CPUParticles3D
	if dust:
		dust.visible = dust_enabled
		dust.emitting = dust_enabled
		if dust.amount != maxi(dust_amount, 1):
			dust.amount = maxi(dust_amount, 1)
		var q := dust.mesh as QuadMesh
		if q and q.material is StandardMaterial3D:
			var m := q.material as StandardMaterial3D
			m.albedo_color = Color(dust_color.r * dust_brightness, dust_color.g * dust_brightness, dust_color.b * dust_brightness)

	var shafts := get_node_or_null("LightShafts") as Node3D
	if shafts:
		shafts.visible = shafts_enabled
		for s in shafts.get_children():
			var mi := s as MeshInstance3D
			if mi and mi.material_override is ShaderMaterial:
				var sm := mi.material_override as ShaderMaterial
				sm.set_shader_parameter("intensity", shaft_intensity)
				sm.set_shader_parameter("beam_color", shaft_color)

	var clouds := get_node_or_null("CloudShadows") as Node3D
	if clouds:
		clouds.visible = clouds_enabled
		for d in clouds.get_children():
			if d is Decal:
				(d as Decal).modulate = Color(cloud_color.r, cloud_color.g, cloud_color.b, cloud_darkness)


func _apply_wind() -> void:
	var mats := {}
	var groups := [[bushes, bush_sway], [trees, tree_sway]]
	var k := 0
	for g in groups:
		for p in g[0]:
			var s := get_node_or_null(p) as Sprite3D
			if s == null or s.texture == null:
				continue
			k += 1
			if not wind_enabled:
				s.material_override = null
				continue
			# one material per picture, shared by every prop that uses it
			var key := s.texture.resource_path
			if not mats.has(key):
				var m := ShaderMaterial.new()
				m.shader = WIND_SHADER
				m.set_shader_parameter("texture_albedo", s.texture)
				m.set_shader_parameter("wind_strength", wind_strength)
				m.set_shader_parameter("wind_speed", wind_speed)
				mats[key] = m
			s.material_override = mats[key]
			s.set_instance_shader_parameter("sway", g[1])
			s.set_instance_shader_parameter("px", s.pixel_size)
			s.set_instance_shader_parameter("phase", float(k) * 1.7)
