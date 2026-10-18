extends RefCounted
## MANCER — GAME DATA (one file for every number you might want to tune).
## Heroes, Magicks (unlocked by level), monsters, stages, the element table and the
## battle tuning constants. Battle rules live in scripts/battle_ui.gd.
##
## Element rules are ported from the web build (Project Mancer v1.19+):
##   4 base elements in a cycle  Fire > Earth > Air > Water > Fire
##   every mixed element is made of 2 bases (Steam = Water+Fire, Magma = Fire+Earth …)
##   x2 = weak, x0.5 = resisted, x0.75 = a base hitting a mix that already contains it.

# ------------------------------------------------------------------ elements
const EL_TH := {
	"Earth": "ดิน", "Water": "น้ำ", "Air": "ลม", "Fire": "ไฟ", "Bio": "ชีวภาพ", "Lightning": "สายฟ้า",
	"Steam": "ไอน้ำ", "Ice": "น้ำแข็ง", "Sand": "ทราย", "Magma": "ลาวา", "Death": "ความตาย", "None": "กายภาพ",
}
const EL_COL := {
	"Earth": Color("C8924E"), "Water": Color("3E8EF0"), "Air": Color("49C9AE"), "Fire": Color("F0503F"),
	"Bio": Color("6CC045"), "Lightning": Color("F2CC2A"), "Steam": Color("F0E6DA"), "Ice": Color("A8E0FF"),
	"Sand": Color("D6B474"), "Magma": Color("F07A34"), "Death": Color("2E9C78"), "None": Color("DDE6F5"),
}
## strong against (x2)
const STRONG := {
	"Water": ["Fire", "Magma"], "Fire": ["Earth", "Ice"], "Air": ["Water", "Steam"], "Earth": ["Air", "Lightning"],
	"Steam": ["Ice", "Magma"], "Magma": ["Sand", "Bio"], "Sand": ["Lightning", "Fire"], "Ice": ["Earth", "Bio"],
	"Bio": ["Steam", "Sand"], "Lightning": ["Water", "Air"],
}
const BEATS := {"Fire": "Earth", "Earth": "Air", "Air": "Water", "Water": "Fire"}
## a base element hitting a mix that contains it (lava shrugs off fire) = x0.75
const HALF := {"Fire": ["Magma", "Lightning"], "Water": ["Ice"], "Earth": ["Sand"], "Air": ["Lightning"]}
## FUSION: a Magick hits an enemy that still carries another element's mark -> the two mix.
const FUSE := {
	"Earth+Fire": "Magma", "Fire+Water": "Steam", "Earth+Water": "Bio",
	"Air+Fire": "Lightning", "Air+Earth": "Sand", "Air+Water": "Ice",
}
const FUSE_TH := {"Magma": "ลาวา", "Steam": "ไอน้ำ", "Bio": "ชีวภาพ", "Lightning": "สายฟ้า", "Sand": "ทราย", "Ice": "น้ำแข็ง"}


## raw multiplier attacker element -> defender element
static func mult_raw(a: String, d: String) -> float:
	if a == "" or a == "None" or d == "":
		return 1.0
	if not STRONG.has(a) or not STRONG.has(d):
		return 1.0
	if d in STRONG[a]:
		return 2.0
	if d == a:
		return 0.5
	if BEATS.has(a):
		for k in BEATS:
			if BEATS[k] == a and k == d:
				return 0.5   # a base hitting the base that beats it
		if d in HALF.get(a, []):
			return 0.75
	return 1.0


## for labels: 2 = WEAK, 0.5 = RESIST, 1 = neutral
static func mult(a: String, d: String) -> float:
	var m := mult_raw(a, d)
	return 2.0 if m >= 2.0 else (0.5 if m < 1.0 else m)


## multiplier for enemy elemental attacks on a hero of element h (softer than x2)
static func mult_def(a: String, h: String) -> float:
	var m := mult_raw(a, h)
	return 1.0 + (m - 1.0) * 0.5 if m > 1.0 else 1.0 - (1.0 - m) * 0.6


static func fuse(a: String, b: String) -> String:
	var k := a + "+" + b if a < b else b + "+" + a
	return FUSE.get(k, "")


