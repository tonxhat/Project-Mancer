extends OmniLight3D
## Simple flickering light (lava glow, ghost flames). Base energy = the light's energy.
@export_range(0.0, 1.0, 0.01) var flicker := 0.25
@export_range(0.1, 10.0, 0.1) var speed := 2.0
var _base := 0.0
var _t := 0.0

func _ready() -> void:
	_base = light_energy
	_t = randf() * 10.0

func _process(delta: float) -> void:
	_t += delta * speed
	light_energy = _base * (1.0 - flicker * 0.5 + flicker * 0.5 * (sin(_t * 2.3) * 0.6 + sin(_t * 5.1) * 0.4))
