extends RefCounted
## SAVE — hero levels, EXP, combo sets and cleared stages in user://mancer_save.json
## (Windows: %APPDATA%\Godot\app_userdata\Mancer HD-2D Slice\). Delete the file to start over.

const D := preload("res://scripts/mancer_data.gd")
const PATH := "user://mancer_save.json"


static func fresh() -> Dictionary:
	var heroes := {}
	for h in D.HEROES:
		heroes[h["id"]] = {"lv": 1, "exp": 0, "set": D.DEFAULT_SET[h["id"]].duplicate(), "eq": {}, "tree": [], "sp_bonus": 0}
	heroes["Terramancer"]["eq"] = {"weapon": "war_gauntlet", "armor": "leather_coat"}
	heroes["Pyromancer"]["eq"] = {"weapon": "oak_staff"}
	return {"heroes": heroes, "cleared": [], "stage": 0, "items": D.START_ITEMS.duplicate(), "equips": D.START_EQUIPS.duplicate(),
		"opt": {"music": -10.0, "sfx": -4.0, "auto": false, "speed": 1.0}}


static func load_game() -> Dictionary:
	var s := fresh()
	if not FileAccess.file_exists(PATH):
		return s
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return s
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return s
	for id in s["heroes"]:
		var h: Dictionary = d.get("heroes", {}).get(id, {})
		if h.is_empty():
			continue
		s["heroes"][id]["lv"] = clampi(int(h.get("lv", 1)), 1, D.MAX_LV)
		s["heroes"][id]["exp"] = int(h.get("exp", 0))
		var st: Array = h.get("set", [])
		if st.size() == 3:
			s["heroes"][id]["set"] = st
		if h.has("eq"):
			s["heroes"][id]["eq"] = h["eq"]
		if h.has("tree"):
			s["heroes"][id]["tree"] = h["tree"]
		s["heroes"][id]["sp_bonus"] = int(h.get("sp_bonus", 0))
	s["cleared"] = []
	for c in d.get("cleared", []):
		s["cleared"].append(int(c))
	s["stage"] = int(d.get("stage", 0))
	if d.has("items"):
		s["items"] = {}
		for k in d["items"]:
			s["items"][k] = int(d["items"][k])
	if d.has("rewarded"):
		s["rewarded"] = []
		for c in d["rewarded"]:
			s["rewarded"].append(int(c))
	if d.has("equips"):
		s["equips"] = d["equips"]
	if d.has("opt"):
		s["opt"].merge(d["opt"], true)
	return s


static func save_game(s: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(s, "  "))