# ------------------------------------------------------------------ heroes
## stat order: hp, mp, str, mag, def, mdef, spd  (multiplies the shared level curve)
const HEROES := [
	{"id": "Terramancer", "name": "TERRAMANCER", "short": "TERRA", "el": "Earth", "th": "จอมเวทดิน · แทงก์ กายภาพแรง",
	 "mod": [1.25, 0.8, 1.25, 0.8, 1.35, 1.0, 0.9], "icon": Rect2(14, 2, 38, 38)},
	{"id": "Pyromancer", "name": "PYROMANCER", "short": "PYRO", "el": "Fire", "th": "จอมเวทไฟ · ดาเมจเวทสูง ตัวบาง",
	 "mod": [0.9, 1.1, 0.9, 1.3, 0.85, 1.0, 1.0], "icon": Rect2(13, 2, 38, 38)},
	{"id": "Hydromancer", "name": "HYDROMANCER", "short": "HYDRO", "el": "Water", "th": "จอมเวทน้ำ · ฮีลเลอร์ ทนเวท",
	 "mod": [1.05, 1.25, 0.85, 1.05, 1.0, 1.2, 1.0], "icon": Rect2(14, 2, 38, 38)},
]
const MAX_LV := 20


static func hero_def(id: String) -> Dictionary:
	for h in HEROES:
		if h["id"] == id:
			return h
	return HEROES[0]


static func hero_stats(id: String, lv: int) -> Dictionary:
	var k := float(lv - 1)
	var base := [340 + 64 * k, 52 + 8 * k, 22 + 4.2 * k, 22 + 4.2 * k, 14 + 3 * k, 14 + 3 * k, 30 + 0.8 * k]
	var m: Array = hero_def(id)["mod"]
	return {"mhp": int(round(base[0] * m[0])), "mmp": int(round(base[1] * m[1])), "str": base[2] * m[2], "mag": base[3] * m[3],
		"def": base[4] * m[4], "mdef": base[5] * m[5], "spd": base[6] * m[6]}


## EXP needed to go from lv to lv+1
static func exp_need(lv: int) -> int:
	return int(round(25.0 * pow(float(lv), 1.45)))


