extends Node
## TURN GLOW — glowing outline on whoever is taking their turn (party battle).
## Tune here; BattleUI reads these values every frame.

## Outline thickness in sprite pixels (1 = thin, 4 = thick).
@export_range(1, 4) var width := 2
## Corner shape: 0 = sharp diamond corners, 1 = square corners.
@export_range(0.0, 1.0, 0.05) var roundness := 0.5
@export var ally_color := Color("45C8FF")
@export var enemy_color := Color("FF3D5A")
## Base brightness (above 1 blooms).
@export_range(0.0, 6.0, 0.05) var brightness := 2.2
## How much it pulses on top of the base.
@export_range(0.0, 4.0, 0.05) var pulse := 1.3
## Pulse speed.
@export_range(0.0, 20.0, 0.5) var pulse_speed := 5.0
## Also glow while the enemy takes its turn.
@export var glow_enemies := true


func _ready() -> void:
	add_to_group("turn_glow")
