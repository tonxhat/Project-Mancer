extends Node
## DEMO LOOP — makes the heroes take turns casting, forever, so the light and
## glow can be watched (and recorded) without any game logic yet.
## Turn it off with "Running" in the Inspector. It never runs inside the editor.

## Casters in turn order (SpellCaster nodes under each hero).
@export var casters: Array[NodePath] = []
## Seconds before the first cast.
@export var start_delay := 0.6
## Seconds between one cast starting and the next.
@export var gap := 2.7
@export var running := true


func _ready() -> void:
	if Engine.is_editor_hint() or not running:
		return
	await get_tree().create_timer(start_delay).timeout
	var i := 0
	while running and not casters.is_empty():
		var c := get_node_or_null(casters[i % casters.size()])
		if c and c.has_method("cast"):
			c.call("cast")
		i += 1
		await get_tree().create_timer(gap).timeout
