extends Node
## COMBO CASTER (week 4) — two heroes cast at the same target at the same time;
## when both spells arrive they fuse into a combo (scripts/elements.gd → COMBO).
##   Lava  = Earth + Fire : glowing pool, erupting molten blobs, rising embers
##   Steam = Water + Fire : billowing lit cloud, hot spray, droplets
## Call cast() (BattleDemo does this when the node is in its list).

const EL := preload("res://scripts/elements.gd")
const KIT := preload("res://scripts/vfx_kit.gd")

@export_enum("Lava", "Steam") var combo := "Lava"
## The two SpellCaster nodes (one under each hero).
@export var caster_a: NodePath
@export var caster_b: NodePath
## Seconds the second hero waits before starting, so the casts overlap but don't mirror.
@export var stagger := 0.15

var _busy := false


func cast() -> void:
	var a := get_node_or_null(caster_a)
	var b := get_node_or_null(caster_b)
	if _busy or a == null or b == null:
		return
	_busy = true
	var c: Dictionary = EL.combo(combo)
	var hits := []
	var run := func(caster: Node, delay: float) -> void:
		if delay > 0.0:
			await get_tree().create_timer(delay).timeout
		var p: Vector3 = await caster.call("cast_part")
		hits.append(p)
		# each spell gives a small hit as it lands
		var sp: Dictionary = EL.spell(caster.get("element"))
		KIT.motes(get_tree().current_scene, p, EL.motes(caster.get("element")), 0.0)
	run.call(a, 0.0)
	run.call(b, stagger)
	while hits.size() < 2:
		await get_tree().process_frame
	var at: Vector3 = (hits[0] + hits[1]) * 0.5
	var root := get_tree().current_scene
	if combo == "Steam":
		KIT.steam(root, at, c)
	else:
		KIT.lava(root, at, c)
	var tgt := a.get_node_or_null(a.get("target"))
	if tgt and tgt.has_method("hit"):
		var hc: Color = c["color"] * 0.6
		tgt.call("hit", hc)
		await get_tree().create_timer(0.35).timeout
		tgt.call("hit", hc)
	_busy = false
