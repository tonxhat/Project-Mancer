@tool
extends Node3D
## STAGE SET — pick which battle stage is shown. Put it directly under the Look root.
## Verdant Field uses the nodes already in main.tscn (Ground, DirtPath1, Backdrop, Props);
## every other stage is a child of this node (Coast, Cave, Peak, Marsh, Spire) — open the
## arrow next to it in the Scene tree, or click its props in the 3D view, and move them freely.
##
## LIGHT AND COLOUR PER STAGE: pick a stage here, then tune the Look / Atmosphere panels.
## The values are remembered for THAT stage only (automatically). Ctrl+S saves them.
## Camera settings stay shared by all stages.
## In game: L1 / R1 (or Q / E) switch stage.

const STAGES := {
	"Field": "",
	"Coast": "res://stages/coast.tscn",
	"Cave": "res://stages/cave.tscn",
	"Peak": "res://stages/peak.tscn",
	"Marsh": "res://stages/marsh.tscn",
	"Spire": "res://stages/spire.tscn",
}
const FIELD_NODES := ["Ground", "DirtPath1", "Backdrop", "Props"]

signal stage_changed(preset: Node)

@export_enum("Field", "Coast", "Cave", "Peak", "Marsh", "Spire") var stage := "Field":
	set(v):
		if v == stage and is_node_ready():
			return
		stage = v
		if is_node_ready():
			_switch()

var _snap_hash := 0
var _poll := 0.0


func _ready() -> void:
	var fp := get_node_or_null("FieldPreset")
	# first run with this version: Field remembers your current tilt-shift / DOF / wind etc.
	# (only the values that were never per-stage before — sun, colour etc. stay as stored)
	if fp and fp.extra.is_empty():
		var all: Dictionary = fp.collect(_look(), _atmo())
		var known: Dictionary = fp.values()
		var ex := {}
		for k in all:
			if not known.has(k):
				ex[k] = all[k]
		fp.extra = ex
	_switch()


func cycle(step: int) -> void:
	var keys := STAGES.keys().filter(func(k): return k == "Field" or _stage_node(k, false) != null or ResourceLoader.exists(STAGES[k]))
	stage = keys[posmod(keys.find(stage) + step, keys.size())]


func preset() -> Node:
	if stage == "Field":
		return get_node_or_null("FieldPreset")
	return _stage_node(stage, false)


func _look() -> Node:
	return get_parent()


func _atmo() -> Node:
	return get_parent().get_node_or_null("Atmosphere")


func _stage_node(key: String, create: bool) -> Node3D:
	var n := get_node_or_null(key) as Node3D
	if n == null and create and key != "Field" and ResourceLoader.exists(STAGES[key]):
		# stage not placed in main.tscn: load it for this run only
		n = (load(STAGES[key]) as PackedScene).instantiate() as Node3D
		n.name = key
		add_child(n)
	return n


func _switch() -> void:
	var look := _look()
	if stage != "Field" and _stage_node(stage, true) == null:
		push_warning("Stage scene not built yet: " + STAGES[stage])
		stage = "Field"
		return
	var field := stage == "Field"
	for n in FIELD_NODES:
		var node := look.get_node_or_null(n) as Node3D
		if node:
			node.visible = field
	for k in STAGES:
		if k == "Field":
			continue
		var sn := _stage_node(k, false)
		if sn:
			sn.visible = k == stage
			if not Engine.is_editor_hint():
				sn.process_mode = Node.PROCESS_MODE_INHERIT if k == stage else Node.PROCESS_MODE_DISABLED
	var p := preset()
	if p:
		var fb := {}
		var fp := get_node_or_null("FieldPreset")
		if fp and not field:
			fb = fp.values()   # anything this stage hasn't stored yet comes from Verdant Field
		p.apply_to(look, _atmo(), fb)
	_snap_hash = _snapshot_hash()
	stage_changed.emit(p)


func _snapshot_hash() -> int:
	var sp := load("res://scripts/stage_preset.gd")
	return var_to_str(sp.collect(_look(), _atmo())).hash()


func _process(delta: float) -> void:
	# Editor only: whatever you change in Look / Atmosphere is stored into the shown stage.
	if not Engine.is_editor_hint():
		return
	_poll += delta
	if _poll < 0.3:
		return
	_poll = 0.0
	var h := _snapshot_hash()
	if h != _snap_hash:
		_snap_hash = h
		var p := preset()
		if p:
			p.capture_from(_look(), _atmo())