# ------------------------------------------------------------------ magicks
## lv = level that unlocks it · tg: one / all (enemies), self, party, ally (lowest HP), revive
## k: mag / phys · pow = power · hits = hits per target · w = how long it takes (timeline: 1 = normal)
## st = status on the enemy (turns) · buff = status on the allies hit · heal = share of max HP
const MAGICKS := {
	"Terramancer": [
		{"id": "stone_fist", "lv": 1, "n": "Stone Fist", "th": "หมัดหิน", "el": "Earth", "k": "phys", "tg": "one", "mp": 3, "pow": 1.5, "d": "หมัดหินกายภาพใส่ศัตรู 1 ตัว"},
		{"id": "rock_break", "lv": 1, "n": "Rock Break", "th": "ทุบเกราะ", "el": "Earth", "k": "phys", "tg": "one", "mp": 6, "pow": 1.0, "st": {"defdown": 3}, "brk": 1.6, "d": "ทุบเกราะ ลด DEF ศัตรู 3 เทิร์น · ทำ Break แรง"},
		{"id": "stoneskin", "lv": 1, "n": "Stoneskin", "th": "ผิวหิน", "el": "Earth", "tg": "party", "mp": 10, "buff": {"protect": 3}, "w": 0.8, "d": "Protect ทั้งปาร์ตี้ ลดดาเมจกายภาพครึ่งหนึ่ง 3 เทิร์น"},
		{"id": "quake", "lv": 3, "n": "Quake", "th": "แผ่นดินไหว", "el": "Earth", "k": "phys", "tg": "all", "mp": 14, "pow": 1.05, "w": 1.2, "d": "แผ่นดินไหวใส่ศัตรูทั้งหมด"},
		{"id": "concuss", "lv": 5, "n": "Concuss", "th": "หมัดสะเทือน", "el": "Earth", "k": "phys", "tg": "one", "mp": 9, "pow": 1.2, "st": {"stun": 1}, "d": "หมัดหิน + Stun ดันเทิร์นศัตรูถอยหลัง"},
		{"id": "fault_line", "lv": 7, "n": "Fault Line", "th": "รอยเลื่อน", "el": "Earth", "k": "phys", "tg": "one", "mp": 14, "pow": 1.6, "st": {"defdown": 3, "slow": 2}, "w": 1.2, "d": "×1.6 + DEF↓ 3 เทิร์น + Slow 2 เทิร์น"},
		{"id": "mountain_guard", "lv": 9, "n": "Mountain Guard", "th": "ป้อมภูผา", "el": "Earth", "tg": "party", "mp": 18, "buff": {"protect": 3, "shell": 3}, "w": 0.9, "d": "Protect + Shell ทั้งปาร์ตี้ 3 เทิร์น"},
		{"id": "meteor_fist", "lv": 12, "n": "Meteor Fist", "th": "หมัดอุกกาบาต", "el": "Earth", "k": "phys", "tg": "one", "mp": 18, "pow": 2.2, "w": 1.3, "d": "หมัดอุกกาบาต ×2.2"},
		{"id": "aftershock", "lv": 15, "n": "Aftershock", "th": "อาฟเตอร์ช็อก", "el": "Earth", "k": "phys", "tg": "all", "mp": 20, "pow": 0.62, "hits": 2, "d": "แผ่นดินไหว 2 ระลอกใส่ศัตรูทั้งหมด"},
		{"id": "cataclysm", "lv": 18, "n": "Cataclysm", "th": "มหาวิบัติ", "el": "Earth", "k": "phys", "tg": "all", "mp": 28, "pow": 1.5, "st": {"defdown": 2}, "w": 1.4, "d": "มหาวิบัติทั้งหมด ×1.5 + DEF↓"},
	],
	"Pyromancer": [
		{"id": "fire_bolt", "lv": 1, "n": "Fire Bolt", "th": "ลูกไฟ", "el": "Fire", "k": "mag", "tg": "one", "mp": 5, "pow": 1.35, "d": "ลูกไฟใส่ศัตรู 1 ตัว"},
		{"id": "ignite", "lv": 1, "n": "Ignite", "th": "จุดไฟ", "el": "Fire", "k": "mag", "tg": "one", "mp": 7, "pow": 0.6, "st": {"burn": 3}, "d": "จุดไฟ + ติดไฟ (Burn) 3 เทิร์น"},
		{"id": "kindle", "lv": 1, "n": "Kindle", "th": "ปลุกเปลว", "el": "Fire", "tg": "self", "mp": 6, "buff": {"magup": 3}, "w": 0.7, "d": "พลังเวท (MAG) +50% 3 เทิร์น · ร่ายไว"},
		{"id": "flame_burst", "lv": 3, "n": "Flame Burst", "th": "ระเบิดเพลิง", "el": "Fire", "k": "mag", "tg": "all", "mp": 14, "pow": 1.0, "w": 1.2, "d": "ระเบิดเพลิงใส่ศัตรูทั้งหมด"},
		{"id": "twin_bolt", "lv": 5, "n": "Twin Bolt", "th": "ลูกไฟคู่", "el": "Fire", "k": "mag", "tg": "one", "mp": 9, "pow": 0.8, "hits": 2, "d": "ลูกไฟ 2 ลูกติดกัน"},
		{"id": "wildfire", "lv": 7, "n": "Wildfire", "th": "ไฟลามทุ่ง", "el": "Fire", "k": "mag", "tg": "all", "mp": 16, "pow": 0.7, "st": {"burn": 3}, "w": 1.2, "d": "ไฟลามทั้งหมด + Burn 3 เทิร์น"},
		{"id": "searing", "lv": 9, "n": "Searing", "th": "แผดเผา", "el": "Fire", "k": "mag", "tg": "one", "mp": 10, "pow": 0.6, "st": {"burn": 3, "defdown": 3}, "d": "ติดไฟ + DEF↓ 3 เทิร์น"},
		{"id": "flare", "lv": 12, "n": "Flare", "th": "แฟลร์", "el": "Fire", "k": "mag", "tg": "one", "mp": 18, "pow": 1.9, "w": 1.3, "d": "ลูกไฟแรงสูง ×1.9"},
		{"id": "blaze_soul", "lv": 15, "n": "Blaze Soul", "th": "วิญญาณเพลิง", "el": "Fire", "tg": "party", "mp": 20, "buff": {"magup": 3}, "w": 0.9, "d": "MAG↑ ทั้งปาร์ตี้ 3 เทิร์น"},
		{"id": "inferno", "lv": 18, "n": "Inferno", "th": "นรกเพลิง", "el": "Fire", "k": "mag", "tg": "all", "mp": 28, "pow": 1.5, "w": 1.4, "d": "นรกเพลิงทั้งหมด ×1.5"},
	],
	"Hydromancer": [
		{"id": "aqua_lance", "lv": 1, "n": "Aqua Lance", "th": "หอกน้ำ", "el": "Water", "k": "mag", "tg": "one", "mp": 5, "pow": 1.25, "d": "หอกน้ำใส่ศัตรู 1 ตัว"},
		{"id": "cure", "lv": 1, "n": "Cure", "th": "รักษา", "el": "Water", "tg": "ally", "mp": 7, "heal": 0.35, "d": "ฟื้น HP 35% ให้เพื่อนที่ HP น้อยที่สุด"},
		{"id": "riptide", "lv": 1, "n": "Riptide", "th": "กระแสดูด", "el": "Water", "k": "mag", "tg": "one", "mp": 8, "pow": 1.0, "st": {"slow": 2}, "d": "หอกน้ำ + Slow 2 เทิร์น (เทิร์นศัตรูมาช้าลง)"},
		{"id": "regen_tide", "lv": 3, "n": "Regen Tide", "th": "คลื่นฟื้นฟู", "el": "Water", "tg": "party", "mp": 10, "buff": {"regen": 3}, "w": 0.8, "d": "Regen ทั้งปาร์ตี้ ฟื้น HP ทุกเทิร์น 3 เทิร์น"},
		{"id": "torrent", "lv": 5, "n": "Torrent", "th": "กระแสน้ำเชี่ยว", "el": "Water", "k": "mag", "tg": "all", "mp": 14, "pow": 1.0, "w": 1.2, "d": "กระแสน้ำซัดศัตรูทั้งหมด"},
		{"id": "cure_wave", "lv": 7, "n": "Cure Wave", "th": "คลื่นรักษา", "el": "Water", "tg": "party", "mp": 16, "heal": 0.25, "d": "ฟื้น HP 25% ทั้งปาร์ตี้"},
		{"id": "revive", "lv": 9, "n": "Revive", "th": "คืนชีพ", "el": "Water", "tg": "revive", "mp": 20, "heal": 0.3, "w": 1.1, "d": "ชุบเพื่อนที่ล้ม กลับมาพร้อม HP 30%"},
		{"id": "tidal_pierce", "lv": 12, "n": "Tidal Pierce", "th": "หอกกระแสน้ำ", "el": "Water", "k": "mag", "tg": "one", "mp": 12, "pow": 1.0, "hits": 2, "drain": 0.3, "d": "แทง 2 ครั้ง ดูด HP 30% ของดาเมจ"},
		{"id": "undertow", "lv": 15, "n": "Undertow", "th": "คลื่นใต้น้ำ", "el": "Water", "k": "mag", "tg": "all", "mp": 16, "pow": 0.7, "st": {"slow": 2}, "d": "กระแสดูดทั้งหมด + Slow 2 เทิร์น"},
		{"id": "maelstrom", "lv": 18, "n": "Maelstrom", "th": "น้ำวนมหึมา", "el": "Water", "k": "mag", "tg": "all", "mp": 26, "pow": 1.4, "w": 1.4, "d": "น้ำวนทั้งหมด ×1.4"},
	],
}
## combo set a new save starts with (□ △ ○)
const DEFAULT_SET := {
	"Terramancer": ["stone_fist", "rock_break", "stoneskin"],
	"Pyromancer": ["fire_bolt", "ignite", "kindle"],
	"Hydromancer": ["aqua_lance", "riptide", "cure"],
}


