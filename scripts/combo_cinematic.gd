extends Node
## COMBO CINEMATIC — while a combo runs:
##  - the hero dashes out to stand in front of the target (Hero Offset)
##  - the camera pushes in on the hero + target, real depth of field focuses on them
##  - everything outside an ellipse around them is blurred (other heroes / monsters)
##  - battle light dims, a focus light sits between them, the vignette tightens
## BattleUI calls set_active(); everything is tuned here.

@export_group("Hero")
## Where the hero stands, measured from the target's feet (x = toward the heroes' side is negative).
@export var hero_offset := Vector3(-1.7, 0.0, 0.5)

@export_group("Camera")
## How close the camera moves (1 = no change, 0.6 = 40% closer).
@export_range(0.3, 1.0, 0.01) var zoom := 0.62
## Field of view multiplier (1 = no change, lower = tighter lens).
@export_range(0.5, 1.2, 0.01) var fov_scale := 0.9
## Height of the point the camera aims at, above the feet.
@export_range(0.0, 3.0, 0.05) var aim_height := 1.0
## Moves the aim toward the hero (0) or the target (1).
@export_range(0.0, 1.0, 0.01) var aim_bias := 0.45

@export_group("Depth of field")
@export var dof_enabled := true
## Sharp zone around the hero + target (metres in front of / behind them).
@export_range(0.2, 6.0, 0.05) var sharp_range := 2.8
@export_range(0.1, 10.0, 0.05) var dof_fade := 2.0
@export_range(0.0, 1.0, 0.01) var dof_amount := 0.1

@export_group("Screen blur (others out of focus)")
@export var screen_blur := true
## Blur strength (higher = blurrier).
@export_range(0.0, 6.0, 0.1) var blur_amount := 3.2
## Size of the sharp ellipse around hero + target (screen widths / heights).
@export var sharp_size := Vector2(0.2, 0.34)
@export_range(0.05, 2.0, 0.05) var blur_softness := 0.55

@export_group("Light")
## Sun brightness during a combo (1 = unchanged, 0.3 = dark).
@export_range(0.0, 1.0, 0.01) var sun_level := 0.4
## Ambient / sky light during a combo.
@export_range(0.0, 1.0, 0.01) var ambient_level := 0.45
@export var focus_color := Color(1.0, 0.86, 0.7)
@export_range(0.0, 12.0, 0.1) var focus_energy := 3.0
@export_range(1.0, 20.0, 0.1) var focus_range := 6.5
@export_range(0.0, 5.0, 0.05) var focus_height := 2.0
@export var focus_shadows := true
## Extra darkness added to FocusVignette during a combo.
@export_range(0.0, 1.0, 0.01) var vignette_boost := 0.3

@export_group("Timing")
@export_range(0.05, 2.0, 0.05) var fade_in := 0.4
@export_range(0.05, 3.0, 0.05) var fade_out := 0.6

var _k := 0.0
var _on := false
var _a: Node3D
var _b: Node3D
var _light: OmniLight3D
var _sun: DirectionalLight3D
var _env: Environment
var _vig: Node
var _cam: Camera3D
var _base := {}
var _blur: ColorRect


func _ready() -> void:
	add_to_group("combo_cinematic")
	_light = OmniLight3D.new()
	_light.light_energy = 0.0
	_light.visible = false
	add_child.call_deferred(_light)
	var cl := CanvasLayer.new()
	cl.layer = 4
	add_child.call_deferred(cl)
	_blur = ColorRect.new()
	_blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/combo_blur.gdshader")
	_blur.material = m
	_blur.visible = false
	cl.add_child(_blur)


func set_active(on: bool, hero: Node3D = null, target: Node3D = null) -> void:
	if on and not _on:
		_capture()
	_on = on
	if hero:
		_a = hero
	if target:
		_b = target


func _capture() -> void:
	var root := get_tree().current_scene
	if _k > 0.001:
		return   # still fading out from the last combo: keep the real base values
	_sun = null
	for n in root.get_children():
		if n is DirectionalLight3D:
			_sun = n
			break
	var we: WorldEnvironment = null
	for n in root.get_children():
		if n is WorldEnvironment:
			we = n
	_env = we.environment if we else null
	_vig = root.get_node_or_null("FocusVignette")
	_cam = root.get_viewport().get_camera_3d()
	var ca := _cam.attributes as CameraAttributesPractical if _cam else null
	_base = {
		"sun": float(_sun.get_meta("base_energy", _sun.light_energy)) if _sun else 1.0,
		"amb": _env.ambient_light_energy if _env else 1.0,
		"bg": _env.background_energy_multiplier if _env else 1.0,
		"vig": float(_vig.get("strength")) if _vig else 0.0,
		"pos": _cam.position if _cam else Vector3.ZERO,
		"fov": _cam.fov if _cam else 30.0,
		"dist": float(root.get("camera_distance")) if root.get("camera_distance") != null else 14.0,
	}
	if ca:
		_base["dof"] = [ca.dof_blur_far_enabled, ca.dof_blur_far_distance, ca.dof_blur_far_transition,
			ca.dof_blur_near_enabled, ca.dof_blur_near_distance, ca.dof_blur_near_transition, ca.dof_blur_amount]


