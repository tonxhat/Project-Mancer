@tool
extends OmniLight3D
## BODY LIGHT (aura) — a light that a character gives off because of its element.
## Fire breathes and flickers, Lightning crackles, Ice glows softly.
## Earth, Water and Air have no body light: they only light up while casting.
## Pick the element in the Inspector; colour and behaviour come from scripts/elements.gd.

const EL := preload("res://scripts/elements.gd")

@export_enum("Earth", "Water", "Air", "Fire", "Lightning", "Ice", "Magma") var element := "Fire":
	set(v):
		element = v
		_load_preset()
## Multiplies the element's brightness (1 = as set in elements.gd).
@export_range(0.0, 3.0, 0.05) var strength := 1.0:
	set(v):
		strength = v
		_load_preset()

var _base := 0.0
var _style := "steady"
var _t := 0.0
var _spike := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	shadow_enabled = false  # body lights never cast shadows: cheap on phones
	_rng.seed = hash(name)
	_load_preset()


func _load_preset() -> void:
	var p: Dictionary = EL.aura(element)
	light_color = p["color"]
	omni_range = p["range"]
	_base = float(p["energy"]) * strength
	_style = p["style"]
	visible = _base > 0.0
	light_energy = _base


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	match _style:
		"flame":
			var slow := sin(_t * TAU * 1.1) * 0.5 + 0.5
			var fast := sin(_t * 23.0) * sin(_t * 17.0)
			light_energy = _base * (0.7 + 0.3 * slow + 0.09 * fast)
		"crackle":
			if _rng.randf() < delta * 7.0:
				_spike = _rng.randf_range(0.8, 2.2)
			_spike = move_toward(_spike, 0.0, delta * 9.0)
			light_energy = _base * (0.45 + _spike)
		_:
			light_energy = _base * (0.85 + 0.15 * sin(_t * TAU * 0.4))