static func magick(hero_id: String, mid: String) -> Dictionary:
	for m in MAGICKS.get(hero_id, []):
		if m["id"] == mid:
			return m
	return {}


static func magicks_at(hero_id: String, lv: int) -> Array:
	return MAGICKS.get(hero_id, []).filter(func(m): return m["lv"] <= lv)


## icon type for a magick: single, aoe, buff, heal, debuff
static func kind(m: Dictionary) -> String:
	if m.has("heal"):
		return "heal"
	if m["tg"] in ["self", "party"]:
		return "buff"
	if not m.has("pow"):
		return "debuff"
	return "aoe" if m["tg"] == "all" else "single"


const KIND_TAG := {"single": "ATK", "aoe": "ALL", "buff": "BUFF", "heal": "HEAL", "debuff": "DEBUFF"}
const STATUS_TH := {
	"burn": "BURN", "poison": "POISON", "slow": "SLOW", "stun": "STUN", "defdown": "DEF↓", "blind": "BLIND",
	"magup": "MAG↑", "protect": "PROTECT", "shell": "SHELL", "regen": "REGEN", "guard": "GUARD", "break": "BREAK",
}
const BAD := ["burn", "poison", "slow", "defdown", "blind"]

# ------------------------------------------------------------------ monsters
## sheet = art/mon/mon_<El>.png (5 x 2 frames: row 0 idle, row 1 attack) · fs = frame size
## bb = body box inside a frame · b = hp, atk, mag, def, mdef, spd (level 1)
const MONS := {
	"Earth": {"n": "Cragback", "fs": 64, "bb": [8, 21, 56, 61], "b": [300, 16, 10, 22, 8, 20], "sk": "Terra Crush", "sk_k": "phys", "st": {"defdown": 2}},
	"Water": {"n": "Tidefin", "fs": 64, "bb": [10, 20, 54, 61], "b": [240, 13, 15, 10, 16, 26], "sk": "Aqua Lance", "sk_k": "mag"},
	"Air": {"n": "Gustwing", "fs": 64, "bb": [7, 10, 56, 61], "b": [220, 14, 13, 8, 12, 32], "sk": "Gale Force", "sk_k": "mag", "hits": 2},
	"Fire": {"n": "Emberfang", "fs": 64, "bb": [7, 13, 56, 61], "b": [250, 15, 16, 10, 10, 27], "sk": "Inferno Strike", "sk_k": "mag", "st": {"burn": 2}},
	"Ice": {"n": "Frosthorn", "fs": 80, "bb": [11, 17, 69, 77], "b": [330, 15, 17, 14, 18, 22], "sk": "Glacier Tomb", "sk_k": "mag", "st": {"slow": 2}},
	"Lightning": {"n": "Voltclaw", "fs": 80, "bb": [14, 25, 65, 77], "b": [280, 15, 18, 12, 12, 32], "sk": "Volt Pierce", "sk_k": "mag", "st": {"stun": 1}},
	"Magma": {"n": "Cindermaw", "fs": 80, "bb": [8, 29, 72, 77], "b": [380, 18, 18, 18, 10, 20], "sk": "Molten Core", "sk_k": "mag", "st": {"burn": 2}},
	"Steam": {"n": "Boilhide", "fs": 80, "bb": [13, 18, 67, 77], "b": [330, 16, 17, 14, 14, 24], "sk": "Boil Mist", "sk_k": "mag", "st": {"blind": 2}},
	"Sand": {"n": "Dunestalker", "fs": 80, "bb": [11, 20, 69, 77], "b": [310, 17, 13, 18, 12, 26], "sk": "Sand Veil", "sk_k": "phys", "st": {"blind": 2}},
	"Bio": {"n": "Sporemaw", "fs": 80, "bb": [15, 33, 64, 77], "b": [320, 14, 16, 12, 14, 24], "sk": "Wild Surge", "sk_k": "mag", "st": {"poison": 3}},
	"Death": {"n": "Morte", "fs": 96, "bb": [8, 16, 88, 93], "b": [1050, 20, 22, 18, 18, 24], "sk": "Soul Drain", "sk_k": "mag", "boss": true},
}