func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.01)
	if Engine.time_scale <= 0.0:
		rd = 0.0
	var want := 1.0 if _on else 0.0
	if _k == 0.0 and want == 0.0:
		return
	_k = move_toward(_k, want, rd / (fade_in if _on else fade_out))
	var e := _k * _k * (3.0 - 2.0 * _k)
	var ok := is_instance_valid(_a) and is_instance_valid(_b)
	# light
	if _sun:
		var s: float = _base["sun"] * lerpf(1.0, sun_level, e)
		_sun.set_meta("base_energy", s)
		var tw = _sun.get_meta("dim_tween") if _sun.has_meta("dim_tween") else null
		if tw == null or not (tw as Tween).is_valid() or not (tw as Tween).is_running():
			_sun.light_energy = s
	if _env:
		_env.ambient_light_energy = _base["amb"] * lerpf(1.0, ambient_level, e)
		_env.background_energy_multiplier = _base["bg"] * lerpf(1.0, ambient_level, e)
	if _vig:
		_vig.set("strength", clampf(_base["vig"] + vignette_boost * e, 0.0, 1.0))
	if _light and _light.is_inside_tree():
		_light.visible = ok and e > 0.001
		if ok:
			_light.light_color = focus_color
			_light.omni_range = focus_range
			_light.shadow_enabled = focus_shadows
			_light.light_energy = focus_energy * e
			_light.global_position = _a.global_position.lerp(_b.global_position, 0.5) + Vector3(0, focus_height, 1.0)
	# camera push-in + depth of field
	if _cam and _base.has("pos"):
		var aim: Vector3 = _base["pos"] - (-_cam.global_basis.z) * float(_base["dist"])
		if ok:
			aim = _a.global_position.lerp(_b.global_position, aim_bias) + Vector3(0, aim_height, 0)
		var dir := -_cam.global_basis.z
		var dist := float(_base["dist"]) * zoom
		var to := aim - dir * dist
		_cam.position = (_base["pos"] as Vector3).lerp(to, e)
		_cam.fov = lerpf(_base["fov"], _base["fov"] * fov_scale, e)
		var ca := _cam.attributes as CameraAttributesPractical
		if ca and _base.has("dof"):
			var b: Array = _base["dof"]
			if e <= 0.0005 or not dof_enabled:
				ca.dof_blur_far_enabled = b[0]
				ca.dof_blur_far_distance = b[1]
				ca.dof_blur_far_transition = b[2]
				ca.dof_blur_near_enabled = b[3]
				ca.dof_blur_near_distance = b[4]
				ca.dof_blur_near_transition = b[5]
				ca.dof_blur_amount = b[6]
			else:
				var d := _cam.global_position.distance_to(aim)
				ca.dof_blur_far_enabled = true
				ca.dof_blur_near_enabled = true
				ca.dof_blur_far_distance = lerpf(b[1], d + sharp_range, e)
				ca.dof_blur_far_transition = lerpf(b[2], dof_fade, e)
				ca.dof_blur_near_distance = lerpf(b[4], maxf(0.1, d - sharp_range), e)
				ca.dof_blur_near_transition = lerpf(b[5], dof_fade, e)
				ca.dof_blur_amount = lerpf(b[6], dof_amount, e)
	# screen blur outside the hero + target
	if _blur:
		_blur.visible = screen_blur and ok and e > 0.001
		if _blur.visible:
			var vs := get_viewport().get_visible_rect().size
			var pa := _cam.unproject_position(_a.global_position + Vector3(0, 1.0, 0)) / vs
			var pb := _cam.unproject_position(_b.global_position + Vector3(0, 1.0, 0)) / vs
			var m := _blur.material as ShaderMaterial
			m.set_shader_parameter("center", (pa + pb) * 0.5)
			m.set_shader_parameter("radius", Vector2(maxf(sharp_size.x, absf(pb.x - pa.x) * 0.5 + 0.08), sharp_size.y))
			m.set_shader_parameter("softness", blur_softness)
			m.set_shader_parameter("amount", blur_amount)
			m.set_shader_parameter("strength", e)
	if _k == 0.0:
		_light.visible = false
