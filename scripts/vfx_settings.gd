extends Node
## VFX PANEL (week 4) — one node named "VFX" in the scene.
## Every spell reads these values when it lands, so you can tune all spell effects here.
## (Per-element colours and strengths live in scripts/elements.gd.)

## Sprite = pixel-art hit animations from the Mancer prototype (one per element, they glow).
## HD = smooth high-resolution effects. Pixel = only the small pixel sparks.
@export_enum("Sprite", "HD", "Pixel") var style := "Sprite"

@export_group("Sprite hits")
## How hard the pixel-art hit effects glow (0 = flat, 1.5 = soft bloom, 3+ = blazing).
@export_range(0.0, 5.0, 0.05) var sprite_glow := 3.35
## Seconds one hit animation takes (12 frames). Higher = slower, easier to see.
@export_range(0.3, 3.0, 0.05) var sprite_time := 1.1
## Size of the hit animations (1 = one sprite pixel = one character pixel).
@export_range(0.3, 3.0, 0.05) var sprite_size := 0.9
## Glow of the flying spell and the sparks at the hands (multiplies elements.gd "glow").
@export_range(0.0, 3.0, 0.05) var spell_glow := 2.2

@export_group("HD hits")
## Size of HD hit effects.
@export_range(0.3, 3.0, 0.05) var hd_size := 2.4

@export_group("Light and scene")
## Multiplies every spell light (hand glow, flying spell, impact flash).
@export_range(0.0, 3.0, 0.05) var light_strength := 2.6
## Impact flashes cast real shadows from the characters, rocks and trees.
## Looks great; costs a little speed. Turn off on weak phones.
@export var impact_shadows := true
## How much the sun dims while a spell lands (multiplies "dim" in elements.gd). 0 = never.
@export_range(0.0, 2.0, 0.05) var scene_dim := 1.45
## Seconds the sun takes to come back after dimming.
@export_range(0.1, 4.0, 0.05) var dim_recover := 1.0
## Glowing patch on the ground where a spell lands.
@export var ground_glow := true
## Multiplies how many small round sparks each hit leaves. 0 = none.
@export_range(0.0, 3.0, 0.05) var motes_amount := 1.0
## Seconds the small sparks live (short = pop and vanish).
@export_range(0.2, 4.0, 0.05) var motes_time := 0.6
## Camera shake strength on impact. 0 = off.
@export_range(0.0, 3.0, 0.05) var shake := 1.0


func _ready() -> void:
	add_to_group("vfx_settings")