# ------------------------------------------------------------------ stages
## key = StageSet stage · lv = monster level · waves: element names, or {el, n, boss}
const STAGES := [
	{"key": "Field", "n": "VERDANT FIELD", "th": "ทุ่งหญ้าแรกแย้ม", "lv": 1,
	 "waves": [["Air"], ["Earth", "Air"], [{"el": "Earth", "n": "Cragback Alpha", "boss": true}]]},
	{"key": "Coast", "n": "TIDEPOOL COAST", "th": "ชายฝั่งน้ำวน", "lv": 3,
	 "waves": [["Water", "Fire"], ["Fire", "Water", "Water"], [{"el": "Water", "n": "Tidefin King", "boss": true}]]},
	{"key": "Cave", "n": "CINDER CAVE", "th": "ถ้ำเถ้าถ่าน", "lv": 4,
	 "waves": [["Fire", "Earth"], ["Magma", "Fire", "Earth"], [{"el": "Magma", "n": "Cindermaw Tyrant", "boss": true}]]},
	{"key": "Peak", "n": "STORM PEAK", "th": "ยอดเขาพายุ", "lv": 6,
	 "waves": [["Ice", "Air"], ["Lightning", "Ice", "Air"], [{"el": "Lightning", "n": "Voltclaw Storm", "boss": true}]]},
	{"key": "Marsh", "n": "MIASMA MARSH", "th": "บึงไอพิษ", "lv": 7,
	 "waves": [["Steam", "Sand"], ["Bio", "Steam", "Sand"], [{"el": "Bio", "n": "Sporemaw Elder", "boss": true}]]},
	{"key": "Spire", "n": "SPIRE OF MORTE", "th": "หอคอยวิญญาณ", "lv": 9,
	 "waves": [["Ice", "Lightning"], ["Bio", "Magma", "Sand"], [{"el": "Death", "n": "Morte", "boss": true}]]},
]


static func stage_foes(i: int) -> Array:
	var out := []
	for w in STAGES[i]["waves"]:
		for s in w:
			var el: String = s if s is String else s["el"]
			if not el in out:
				out.append(el)
	return out


