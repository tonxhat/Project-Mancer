@tool
extends Sprite3D
## A pixel-art character standing in the 3D world.
## The sheet is a grid of frames (hframes x vframes); one row = one animation.
## The node's origin is where the feet touch the ground.

## Which row of the sheet to play (0 = idle, 1 = attack/cast, 2 = charge for heroes).
@export var row := 0
## Row to go back to after a one-shot animation (attack, hit).
@export var idle_row := 0
## How many frames of the row to use.
@export var frames_in_row := 6
## Animation speed in frames per second.
@export var fps := 8.0
## How bright the hit flash glows (0 = no flash, 1 = strong).
@export_range(0.0, 2.0, 0.05) var flash_strength := 0.7
## Pixel column of the feet inside one frame, measured from the left edge.
@export var feet_x := 32:
	set(v):
		feet_x = v
		_place()
## Pixel row of the feet inside one frame, measured from the top edge.
@export var feet_y := 72:
	set(v):
		feet_y = v
		_place()

var _t := 0.0
var _once := false
var _idle_fps := 8.0
var _home := Vector3.ZERO
var _shake := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _hit_color := Color.WHITE


func _ready() -> void:
	_place()
	_home = position
	_idle_fps = fps


func _process(delta: float) -> void:
	_t += delta
	var n: int = maxi(frames_in_row, 1)
	var i := int(_t * fps)
	if _once and i >= n:
		# one-shot finished: back to idle
		_once = false
		row = idle_row
		fps = _idle_fps
		_t = 0.0
		i = 0
	frame = row * hframes + (mini(i, n - 1) if _once else i % n)

	if Engine.is_editor_hint():
		return
	# hit reaction: shake + bright flash in the spell's colour
	if _shake > 0.0:
		_shake = maxf(_shake - delta, 0.0)
		var a := _shake * 0.35
		position = _home + Vector3(sin(_t * 90.0) * a, 0.0, 0.0)
	else:
		position = _home
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 4.0, 0.0)
	if material_override is ShaderMaterial:
		# actor shader (week 3+): the flash is a coloured glow, the art stays readable
		modulate = Color.WHITE
		set_instance_shader_parameter("flash", Vector4(_hit_color.r, _hit_color.g, _hit_color.b, _flash * flash_strength))
	else:
		modulate = Color.WHITE.lerp(_flash_color, _flash) if _flash > 0.0 else Color.WHITE


## Play a row. once = play it one time, then return to idle_row.
func play_row(r: int, speed: float = -1.0, once: bool = false) -> void:
	row = r
	fps = speed if speed > 0.0 else _idle_fps
	_once = once
	_t = 0.0


## Called by a spell when it lands.
func hit(color: Color) -> void:
	_shake = 0.3
	_flash = 1.0
	_hit_color = color * 0.5
	# above 1.0 = brighter than white, so the glow effect picks the flash up
	_flash_color = Color(color.r * 3.0 + 1.0, color.g * 3.0 + 1.0, color.b * 3.0 + 1.0)


func _place() -> void:
	# Draw from the bottom-left corner, then shift so the feet land on the origin.
	centered = false
	if texture == null:
		return
	var fh: int = texture.get_height() / maxi(vframes, 1)
	var fw: int = texture.get_width() / maxi(hframes, 1)
	var fx := feet_x
	if flip_h:
		fx = fw - feet_x
	offset = Vector2(-fx, -(fh - 1 - feet_y))
