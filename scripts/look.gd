@tool
extends Node3D
## LOOK CONTROL PANEL
## Defaults below = the look approved on 13 Oct 2026.
## Select the root node "Look" and change these values in the Inspector.
## The scene updates live in the editor. Change the look here rather than
## on the Sun / Camera3D / WorldEnvironment nodes, or these values will override them.

@export_group("Sun")
## Height of the sun above the horizon. Low = long golden-hour shadows.
@export_range(5.0, 85.0, 0.5) var sun_height_deg := 34.0:
	set(v):
		sun_height_deg = v
		_apply()
## Where the light comes from. 0 = straight from behind the camera, + = from the left.
@export_range(-90.0, 90.0, 0.5) var sun_from_left_deg := -45.0:
	set(v):
		sun_from_left_deg = v
		_apply()
@export var sun_color := Color(1.0, 0.84, 0.64):
	set(v):
		sun_color = v
		_apply()
@export_range(0.0, 4.0, 0.05) var sun_energy := 1.35:
	set(v):
		sun_energy = v
		_apply()
## Softness of shadow edges.
@export_range(0.0, 4.0, 0.05) var shadow_softness := 2.25:
	set(v):
		shadow_softness = v
		_apply()

@export_group("Shadow side (ambient)")
## Colour that fills the shadows. Cool blue against a warm sun reads as Octopath.
@export var ambient_color := Color(0.50, 0.56, 0.86):
	set(v):
		ambient_color = v
		_apply()
@export_range(0.0, 2.0, 0.05) var ambient_energy := 0.1:
	set(v):
		ambient_energy = v
		_apply()

@export_group("Camera")
## How far the camera looks down. Octopath sits around 20-35.
@export_range(5.0, 70.0, 0.5) var camera_pitch_deg := 12.0:
	set(v):
		camera_pitch_deg = v
		_apply()
@export_range(3.0, 40.0, 0.1) var camera_distance := 14.0:
	set(v):
		camera_distance = v
		_apply()
## Vertical field of view (landscape screen). Narrow = flatter, more diorama-like.
@export_range(10.0, 90.0, 0.5) var camera_fov := 30.0:
	set(v):
		camera_fov = v
		_apply()
@export var camera_target := Vector3(0.0, 1.4, 0.0):
	set(v):
		camera_target = v
		_apply()

@export_group("Tilt-shift lens (screen blur, top and bottom)")
## Main miniature-lens effect. Cheap, works on every renderer and on the web.
@export var tilt_shift_enabled := true:
	set(v):
		tilt_shift_enabled = v
		_apply()
## Blur fades out by this height from the top of the screen (0 = top, 1 = bottom).
@export_range(0.0, 1.0, 0.01) var tilt_top_clear := 0.28:
	set(v):
		tilt_top_clear = v
		_apply()
## Blur starts at this height and grows toward the bottom edge.
@export_range(0.0, 1.0, 0.01) var tilt_bottom_clear := 0.70:
	set(v):
		tilt_bottom_clear = v
		_apply()
@export_range(0.0, 6.0, 0.05) var tilt_strength := 2.6:
	set(v):
		tilt_strength = v
		_apply()

@export_group("Depth of field (optional, real 3D distance)")
## On by default (approved look, 13 Oct 2026). Heavier than tilt-shift and not
## available on the web build, where only the tilt-shift lens remains.
@export var dof_enabled := true:
	set(v):
		dof_enabled = v
		_apply()
## Distance from the camera where the background starts to blur.
@export_range(0.0, 60.0, 0.1) var dof_far_start := 7.8:
	set(v):
		dof_far_start = v
		_apply()
@export_range(0.1, 40.0, 0.1) var dof_far_fade := 9.8:
	set(v):
		dof_far_fade = v
		_apply()
## Anything closer than this to the camera blurs (foreground grass).
@export_range(0.0, 20.0, 0.1) var dof_near_start := 7.9:
	set(v):
		dof_near_start = v
		_apply()
@export_range(0.1, 10.0, 0.1) var dof_near_fade := 2.0:
	set(v):
		dof_near_fade = v
		_apply()
@export_range(0.0, 1.0, 0.01) var dof_strength := 0.09:
	set(v):
		dof_strength = v
		_apply()

@export_group("Colour and glow")
@export_range(0.0, 3.0, 0.05) var exposure := 1.1:
	set(v):
		exposure = v
		_apply()
@export_range(0.0, 2.0, 0.01) var saturation := 0.8:
	set(v):
		saturation = v
		_apply()
@export_range(0.0, 2.0, 0.01) var contrast := 1.51:
	set(v):
		contrast = v
		_apply()
@export_range(0.0, 3.0, 0.05) var glow_strength := 2.5:
	set(v):
		glow_strength = v
		_apply()
## How much of the whole image glows, not only the brightest parts.
@export_range(0.0, 1.0, 0.01) var glow_bloom := 0.13:
	set(v):
		glow_bloom = v
		_apply()
## Distance haze. Pushes far layers back and ties them to the sky colour.
@export_range(0.0, 0.1, 0.001) var haze_density := 0.008:
	set(v):
		haze_density = v
		_apply()
@export var haze_color := Color(0.96, 0.72, 0.56):
	set(v):
		haze_color = v
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	var cam := get_node_or_null("Camera3D") as Camera3D
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment

	if sun:
		# Light travels away from the camera, angled down and to the right.
		sun.rotation_degrees = Vector3(-sun_height_deg, -sun_from_left_deg, 0.0)
		sun.light_color = sun_color
		sun.light_energy = sun_energy
		sun.shadow_blur = shadow_softness

	if cam:
		var p := deg_to_rad(camera_pitch_deg)
		cam.position = camera_target + Vector3(0.0, sin(p), cos(p)) * camera_distance
		cam.rotation = Vector3(-p, 0.0, 0.0)
		cam.keep_aspect = Camera3D.KEEP_HEIGHT  # landscape PC screen: lock the vertical view
		cam.fov = camera_fov
		var ca := cam.attributes as CameraAttributesPractical
		if ca:
			ca.dof_blur_far_enabled = dof_enabled
			ca.dof_blur_near_enabled = dof_enabled
			ca.dof_blur_far_distance = dof_far_start
			ca.dof_blur_far_transition = dof_far_fade
			ca.dof_blur_near_distance = dof_near_start
			ca.dof_blur_near_transition = dof_near_fade
			ca.dof_blur_amount = dof_strength
			ca.exposure_multiplier = exposure

	var tilt := get_node_or_null("TiltShift/Blur") as ColorRect
	if tilt:
		tilt.visible = tilt_shift_enabled
		var sm := tilt.material as ShaderMaterial
		if sm:
			sm.set_shader_parameter("top_clear", tilt_top_clear)
			sm.set_shader_parameter("bottom_clear", tilt_bottom_clear)
			sm.set_shader_parameter("strength", tilt_strength)

	if we and we.environment:
		var env := we.environment
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = ambient_color
		env.ambient_light_energy = ambient_energy
		env.adjustment_enabled = true
		env.adjustment_saturation = saturation
		env.adjustment_contrast = contrast
		env.glow_enabled = glow_strength > 0.0
		env.glow_intensity = glow_strength
		env.glow_bloom = glow_bloom
		env.fog_enabled = haze_density > 0.0
		env.fog_density = haze_density
		env.fog_light_color = haze_color