## monster at level lv. boss = stage boss (more HP, ultimate)
static func make_enemy(spec: Variant, lv: int) -> Dictionary:
	var el: String = spec if spec is String else spec["el"]
	var boss: bool = (spec is Dictionary) and spec.get("boss", false)
	var t: Dictionary = MONS[el]
	var k := float(lv - 1)
	var hp_m: float = (1.0 + 0.2 * k) * TUNE["EHP"] * (TUNE["BOSSHP"] if boss and not t.get("boss", false) else 1.0)
	var st_m := 1.0 + 0.16 * k
	var b: Array = t["b"]
	var mhp := int(round(b[0] * hp_m))
	return {"side": "e", "el": el, "name": (spec["n"] if spec is Dictionary else t["n"]).to_upper(), "boss": boss,
		"mhp": mhp, "hp": mhp, "str": b[1] * st_m * (1.1 if boss else 1.0), "mag": b[2] * st_m * (1.1 if boss else 1.0),
		"def": b[3] * (1.0 + 0.12 * k), "mdef": b[4] * (1.0 + 0.12 * k), "spd": b[5] * (1.5 if boss else 1.0) * (1.0 + 0.02 * k),
		"lv": lv, "status": {}, "known": {}, "mark": "", "turns": 0,
		"mbrk": TUNE["BRKBOSS"] if boss else TUNE["BRK"], "brk": TUNE["BRKBOSS"] if boss else TUNE["BRK"], "broken": 0,
		"exp": int(round((10 + 6 * lv) * (4.0 if boss else 1.0)))}


# ------------------------------------------------------------------ tuning
const TUNE := {
	"DMG": 2.2,        # hero damage scale
	"EDMG": 4.0,       # enemy damage scale
	"EHP": 2.0,        # enemy HP (party of 3 hits much more often than the solo web build)
	"BOSSHP": 2.4,     # stage boss HP x
	"NEU": 0.72,       # elemental hit that is neither weak nor resisted
	"ATK_POW": 0.8,    # normal attack (physical, no element)
	"TURN": 1000.0,    # timeline: one normal action waits TURN / speed
	# combo gauge (0..3 segments)
	"G_ATTACK": 1.0, "G_MAGICK": 0.5, "G_WEAK": 0.5, "G_DEALT": 2.0, "G_DEALT_MAX": 0.5, "G_TAKEN": 2.5, "G_DEFEND": 0.3,
	"COMBO_MIN": 2,    # segments needed to start a combo
	"COMBO_POW": [1.0, 1.35, 1.8],   # power of combo spell 1 / 2 / 3
	"COMBO_BRK": 14.0, # break per combo spell (x element)
	"FULL_BONUS": 0.25,# a combo started with a full gauge (3): every spell +25%
	# break gauge
	"BRK": 100.0, "BRKBOSS": 200.0, "BRK_ATK": 20.0, "BRK_MAG": 5.0, "BRK_DMG": 1.5,
	"BRK_W": 1.5, "BRK_N": 0.6, "BRK_R": 0.3,
	# MP
	"MPX": 1.6,        # every Magick costs its listed mp x this
	"MP_ATTACK": 0.06, "MP_DEFEND": 0.10, "MP_TURN": 0.03, "WAVE_HEAL": 0.2,
	"FUSE_POW": 0.9,
}


# ------------------------------------------------------------------ finishers
## A combo of exactly 3 spells in this button order (0 = □, 1 = △, 2 = ○) fires a finisher.
## Element = the hero's element. Needs a full combo (3 gauge segments).
const FINISHERS := [
	{"seq": [0, 2, 1], "n": "ELEMENTAL STORM", "th": "เวทธาตุถล่มศัตรูทั้งหมด", "kind": "aoe", "pow": 1.3},
	{"seq": [0, 2, 2], "n": "GRACE", "th": "ฮีลทั้งปาร์ตี้ 30% + Regen", "kind": "heal", "heal": 0.3},
	{"seq": [0, 2, 0], "n": "HEX STRIKE", "th": "โจมตี + DEF↓ + Slow", "kind": "hex", "pow": 1.4},
	{"seq": [1, 1, 1], "n": "OVERDRIVE", "th": "โจมตีเดี่ยวแรง ×3.0", "kind": "single", "pow": 3.0},
	{"seq": [0, 0, 0], "n": "BREAKER", "th": "ทุบเกราะ BREAK ทันที", "kind": "break", "pow": 0.8},
	{"seq": [2, 2, 2], "n": "AEGIS", "th": "Protect + Shell ทั้งปาร์ตี้", "kind": "aegis"},
	{"seq": [1, 0, 2], "n": "MANA BLOOM", "th": "MP +25% ทั้งปาร์ตี้ + เกจเพื่อน +1", "kind": "mana"},
	{"seq": [2, 1, 0], "n": "TIME SLIP", "th": "ดันเทิร์นศัตรูทั้งหมดถอยหลัง", "kind": "time"},
]


