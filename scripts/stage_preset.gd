@tool
extends Node3D
## STAGE PRESET — the lighting and atmosphere of one stage.
## Sits on the root of each stage scene (stages/*.tscn) and on StageSet/FieldPreset.
## StageSet copies these values into the Look and Atmosphere panels when the stage is shown.
## Tune the look with the Look / Atmosphere panels while the stage is shown:
## the values are stored here automatically, separately for every stage. Save main.tscn (Ctrl+S).

@export var stage_name := "VERDANT FIELD"
@export var stage_sub := "STAGE 1  ·  ทุ่งหญ้าแรกแย้ม"

@export_group("Sun")
@export_range(5.0, 85.0, 0.5) var sun_height_deg := 34.0
@export_range(-90.0, 90.0, 0.5) var sun_from_left_deg := -45.0
@export var sun_color := Color(1.0, 0.84, 0.64)
@export_range(0.0, 4.0, 0.05) var sun_energy := 1.35

@export_group("Shadow side and sky")
@export var ambient_color := Color(0.5, 0.56, 0.86)
@export_range(0.0, 2.0, 0.05) var ambient_energy := 0.1
## Colour behind everything (only seen where the sky panorama doesn't reach).
@export var background_color := Color(0.96, 0.66, 0.5)

@export_group("Colour")
@export_range(0.0, 3.0, 0.05) var exposure := 1.1
@export_range(0.0, 2.0, 0.01) var saturation := 0.8
@export_range(0.0, 2.0, 0.01) var contrast := 1.51
@export_range(0.0, 3.0, 0.05) var glow_strength := 2.5
@export_range(0.0, 0.1, 0.001) var haze_density := 0.004
@export var haze_color := Color(0.96, 0.72, 0.56)

@export_group("Atmosphere")
@export var shafts_enabled := true
@export var shaft_color := Color(1.0, 0.82, 0.55)
@export_range(0.0, 1.5, 0.01) var shaft_intensity := 0.45
@export var clouds_enabled := true
@export_range(0.0, 1.0, 0.01) var cloud_darkness := 0.86
@export var cloud_color := Color(0.12, 0.1, 0.22)
@export var dust_color := Color(1.0, 0.8, 0.5)
@export_range(0, 300, 1) var dust_amount := 40

const LOOK_KEYS := ["sun_height_deg", "sun_from_left_deg", "sun_color", "sun_energy", "ambient_color",
	"ambient_energy", "exposure", "saturation", "contrast", "glow_strength", "haze_density", "haze_color"]
const ATMO_KEYS := {"shafts_enabled": "shafts_enabled", "shaft_color": "shaft_color", "shaft_intensity": "shaft_intensity",
	"clouds_enabled": "clouds_enabled", "cloud_darkness": "cloud_darkness", "cloud_color": "cloud_color",
	"dust_color": "dust_color", "dust_amount": "dust_amount"}
## Look settings shared by every stage (never stored per stage)
const SHARED_PREFIX := ["camera_"]
const SKIP_ATMO := ["bushes", "trees"]
const VALUE_TYPES := [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_COLOR, TYPE_VECTOR2, TYPE_VECTOR3]

## Every other Look / Atmosphere value of this stage (tilt-shift, DOF, bloom, wind, cloud speed ...).
## Filled automatically while you tune the Look panel with this stage shown.
@export_storage var extra := {}


## All per-stage values stored in this preset, as {"look:x": v, "atmo:y": v, "bg": c}.
func values() -> Dictionary:
	var d := extra.duplicate()
	for k in LOOK_KEYS:
		d["look:" + k] = get(k)
	for k in ATMO_KEYS:
		d["atmo:" + ATMO_KEYS[k]] = get(k)
	d["bg"] = background_color
	return d


func store(d: Dictionary) -> void:
	var ex := extra.duplicate()
	for key in d:
		var k := String(key)
		if k == "bg":
			background_color = d[k]
		elif k.begins_with("look:") and k.substr(5) in LOOK_KEYS:
			set(k.substr(5), d[k])
		elif k.begins_with("atmo:") and k.substr(5) in ATMO_KEYS:
			set(k.substr(5), d[k])
		else:
			ex[k] = d[k]
	extra = ex


## Read the current per-stage values from the Look and Atmosphere panels.
static func collect(look: Node, atmo: Node) -> Dictionary:
	var d := {}
	for pr in look.get_property_list():
		var n: String = pr.name
		if not (pr.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and pr.usage & PROPERTY_USAGE_EDITOR):
			continue
		if not (pr.type in VALUE_TYPES) or SHARED_PREFIX.any(func(x): return n.begins_with(x)):
			continue
		d["look:" + n] = look.get(n)
	if atmo:
		for pr in atmo.get_property_list():
			var n: String = pr.name
			if not (pr.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and pr.usage & PROPERTY_USAGE_EDITOR):
				continue
			if not (pr.type in VALUE_TYPES) or n in SKIP_ATMO:
				continue
			d["atmo:" + n] = atmo.get(n)
	var we := look.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		d["bg"] = we.environment.background_color
	return d


## fallback = values to use for anything this stage hasn't stored yet (Verdant Field's).
func apply_to(look: Node, atmo: Node, fallback := {}) -> void:
	# stop any spell "sun dim" still running and forget its old base brightness,
	# otherwise the sun would fade back to the previous stage's brightness
	var sun := look.get_node_or_null("Sun")
	if sun:
		if sun.has_meta("dim_tween"):
			var tw: Tween = sun.get_meta("dim_tween")
			if tw and tw.is_valid():
				tw.kill()
			sun.remove_meta("dim_tween")
		if sun.has_meta("base_energy"):
			sun.remove_meta("base_energy")
	var d := fallback.duplicate()
	d.merge(values(), true)
	for key in d:
		var k := String(key)
		if k == "bg":
			var we := look.get_node_or_null("WorldEnvironment") as WorldEnvironment
			if we and we.environment:
				we.environment.background_color = d[k]
		elif k.begins_with("look:"):
			if k.substr(5) in look:
				look.set(k.substr(5), d[k])
		elif k.begins_with("atmo:") and atmo:
			if k.substr(5) in atmo:
				atmo.set(k.substr(5), d[k])


func capture_from(look: Node, atmo: Node) -> void:
	store(collect(look, atmo))


func _ready() -> void:
	_apply_wind()


## Sprites in a stage that should sway: give them the meta "sway" (e.g. 0.08 trees, 0.16 grass).
func _apply_wind() -> void:
	var shader := load("res://shaders/wind_sway.gdshader")
	var mats := {}
	var k := 0
	for n in find_children("*", "Sprite3D", true, false):
		var s := n as Sprite3D
		if not s.has_meta("sway") or s.texture == null:
			continue
		k += 1
		var key := s.texture.resource_path
		if not mats.has(key):
			var m := ShaderMaterial.new()
			m.shader = shader
			m.set_shader_parameter("texture_albedo", s.texture)
			m.set_shader_parameter("wind_strength", 1.0)
			m.set_shader_parameter("wind_speed", 1.0)
			mats[key] = m
		s.material_override = mats[key]
		s.set_instance_shader_parameter("sway", float(s.get_meta("sway")))
		s.set_instance_shader_parameter("px", s.pixel_size)
		s.set_instance_shader_parameter("phase", float(k) * 1.7)
