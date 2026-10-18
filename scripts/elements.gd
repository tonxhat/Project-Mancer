extends RefCounted
## Element lighting table: one place for every element's light colour and behaviour.
## Change a row here and every hero, spell and aura of that element follows.
## Colours lean on the Mancer Colour Bible element hues.

## Body light (aura): elements that give off light by themselves.
## energy 0 = this element has no body light (it only lights up while casting).
## style: "flame" = breathing + flicker, "crackle" = sharp random spikes,
##        "steady" = slow gentle pulse.
const AURA := {
	"Earth":     {"color": Color(1.00, 0.78, 0.45), "energy": 0.0, "range": 3.0, "style": "steady"},
	"Water":     {"color": Color(0.45, 0.72, 1.00), "energy": 0.0, "range": 3.0, "style": "steady"},
	"Air":       {"color": Color(0.70, 1.00, 0.82), "energy": 0.0, "range": 3.0, "style": "steady"},
	"Fire":      {"color": Color(1.00, 0.55, 0.22), "energy": 1.6, "range": 4.5, "style": "flame"},
	"Lightning": {"color": Color(0.62, 0.74, 1.00), "energy": 1.1, "range": 3.6, "style": "crackle"},
	"Ice":       {"color": Color(0.62, 0.88, 1.00), "energy": 0.5, "range": 2.6, "style": "steady"},
	"Magma":     {"color": Color(1.00, 0.42, 0.12), "energy": 0.9, "range": 3.2, "style": "flame"},
}

## Spell light: every element lights the scene while casting and on impact.
## charge = energy at the hands while charging; travel = light carried by the spell;
## impact = peak of the flash where it hits. glow = how hard the spell's own pixels glow:
## about 1 = no glow, 2-3 = strong glow. Above ~3 the colour burns out to white.
const SPELL := {
	"Earth":     {"color": Color(1.00, 0.74, 0.40), "charge": 1.6, "travel": 2.0, "impact": 5.0, "glow": 1.8, "dim": 0.2},
	"Water":     {"color": Color(0.40, 0.70, 1.00), "charge": 1.6, "travel": 2.4, "impact": 6.0, "glow": 2.0, "dim": 0.25},
	"Air":       {"color": Color(0.70, 1.00, 0.82), "charge": 1.4, "travel": 2.0, "impact": 5.0, "glow": 1.8, "dim": 0.2},
	"Fire":      {"color": Color(1.00, 0.50, 0.16), "charge": 2.6, "travel": 3.2, "impact": 9.0, "glow": 2.4, "dim": 0.35},
	"Lightning": {"color": Color(0.66, 0.78, 1.00), "charge": 2.4, "travel": 4.0, "impact": 11.0, "glow": 3.0, "dim": 0.5},
	"Ice":       {"color": Color(0.62, 0.88, 1.00), "charge": 1.8, "travel": 2.6, "impact": 6.5, "glow": 2.0, "dim": 0.3},
	"Magma":     {"color": Color(1.00, 0.40, 0.10), "charge": 2.2, "travel": 3.0, "impact": 8.5, "glow": 2.3, "dim": 0.35},
}
## "dim" = how much the sun dims for a moment when the spell lands (0 = not at all, 1 = dark),
## so the spell's own light takes over the scene.

## Small round sparks that pop out of a hit and vanish quickly (VFX → Motes Time).
## motion: "ember" rises, "snow" drifts down, "pop" bursts outward, "dust" settles,
##         "swirl" circles, "spark" short fast zaps.
const MOTES := {
	"Earth":     {"color": Color(0.95, 0.72, 0.42), "glow": 1.8, "motion": "dust",  "amount": 12, "tex": "dot"},
	"Water":     {"color": Color(0.45, 0.78, 1.00), "glow": 2.0, "motion": "pop",   "amount": 14, "tex": "dot"},
	"Air":       {"color": Color(0.75, 1.00, 0.85), "glow": 1.8, "motion": "swirl", "amount": 14, "tex": "dot"},
	"Fire":      {"color": Color(1.00, 0.55, 0.18), "glow": 2.6, "motion": "ember", "amount": 16, "tex": "dot"},
	"Lightning": {"color": Color(0.70, 0.82, 1.00), "glow": 3.0, "motion": "spark", "amount": 18, "tex": "dot"},
	"Ice":       {"color": Color(0.75, 0.92, 1.00), "glow": 2.0, "motion": "snow",  "amount": 14, "tex": "dot"},
	"Magma":     {"color": Color(1.00, 0.42, 0.10), "glow": 2.6, "motion": "ember", "amount": 16, "tex": "dot"},
	"Steam":     {"color": Color(0.95, 0.95, 1.00), "glow": 1.6, "motion": "pop",   "amount": 14, "tex": "dot"},
}

## Combo spells: two elements meeting at the target make a new effect.
const COMBO := {
	"Lava":  {"a": "Earth", "b": "Fire",  "color": Color(1.00, 0.38, 0.08), "impact": 14.0, "dim": 0.6, "linger": 3.5},
	"Steam": {"a": "Water", "b": "Fire",  "color": Color(0.92, 0.95, 1.00), "impact": 5.0,  "dim": 0.45, "linger": 3.5},
}

const NAMES := "Earth,Water,Air,Fire,Lightning,Ice,Magma"


static func aura(element: String) -> Dictionary:
	return AURA.get(element, AURA["Earth"])


static func spell(element: String) -> Dictionary:
	return SPELL.get(element, SPELL["Earth"])


static func motes(element: String) -> Dictionary:
	return MOTES.get(element, MOTES["Earth"])


static func combo(name: String) -> Dictionary:
	return COMBO.get(name, COMBO["Lava"])