static func finisher_for(seq: Array) -> Dictionary:
	for f in FINISHERS:
		if f["seq"] == seq:
			return f
	return {}


# ------------------------------------------------------------------ items
## use: what happens when used from the System Menu on the selected hero
const ITEMS := {
	"tome_s": {"n": "EXP Tome", "th": "ตำรา EXP เล็ก", "d": "EXP +60 ให้ตัวละคร 1 คน", "use": {"exp": 60}},
	"tome_l": {"n": "Grand Tome", "th": "ตำรา EXP ใหญ่", "d": "EXP +300 ให้ตัวละคร 1 คน", "use": {"exp": 300}},
	"seed": {"n": "Skill Seed", "th": "เมล็ดทักษะ", "d": "Skill Point +1 ให้ตัวละคร 1 คน", "use": {"sp": 1}},
	"forget": {"n": "Forget Orb", "th": "ลูกแก้วลืมเลือน", "d": "รีเซ็ต Skill Tree คืน SP ทั้งหมด", "use": {"reset": 1}},
}
const START_ITEMS := {"tome_s": 3, "seed": 1, "forget": 1}

# ------------------------------------------------------------------ equipment
## slot: weapon / armor / accessory · fx: multipliers (str, mag, def, mdef, hp, mp, spd) and
## gauge (combo gauge gain), cpow (combo power), mpatk (MP from attack)
const EQUIPS := {
	"oak_staff": {"slot": "weapon", "n": "Oak Staff", "th": "ไม้เท้าโอ๊ก", "d": "MAG +8%", "fx": {"mag": 1.08}},
	"war_gauntlet": {"slot": "weapon", "n": "War Gauntlet", "th": "สนับมือศึก", "d": "STR +15%", "fx": {"str": 1.15}},
	"sage_rod": {"slot": "weapon", "n": "Sage Rod", "th": "คทานักปราชญ์", "d": "MAG +15% · MP +10%", "fx": {"mag": 1.15, "mp": 1.1}},
	"titan_fist": {"slot": "weapon", "n": "Titan Fist", "th": "หมัดไททัน", "d": "STR +25% · DEF +5%", "fx": {"str": 1.25, "def": 1.05}},
	"leather_coat": {"slot": "armor", "n": "Leather Coat", "th": "เสื้อหนัง", "d": "DEF +10% · HP +5%", "fx": {"def": 1.1, "hp": 1.05}},
	"iron_plate": {"slot": "armor", "n": "Iron Plate", "th": "เกราะเหล็ก", "d": "DEF / MDEF +18%", "fx": {"def": 1.18, "mdef": 1.18}},
	"mystic_robe": {"slot": "armor", "n": "Mystic Robe", "th": "เสื้อคลุมเวท", "d": "MDEF +15% · MP +15%", "fx": {"mdef": 1.15, "mp": 1.15}},
	"combo_gloves": {"slot": "accessory", "n": "Combo Gloves", "th": "ถุงมือคอมโบ", "d": "เกจคอมโบเติมเร็วขึ้น 25%", "fx": {"gauge": 1.25}},
	"echo_stone": {"slot": "accessory", "n": "Echo Stone", "th": "หินก้อง", "d": "พลังเวทคอมโบ +12%", "fx": {"cpow": 1.12}},
	"life_pendant": {"slot": "accessory", "n": "Life Pendant", "th": "จี้ชีวิต", "d": "HP สูงสุด +15%", "fx": {"hp": 1.15}},
	"mana_ring": {"slot": "accessory", "n": "Mana Ring", "th": "แหวนมานา", "d": "MP จากโจมตีปกติ +100%", "fx": {"mpatk": 2.0}},
	"gale_boots": {"slot": "accessory", "n": "Gale Boots", "th": "รองเท้าลมกรด", "d": "SPD +10% (เทิร์นมาเร็วขึ้น)", "fx": {"spd": 1.1}},
}
const SLOTS := ["weapon", "armor", "accessory"]
const SLOT_TH := {"weapon": "อาวุธ", "armor": "ชุดเกราะ", "accessory": "เครื่องประดับ"}
const START_EQUIPS := ["oak_staff", "war_gauntlet", "leather_coat"]
## first clear of stage i gives these
const CLEAR_REWARD := [
	{"eq": ["combo_gloves", "iron_plate"], "items": {"seed": 1}},
	{"eq": ["sage_rod", "life_pendant"], "items": {"seed": 1, "tome_s": 2}},
	{"eq": ["mystic_robe", "echo_stone"], "items": {"seed": 1}},
	{"eq": ["gale_boots", "mana_ring"], "items": {"seed": 1, "tome_l": 1}},
	{"eq": ["titan_fist"], "items": {"seed": 2}},
	{"eq": [], "items": {"seed": 2, "tome_l": 2}},
]

# ------------------------------------------------------------------ skill tree
## 3 branches x 3 tiers per hero. A node needs the one above it in the same branch.
## cost = SP. Heroes earn 1 SP per level (from Lv2) + Skill Seeds.
const TREE := [
	{"id": "b1", "br": 0, "t": 0, "n": "Vitality", "th": "พลังชีวิต", "d": "HP +8%", "cost": 1, "fx": {"hp": 1.08}},
	{"id": "b2", "br": 0, "t": 1, "n": "Iron Skin", "th": "ผิวเหล็ก", "d": "DEF / MDEF +10%", "cost": 2, "fx": {"def": 1.1, "mdef": 1.1}},
	{"id": "b3", "br": 0, "t": 2, "n": "Second Wind", "th": "ลมหายใจที่สอง", "d": "HP +15% · ฟื้น 5% ทุกเทิร์น", "cost": 3, "fx": {"hp": 1.15, "regen": 0.05}},
	{"id": "m1", "br": 1, "t": 0, "n": "Focus", "th": "สมาธิ", "d": "MAG +6% · STR +6%", "cost": 1, "fx": {"mag": 1.06, "str": 1.06}},
	{"id": "m2", "br": 1, "t": 1, "n": "Mana Flow", "th": "กระแสมานา", "d": "MP +15% · เวทใช้ MP −10%", "cost": 2, "fx": {"mp": 1.15, "mpcut": 0.9}},
	{"id": "m3", "br": 1, "t": 2, "n": "Arcane Edge", "th": "คมเวท", "d": "ดาเมจธาตุ +12%", "cost": 3, "fx": {"eldmg": 1.12}},
	{"id": "c1", "br": 2, "t": 0, "n": "Rhythm", "th": "จังหวะ", "d": "เกจคอมโบเติมเร็วขึ้น 15%", "cost": 1, "fx": {"gauge": 1.15}},
	{"id": "c2", "br": 2, "t": 1, "n": "Head Start", "th": "ออกตัวไว", "d": "เริ่มการต่อสู้ด้วยเกจ 1 ช่อง", "cost": 2, "fx": {"g0": 1.0}},
	{"id": "c3", "br": 2, "t": 2, "n": "Crescendo", "th": "ไคลแมกซ์", "d": "พลังเวทคอมโบ +15% · Finisher +20%", "cost": 3, "fx": {"cpow": 1.15, "fin": 1.2}},
]
const BRANCH_TH := ["BODY · ร่างกาย", "MIND · จิตใจ", "COMBO · คอมโบ"]


static func tree_node(id: String) -> Dictionary:
	for t in TREE:
		if t["id"] == id:
			return t
	return {}


## all multipliers from equipment + learned tree nodes
static func hero_fx(hs: Dictionary) -> Dictionary:
	var fx := {}
	var srcs := []
	for sl in SLOTS:
		var eid: String = hs.get("eq", {}).get(sl, "")
		if EQUIPS.has(eid):
			srcs.append(EQUIPS[eid]["fx"])
	for tid in hs.get("tree", []):
		var t := tree_node(tid)
		if not t.is_empty():
			srcs.append(t["fx"])
	for s in srcs:
		for k in s:
			if k in ["regen", "g0"]:
				fx[k] = float(fx.get(k, 0.0)) + float(s[k])
			else:
				fx[k] = float(fx.get(k, 1.0)) * float(s[k])
	return fx


static func final_stats(id: String, hs: Dictionary) -> Dictionary:
	var st := hero_stats(id, int(hs["lv"]))
	var fx := hero_fx(hs)
	st["mhp"] = int(round(st["mhp"] * fx.get("hp", 1.0)))
	st["mmp"] = int(round(st["mmp"] * fx.get("mp", 1.0)))
	for k in ["str", "mag", "def", "mdef", "spd"]:
		st[k] = st[k] * fx.get(k, 1.0)
	st["fx"] = fx
	return st


static func sp_total(hs: Dictionary) -> int:
	return int(hs["lv"]) - 1 + int(hs.get("sp_bonus", 0))


static func sp_spent(hs: Dictionary) -> int:
	var n := 0
	for tid in hs.get("tree", []):
		n += int(tree_node(tid).get("cost", 0))
	return n
