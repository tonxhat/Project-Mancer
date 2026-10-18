extends CanvasLayer
## MANCER — PARTY BATTLE (HD-2D, landscape PC · PS5 pad · keyboard · mouse)
## The whole game loop lives here: CAMP (pick a stage, set combo Magicks) -> BATTLE -> RESULT.
## Numbers, Magicks, monsters and stages: scripts/mancer_data.gd · save: scripts/mancer_save.gd
##
## BATTLE RULES
##  - TIMELINE (top): turn order by speed, no ATB. Every action pushes the actor back on the
##    timeline; heavy Magicks push further, DEFEND less. The bar previews where you land.
##  - Nobody acts outside their turn.
##  - Commands: ATTACK · MAGICKS (every Magick learned so far) · COMBO · DEFEND
##  - COMBO GAUGE (3 segments per hero): fills from Attack, Magicks, weakness hits, damage dealt
##    and damage taken. With 2+ segments COMBO opens combo mode: □ / △ / ○ cast the 3 Magicks
##    set in camp (1 segment each, every next one stronger), ✕ ends the combo.
##    A combo opened with a FULL gauge (3) gives +25% to every spell.
##  - Element marks: a Magick leaves its element on the enemy; another element on top FUSES
##    (Earth+Fire = Magma, Water+Fire = Steam, Earth+Water = Bio) for a bonus hit.
##  - Break gauge: hits wear it down (Attack and Combo the most). Empty = BREAK: loses its next
##    turn and takes x1.5 damage until then.
##
## CONTROLS                PS5 pad          keyboard
##   move / preview         D-pad, stick      arrows / WASD
##   confirm                ✕                 Enter / Space / K
##   back                   ○                 Esc / Backspace
##   combo □ △ ○            □ △ ○             J  I  L
##   end combo              ✕                 K / Esc
##   change target          L1 / R1           Q / E  (or ← → in the menu)
##   auto battle            OPTIONS           Tab
##   speed x1 / x2          CREATE            F

const KIT := preload("res://scripts/vfx_kit.gd")
const EL := preload("res://scripts/elements.gd")
const D := preload("res://scripts/mancer_data.gd")
const SAVE := preload("res://scripts/mancer_save.gd")

const C_PANEL := Color(0.078, 0.082, 0.098, 0.88)
const C_PANEL2 := Color("1D1F25")
const C_LINE := Color("33363F")
const C_INK := Color("F2F2EC")
const C_DIM := Color("8E919B")
const C_ACC := Color("E4FF32")
const C_ACC_INK := Color("0A0B0C")
const C_HP := Color("C6FF3A")
const C_MP := Color("3AD3FF")
const C_BAD := Color("FF3D5A")
const C_OK := Color("7CFFB2")
const C_PINK := Color("FF3F9A")
const C_GOLD := Color("FFD23A")
const C_BRK := Color("9FE8FF")
const C_ALLY := Color("45C8FF")
const C_FOE := Color("FF3D5A")

## Play by itself (heroes pick commands). OPTIONS / Tab toggles it in game.
@export var auto_battle := false
## UI size (1 = designed for 1920x1080).
@export_range(0.6, 1.5, 0.05) var ui_scale := 1.0
## Battle speed (CREATE / F toggles x1 / x2 in game).
@export_range(1.0, 4.0, 0.5) var battle_speed := 1.0
## Testing: every hero starts at this level (0 = use the save).
@export_range(0, 20) var debug_level := 0
## Start a fresh save when the game starts (wipes levels and cleared stages).
@export var reset_save := false

signal battle_finished(win: bool, stage: int, turns: int)

var F_D: FontFile
var F_D2: FontFile
var F_UI: FontFile
var F_UI2: FontFile

var _hud: Control
var _t := 0.0
var _sc := 1.0
var _tex := {}

var save := {}
var mode := "boot"          # boot, camp, battle
var state := ""             # command, magicks, combo, acting, foe, wait, win, lose
# battle
var party: Array = []
var foes: Array = []
var stage_i := 0
var wave := 0
var now := 0.0
var cur: Dictionary = {}
var cmd := 0
var mag_i := 0
var mag_top := 0
var tgt := 0
var combo := {}
var cmb_sel := -1
var turns := 0
var _exp_pool := 0
var _result := {}
var _auto_wait := 0.0
var _home := {}
var _tmpl: Sprite3D
var _bid := 0
# camp
var camp_focus := "stage"
var camp_stage := 0
var camp_hero := 0
var camp_mag := 0
# feedback
var _pops := []
var _banner := ""
var _banner_sub := ""
var _banner_t := -10.0
var _banner_col := C_ACC
var _act_text := ""
var _act_enemy := false
var _act_t := -10.0
var _info := ""
var _info_t := -10.0
var _shown := {}
var _hits := []
var _hover := ""
# options menu (battle)
var menu_open := false
var sysm
var menu_i := 0
const MENU := [["RESUME", "เล่นต่อ"], ["AUTO BATTLE", "ออโต้"], ["SPEED", "ความเร็ว"], ["SURRENDER", "ยอมแพ้"], ["RETURN TO TITLE", "กลับหน้าแรก"]]
# audio
var _bgm: AudioStreamPlayer
var _bgm_key := ""
var _sfxp: Array = []
var _sfx_i := 0
@export_range(-40.0, 6.0, 1.0) var music_db := -10.0
@export_range(-40.0, 6.0, 1.0) var sfx_db := -4.0
# combo screen fx
var _cfx_k := 0.0

const COMMANDS := [["ATTACK", "โจมตี"], ["MAGICKS", "เวทมนตร์"], ["COMBO", "คอมโบ"], ["DEFEND", "ป้องกัน"]]
const SLOT_GLYPH := ["square", "triangle", "circle"]
const SLOTS_1 := [[Vector2(2.4, 0.15)], [Vector2(1.8, 0.8), Vector2(3.9, -0.95)], [Vector2(1.7, 0.9), Vector2(3.2, -1.1), Vector2(4.5, 0.35)]]


# ================================================================ setup
func _ready() -> void:
	layer = 5
	F_UI = load("res://fonts/Kanit-Regular.ttf")
	F_UI2 = load("res://fonts/Kanit-SemiBold.ttf")
	F_D = load("res://fonts/BarlowCondensed-ExtraBoldItalic.ttf")
	F_D2 = load("res://fonts/BarlowCondensed-SemiBoldItalic.ttf")
	F_D.fallbacks = [F_UI2]
	F_D2.fallbacks = [F_UI]
	_bgm = AudioStreamPlayer.new()
	_bgm.volume_db = music_db
	add_child(_bgm)
	for i in 10:
		var ap := AudioStreamPlayer.new()
		ap.volume_db = sfx_db
		add_child(ap)
		_sfxp.append(ap)
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	_hud.draw.connect(_draw_hud)
	_setup_input()
	var demo := get_node_or_null("../BattleDemo")
	if demo:
		demo.set("running", false)     # the game drives the actors now
	_tmpl = get_node_or_null("../Actors/MagmaBeast") as Sprite3D
	if _tmpl:
		_tmpl.visible = false           # template for every monster (duplicated per battle)
	for h in D.HEROES:
		var n := get_node_or_null("../Actors/" + h["id"]) as Node3D
		if n:
			_home[h["id"]] = n.position
	save = SAVE.fresh() if reset_save else SAVE.load_game()
	if debug_level > 0:
		for id in save["heroes"]:
			save["heroes"][id]["lv"] = debug_level
	camp_stage = clampi(int(save.get("stage", 0)), 0, D.STAGES.size() - 1)
	var o: Dictionary = save.get("opt", {})
	auto_battle = bool(o.get("auto", auto_battle))
	battle_speed = float(o.get("speed", battle_speed))
	music_db = float(o.get("music", music_db))
	sfx_db = float(o.get("sfx", sfx_db))
	sysm = preload("res://scripts/system_menu.gd").new(self)
	await get_tree().process_frame
	_enter_camp()


func _setup_input() -> void:
	var map := {
		"m_up": [KEY_UP, KEY_W, JOY_BUTTON_DPAD_UP],
		"m_down": [KEY_DOWN, KEY_S, JOY_BUTTON_DPAD_DOWN],
		"m_left": [KEY_LEFT, KEY_A, JOY_BUTTON_DPAD_LEFT],
		"m_right": [KEY_RIGHT, KEY_D, JOY_BUTTON_DPAD_RIGHT],
		"m_cross": [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER, KEY_K, JOY_BUTTON_A],
		"m_circle": [KEY_L, JOY_BUTTON_B],
		"m_square": [KEY_J, JOY_BUTTON_X],
		"m_triangle": [KEY_I, JOY_BUTTON_Y],
		"m_back": [KEY_ESCAPE, KEY_BACKSPACE],
		"m_l1": [KEY_Q, JOY_BUTTON_LEFT_SHOULDER],
		"m_r1": [KEY_E, JOY_BUTTON_RIGHT_SHOULDER],
		"m_auto": [KEY_TAB, JOY_BUTTON_START],
		"m_speed": [KEY_F, JOY_BUTTON_BACK],
	}
	for a in map:
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a, 0.5)
		for code in map[a]:
			var ev: InputEvent
			if code < 32:   # small numbers are joypad buttons, keys are much larger
				ev = InputEventJoypadButton.new()
				ev.button_index = code
			else:
				ev = InputEventKey.new()
				ev.physical_keycode = code
			InputMap.action_add_event(a, ev)
	for pair in [["m_up", JOY_AXIS_LEFT_Y, -1.0], ["m_down", JOY_AXIS_LEFT_Y, 1.0], ["m_left", JOY_AXIS_LEFT_X, -1.0], ["m_right", JOY_AXIS_LEFT_X, 1.0]]:
		var jm := InputEventJoypadMotion.new()
		jm.axis = pair[1]
		jm.axis_value = pair[2]
		InputMap.action_add_event(pair[0], jm)


# ================================================================ helpers
func _hnode(h: Dictionary) -> Node3D:
	return get_node_or_null("../Actors/" + str(h["id"])) as Node3D


func _enode(e: Dictionary) -> Node3D:
	var n = e.get("node")
	return n if is_instance_valid(n) else null


func _unode(u: Dictionary) -> Node3D:
	return _hnode(u) if u["side"] == "h" else _enode(u)


func _alive_heroes() -> Array:
	return party.filter(func(h): return h["hp"] > 0)


func _alive_foes() -> Array:
	return foes.filter(func(e): return e["hp"] > 0)


func _target_foe() -> Dictionary:
	var al := _alive_foes()
	if al.is_empty():
		return {}
	if tgt < 0 or tgt >= foes.size() or foes[tgt]["hp"] <= 0:
		tgt = foes.find(al[0])
	return foes[tgt]


func _cycle_target(step: int) -> void:
	var al := _alive_foes()
	if al.size() < 2:
		return
	var i := al.find(_target_foe())
	tgt = foes.find(al[posmod(i + step, al.size())])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _root() -> Node:
	return get_tree().current_scene


func _el_col(el: String) -> Color:
	return D.EL_COL.get(el, C_INK)


func _stats(u: Dictionary) -> Dictionary:
	var s := {"str": float(u["str"]), "mag": float(u["mag"]), "def": float(u["def"]), "mdef": float(u["mdef"])}
	if u["status"].has("magup"):
		s["mag"] *= 1.5
	if u["status"].has("defdown"):
		s["def"] *= 0.5
		s["mdef"] *= 0.7
	return s


func _delay(u: Dictionary) -> float:
	var d: float = D.TUNE["TURN"] / maxf(float(u["spd"]), 1.0)
	if u["status"].has("slow"):
		d *= 1.5
	return d


func _mp_cost(m: Dictionary) -> int:
	var c := float(m.get("mp", 0)) * float(D.TUNE["MPX"])
	if mode == "battle" and not cur.is_empty() and cur.has("fx"):
		c *= float(cur["fx"].get("mpcut", 1.0))
	return int(ceil(c))


func _can_cast(h: Dictionary, m: Dictionary) -> String:
	if m.is_empty():
		return "ยังไม่ได้ตั้งเวท"
	if h["mp"] < _mp_cost(m):
		return "MP ไม่พอ"
	if m["tg"] == "revive" and party.filter(func(x): return x["hp"] <= 0).is_empty():
		return "ไม่มีเพื่อนที่ล้ม"
	if m.has("pow") and _alive_foes().is_empty():
		return "ไม่มีเป้าหมาย"
	return ""


func _set_magicks(h: Dictionary) -> Array:
	var out := []
	for mid in h["set"]:
		out.append(D.magick(h["id"], mid))
	return out


# ================================================================ camp
func _enter_camp() -> void:
	mode = "camp"
	state = ""
	_clear_foes()
	combo = {}
	menu_open = false
	Engine.time_scale = 1.0
	_music("camp")
	for h in D.HEROES:
		var n := get_node_or_null("../Actors/" + h["id"]) as Node3D
		if n:
			n.rotation = Vector3.ZERO
			if _home.has(h["id"]):
				n.set("_home", _home[h["id"]])
			n.call("play_row", 0)
	_preview_stage()


func _stage_open(i: int) -> bool:
	return i == 0 or (i - 1) in save["cleared"] or i in save["cleared"]


func _preview_stage() -> void:
	var ss := get_node_or_null("../StageSet")
	if ss:
		ss.set("stage", D.STAGES[camp_stage]["key"])


func _camp_hero_id() -> String:
	return D.HEROES[camp_hero]["id"]


func _camp_input(ev: InputEvent) -> void:
	if sysm.open:
		sysm.input(ev)
		return
	camp_focus = "stage"
	if ev.is_action_pressed("m_triangle"):
		sysm.show()
	elif ev.is_action_pressed("m_l1") or ev.is_action_pressed("m_r1"):
		camp_hero = posmod(camp_hero + (-1 if ev.is_action_pressed("m_l1") else 1), D.HEROES.size())
	elif ev.is_action_pressed("m_up", true) or ev.is_action_pressed("m_down", true):
		var st := -1 if ev.is_action_pressed("m_up", true) else 1
		camp_stage = clampi(camp_stage + st, 0, D.STAGES.size() - 1)
		_preview_stage()
	elif ev.is_action_pressed("m_cross"):
		_try_start(camp_stage)


func _try_start(i: int) -> void:
	if _stage_open(i):
		_sfx("confirm")
	if not _stage_open(i):
		_pop_screen("ยังไม่ปลดล็อก — ผ่านด่านก่อนหน้าก่อน", Vector2(380, 640), "txt")
		return
	_start_battle(i)


func _assign_slot(slot: int) -> void:
	var hid := _camp_hero_id()
	var hs: Dictionary = save["heroes"][hid]
	var m: Dictionary = D.MAGICKS[hid][camp_mag]
	if m["lv"] > int(hs["lv"]):
		_pop_screen("ปลดล็อกที่ Lv %d" % m["lv"], Vector2(1300, 600), "txt")
		return
	var st: Array = hs["set"]
	var old := st.find(m["id"])
	if old >= 0:
		st[old] = st[slot]
	st[slot] = m["id"]
	SAVE.save_game(save)
	_sfx("confirm")
	_pop_screen("SET  " + m["n"].to_upper(), Vector2(1300, 600), "txt")


# ================================================================ battle setup
func _start_battle(i: int) -> void:
	_bid += 1
	mode = "battle"
	state = "intro"
	stage_i = i
	camp_stage = i
	save["stage"] = i
	wave = 0
	now = 0.0
	turns = 0
	_exp_pool = 0
	combo = {}
	_pops.clear()
	Engine.time_scale = battle_speed
	_preview_stage()
	_music("battle")
	party.clear()
	for hd in D.HEROES:
		var hs: Dictionary = save["heroes"][hd["id"]]
		var lv := int(hs["lv"])
		var st := D.final_stats(hd["id"], hs)
		var h := {"side": "h", "id": hd["id"], "name": hd["name"], "short": hd["short"], "el": hd["el"], "lv": lv,
			"hp": st["mhp"], "mp": st["mmp"], "g": minf(3.0, float(st["fx"].get("g0", 0.0))), "status": {}, "set": hs["set"].duplicate(),
			"mags": D.magicks_at(hd["id"], lv), "next": 0.0}
		h.merge(st)
		party.append(h)
		var n := _hnode(h)
		if n:
			n.rotation = Vector3.ZERO
			n.set("_home", _home[h["id"]])
			n.call("play_row", 0)
	for h in party:
		h["next"] = _delay(h) * randf_range(0.15, 0.55)
	_spawn_wave(0)
	var stg: Dictionary = D.STAGES[i]
	_show_banner(stg["n"], "STAGE %d  ·  %s" % [i + 1, stg["th"]])
	await _wait(1.6)
	_show_banner("WAVE 1 / %d" % stg["waves"].size(), "เริ่มการต่อสู้")
	var bid := _bid
	await _wait(1.0)
	if bid != _bid:
		return
	_advance()


func _clear_foes() -> void:
	for e in foes:
		var n := _enode(e)
		if n:
			n.visible = false
			n.name = n.name + "_old"
			get_tree().create_timer(5.0, true, false, true).timeout.connect(n.queue_free)
	foes.clear()


func _spawn_wave(w: int) -> void:
	_clear_foes()
	wave = w
	var specs: Array = D.STAGES[stage_i]["waves"][w]
	var lv: int = D.STAGES[stage_i]["lv"]
	for s in specs.size():
		var e := D.make_enemy(specs[s], lv)
		e["slot"] = s
		e["next"] = now + _delay(e) * randf_range(0.35, 0.9)
		_exp_pool += int(e["exp"])
		foes.append(e)
		_spawn_node(e, s, specs.size())
	tgt = 0


func _spawn_node(e: Dictionary, slot: int, count: int) -> void:
	if _tmpl == null:
		return
	var m: Dictionary = D.MONS[e["el"]]
	var n := _tmpl.duplicate() as Sprite3D
	n.name = "Foe_%d_%d_%d" % [_bid, wave, slot]
	n.material_override = null
	n.texture = load("res://art/mon/mon_%s.png" % e["el"])
	n.hframes = 5
	n.vframes = 2
	n.frame = 0
	n.set("frames_in_row", 5)
	n.set("row", 0)
	n.set("idle_row", 0)
	n.set("fps", 7.0)
	var bb: Array = m["bb"]
	n.set("feet_x", int((bb[0] + bb[2]) / 2))
	n.set("feet_y", int(bb[3]))
	var p: Vector2 = SLOTS_1[count - 1][slot]
	var fs: int = m["fs"]
	var sc := (64.0 / fs) * (1.45 if e["boss"] else 1.15)
	if e["el"] == "Death":
		sc = 1.5
	n.scale = Vector3.ONE * sc
	n.position = Vector3(p.x, 0.0, p.y)
	n.rotation = Vector3.ZERO
	var aura := n.get_node_or_null("Aura")
	if aura:
		if EL.AURA.has(e["el"]):
			aura.set("element", e["el"])
		else:
			aura.visible = false
	n.visible = true
	_tmpl.get_parent().add_child(n)
	e["node"] = n
	e["sc"] = sc


# ================================================================ timeline
func _advance() -> void:
	if mode != "battle":
		return
	if _alive_heroes().is_empty():
		_defeat()
		return
	if _alive_foes().is_empty():
		if wave + 1 < D.STAGES[stage_i]["waves"].size():
			_next_wave()
		else:
			_victory()
		return
	var u := _next_unit()
	now = u["next"]
	_start_turn(u)


func _next_unit() -> Dictionary:
	var best := {}
	for u in _alive_heroes() + _alive_foes():
		if best.is_empty() or float(u["next"]) < float(best["next"]) - 0.0001:
			best = u
	return best


## Predicted turn order. The unit taking its turn now lands at now + delay * w.
func _timeline(count: int, w: float) -> Array:
	var sim := []
	for u in _alive_heroes() + _alive_foes():
		var t: float = u["next"]
		if is_same(u, cur) and state in ["command", "magicks", "combo", "acting"]:
			t = now + _delay(u) * w
		sim.append({"u": u, "t": t})
	var out := []
	if sim.is_empty():
		return out
	for k in count:
		var bi := 0
		for i in sim.size():
			if sim[i]["t"] < sim[bi]["t"] - 0.0001:
				bi = i
		var s: Dictionary = sim[bi]
		out.append({"u": s["u"]})
		s["t"] += _delay(s["u"])
	return out


func _preview_w() -> float:
	if state == "command":
		return [1.0, 1.0, 1.0, 0.7][cmd]
	if state == "magicks" and not cur.is_empty():
		var ms: Array = cur["mags"]
		if mag_i < ms.size():
			return float(ms[mag_i].get("w", 1.0))
	return 1.0


func _start_turn(u: Dictionary) -> void:
	cur = u
	turns += 1
	u["status"].erase("guard")
	var bid := _bid
	var alive_ok: bool = await _tick_status(u)
	if bid != _bid:
		return
	if not alive_ok:
		_end_turn(u, 0.6)
		return
	if u["side"] == "e":
		if u["broken"] > 0:
			u["broken"] = 0
			u["brk"] = u["mbrk"]
			_pop_world(_enode(u), "RECOVER", "", "txt")
			_act(u["name"] + "  ·  ยังมึนอยู่", true)
			_end_turn(u, 1.0)
			return
		_sfx("cursor", -2.0)
		_foe_turn(u)
		return
	u["mp"] = mini(u["mp"] + int(ceil(u["mmp"] * D.TUNE["MP_TURN"])), u["mmp"])
	var rg := float(u.get("fx", {}).get("regen", 0.0))
	if rg > 0.0 and u["hp"] < u["mhp"]:
		_heal(u, u["mhp"] * rg)
	cmd = 0
	mag_i = 0
	mag_top = 0
	cmb_sel = -1
	_target_foe()
	_sfx("change", -2.0)
	state = "command"
	_auto_wait = 0.7


## Status effects at the start of a turn. Returns false if the unit fell.
func _tick_status(u: Dictionary) -> bool:
	var st: Dictionary = u["status"]
	var n := _unode(u)
	for k in st.keys():
		if k in ["burn", "poison"]:
			var r := 0.06 if u["side"] == "h" else (0.03 if u.get("boss", false) else 0.05)
			var d := maxi(1, int(u["mhp"] * r))
			u["hp"] = maxi(u["hp"] - d, 0)
			if n:
				n.call("hit", Color(1, 0.4, 0.1) if k == "burn" else Color(0.6, 0.3, 1))
			_pop_world(n, str(d), k.to_upper(), "hurt")
			await _wait(0.35)
		elif k == "regen" and u["hp"] > 0:
			_heal(u, u["mhp"] * 0.08)
			await _wait(0.25)
		st[k] = int(st[k]) - 1
		if st[k] <= 0:
			st.erase(k)
	if u["hp"] <= 0:
		if u["side"] == "h":
			_ko_hero(u)
		else:
			_ko_enemy(u)
		return false
	return true


func _end_turn(u: Dictionary, w: float) -> void:
	if mode != "battle" or state in ["win", "lose"]:
		return
	u["next"] = now + _delay(u) * w
	state = "wait"
	var bid := _bid
	await _wait(0.4)
	if bid != _bid or mode != "battle":
		return
	_advance()


func _next_wave() -> void:
	state = "wait"
	for h in _alive_heroes():
		_heal(h, h["mhp"] * D.TUNE["WAVE_HEAL"], true)
		h["mp"] = mini(h["mp"] + int(h["mmp"] * D.TUNE["WAVE_HEAL"]), h["mmp"])
	var bid := _bid
	await _wait(0.8)
	if bid != _bid:
		return
	_spawn_wave(wave + 1)
	var n: int = D.STAGES[stage_i]["waves"].size()
	_show_banner("WAVE %d / %d" % [wave + 1, n], "ฟื้น HP / MP 20%" if wave + 1 < n else "BOSS")
	if wave + 1 >= n:
		_music("boss")
		_sfx("ult", -4.0)
	else:
		_sfx("confirm")
	await _wait(1.4)
	_advance()


# ================================================================ input
func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion or ev is InputEventMouseButton:
		_mouse(ev)
		return
	if menu_open:
		_menu_input(ev)
		return
	if ev.is_action_pressed("m_auto"):
		if mode == "battle" and not state in ["win", "lose", "intro"]:
			_open_menu()
		else:
			auto_battle = not auto_battle
			_pop_screen("AUTO " + ("ON" if auto_battle else "OFF"), Vector2(960, 230), "txt")
		return
	if ev.is_action_pressed("m_speed"):
		battle_speed = 2.0 if battle_speed < 2.0 else 1.0
		if mode == "battle":
			Engine.time_scale = battle_speed
		_pop_screen("SPEED ×%d" % int(battle_speed), Vector2(960, 230), "txt")
		return
	if ev.is_action_pressed("m_up", true) or ev.is_action_pressed("m_down", true) or ev.is_action_pressed("m_left", true) or ev.is_action_pressed("m_right", true) or ev.is_action_pressed("m_l1") or ev.is_action_pressed("m_r1"):
		_sfx("cursor", -8.0)
	elif ev.is_action_pressed("m_back") or (ev.is_action_pressed("m_circle") and state != "combo"):
		_sfx("cancel", -4.0)
	if mode == "camp":
		_camp_input(ev)
		return
	if mode != "battle":
		return
	if state == "win" or state == "lose":
		if ev.is_action_pressed("m_cross"):
			_result_continue(true)
		elif ev.is_action_pressed("m_circle") or ev.is_action_pressed("m_back"):
			_result_continue(false)
		return
	if auto_battle:
		return
	if state in ["command", "magicks", "combo"]:
		if ev.is_action_pressed("m_l1"):
			_cycle_target(-1)
		elif ev.is_action_pressed("m_r1"):
			_cycle_target(1)
	match state:
		"command":
			if ev.is_action_pressed("m_up", true): cmd = posmod(cmd - 1, COMMANDS.size())
			elif ev.is_action_pressed("m_down", true): cmd = posmod(cmd + 1, COMMANDS.size())
			elif ev.is_action_pressed("m_left", true): _cycle_target(-1)
			elif ev.is_action_pressed("m_right", true): _cycle_target(1)
			elif ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]: _choose_command(cmd)
			elif ev.is_action_pressed("m_square"): _choose_command(0)
			elif ev.is_action_pressed("m_triangle"): _choose_command(1)
			elif ev.is_action_pressed("m_circle"): _choose_command(2)
			elif ev.is_action_pressed("m_cross"): _choose_command(3)
		"magicks":
			var n: int = cur["mags"].size()
			if ev.is_action_pressed("m_up", true): _mag_move(-1, n)
			elif ev.is_action_pressed("m_down", true): _mag_move(1, n)
			elif ev.is_action_pressed("m_left", true): _cycle_target(-1)
			elif ev.is_action_pressed("m_right", true): _cycle_target(1)
			elif ev.is_action_pressed("m_cross"): _cast_from_list(mag_i)
			elif ev.is_action_pressed("m_circle") or ev.is_action_pressed("m_back"): state = "command"
		"combo":
			if ev.is_action_pressed("m_left"): cmb_sel = 0
			elif ev.is_action_pressed("m_up"): cmb_sel = 1
			elif ev.is_action_pressed("m_right"): cmb_sel = 2
			elif ev.is_action_pressed("m_square"): _combo_cast(0)
			elif ev.is_action_pressed("m_triangle"): _combo_cast(1)
			elif ev.is_action_pressed("m_circle"): _combo_cast(2)
			elif ev.is_action_pressed("m_cross") or ev.is_action_pressed("m_back"): _combo_cancel()


func _mag_move(s: int, n: int) -> void:
	mag_i = posmod(mag_i + s, n)
	if mag_i < mag_top:
		mag_top = mag_i
	elif mag_i >= mag_top + 6:
		mag_top = mag_i - 5


func _mouse(ev: InputEvent) -> void:
	var p: Vector2 = ev.position / _sc
	var hit := ""
	for i in range(_hits.size() - 1, -1, -1):
		if (_hits[i][0] as Rect2).has_point(p):
			hit = _hits[i][1]
			break
	var click: bool = ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT
	if hit != _hover and hit != "" and not click:
		_sfx("cursor", -10.0)
	if hit != _hover or click:
		_hover = hit
		if hit != "":
			_mouse_hit(hit, click)


func _mouse_hit(id: String, click: bool) -> void:
	var parts := id.split(":")
	var k := parts[0]
	var i := int(parts[1]) if parts.size() > 1 else 0
	if mode == "camp" and sysm.open:
		if k.begins_with("sm_"):
			sysm.mouse(k, i, click)
		return
	if k == "sysm":
		if click and mode == "camp":
			sysm.show()
		return
	if k == "opt":
		if click and mode == "battle" and not state in ["win", "lose", "intro"]:
			_open_menu()
		return
	if menu_open:
		if k == "menu":
			menu_i = i
			if click:
				_menu_pick(i)
		return
	if mode == "camp":
		match k:
			"stage":
				camp_focus = "stage"
				if camp_stage != i:
					camp_stage = i
					_preview_stage()
				if click:
					_try_start(i)
			"hero":
				if click:
					camp_hero = i
					camp_mag = 0
					camp_focus = "party"
			"cmag", "slot":
				if click:
					sysm.page = 1
					sysm.hero = camp_hero
					sysm.show()
		return
	if state == "win" or state == "lose":
		if click and k == "res":
			_result_continue(i == 1)
		return
	if auto_battle:
		return
	match k:
		"tgt":
			if click and state in ["command", "magicks", "combo"]:
				tgt = i
		"cmd":
			if state in ["command", "magicks"]:
				if state == "command":
					cmd = i
				if click:
					state = "command"
					cmd = i
					_choose_command(i)
		"mag":
			if state == "magicks":
				mag_i = i
				if click:
					_cast_from_list(i)
		"cmb":
			if state == "combo":
				cmb_sel = i
				if click:
					_combo_cast(i)
		"cmbx":
			if click and state == "combo":
				_combo_cancel()


func _process(delta: float) -> void:
	_t = Time.get_ticks_msec() / 1000.0
	_update_glow()
	_update_cfx(delta)
	if mode == "battle" and auto_battle and not menu_open and state in ["command", "magicks", "combo"]:
		_auto_wait -= delta
		if _auto_wait <= 0.0:
			_auto_step()
	_hud.queue_redraw()


# ================================================================ hero commands
func _choose_command(i: int) -> void:
	_sfx("confirm")
	match i:
		0: _do_attack()
		1:
			state = "magicks"
			mag_i = clampi(mag_i, 0, cur["mags"].size() - 1)
		2: _enter_combo()
		3: _do_defend()


func _do_attack() -> void:
	var h := cur
	var e := _target_foe()
	if e.is_empty():
		return
	state = "acting"
	_act(h["name"] + "  ·  ATTACK", false)
	var hn := _hnode(h)
	var en := _enode(e)
	var home: Vector3 = _home[h["id"]]
	var to := Vector3(en.position.x - 1.3, home.y, lerpf(home.z, en.position.z, 0.7)) if en else home
	await _slide(hn, home, to, 0.22)
	hn.call("play_row", 1, 14.0, true)
	_sfx("attack")
	await _wait(0.2)
	if not is_instance_valid(en):
		return
	_sfx("hit")
	var at := en.global_position + Vector3(0, 0.8, 0.3)
	KIT.impact_light(_root(), at + Vector3(0, 0.2, 0.5), _el_col(h["el"]), 3.5, 5.0, 0.4)
	KIT.sprite_hit(_root(), at, h["el"], 0.75)
	KIT.shake(_root(), 0.5)
	en.call("hit", Color(1, 1, 1))
	var r := _hit_enemy(h, e, D.TUNE["ATK_POW"], "None", "phys", {"attack": true})
	if not r.get("miss", false):
		_gain(h, D.TUNE["G_ATTACK"])
	h["mp"] = mini(h["mp"] + int(ceil(h["mmp"] * D.TUNE["MP_ATTACK"] * float(h["fx"].get("mpatk", 1.0)))), h["mmp"])
	await _wait(0.25)
	await _slide(hn, to, home, 0.25)
	_end_turn(h, 1.0)


func _do_defend() -> void:
	var h := cur
	state = "acting"
	h["status"]["guard"] = 1
	_act(h["name"] + "  ·  DEFEND", false)
	_pop_world(_hnode(h), "GUARD", "", "heal")
	h["mp"] = mini(h["mp"] + int(ceil(h["mmp"] * D.TUNE["MP_DEFEND"])), h["mmp"])
	_gain(h, D.TUNE["G_DEFEND"])
	var hn := _hnode(h)
	KIT.impact_light(_root(), hn.global_position + Vector3(0, 1, 0.5), _el_col(h["el"]), 2.5, 3.5, 0.6)
	await _wait(0.7)
	_end_turn(h, 0.7)


func _cast_from_list(i: int) -> void:
	var h := cur
	var m: Dictionary = h["mags"][i]
	var why := _can_cast(h, m)
	if why != "":
		_deny(why)
		return
	state = "acting"
	h["mp"] -= _mp_cost(m)
	await _exec_magick(h, m, -1)
	_end_turn(h, float(m.get("w", 1.0)))


func _enter_combo() -> void:
	var h := cur
	if h["g"] < D.TUNE["COMBO_MIN"] - 0.001:
		_deny("เกจคอมโบไม่พอ (ต้องมี %d ช่อง)" % D.TUNE["COMBO_MIN"])
		return
	if not _combo_any(h):
		_deny("MP ไม่พอสำหรับเวทคอมโบ")
		return
	combo = {"step": 0, "full": h["g"] >= 2.999, "max": mini(3, int(floor(h["g"] + 0.001))), "seq": []}
	cmb_sel = -1
	state = "acting"
	_act(h["name"] + ("  ·  FULL COMBO" if combo["full"] else "  ·  COMBO"), false)
	_sfx("special")
	_flash_screen(C_PINK if combo["full"] else C_ACC)
	await _combo_step_in(h)
	if combo.is_empty() or mode != "battle":
		return
	state = "combo"
	_auto_wait = 0.6


## the hero dashes out to stand in front of the target for the whole combo
func _combo_step_in(h: Dictionary) -> void:
	var hn := _hnode(h)
	var e := _target_foe()
	var en := _enode(e) if not e.is_empty() else null
	if hn == null or en == null:
		return
	var off := Vector3(-1.7, 0.0, 0.5)
	var cc := get_tree().get_first_node_in_group("combo_cinematic")
	if cc:
		off = cc.get("hero_offset")
	var from: Vector3 = hn.get("_home")
	var to := en.position + off * Vector3(1, 1, 1)
	to.y = from.y
	combo["home"] = _home[h["id"]]
	hn.call("play_row", 2, 12.0, false)
	await _slide(hn, from, to, 0.28)
	hn.call("play_row", 0)


func _combo_step_out(h: Dictionary) -> void:
	var hn := _hnode(h)
	if hn == null:
		return
	await _slide(hn, hn.get("_home"), _home[h["id"]], 0.3)


func _combo_cast(slot: int) -> void:
	var h := cur
	var m: Dictionary = _set_magicks(h)[slot]
	cmb_sel = slot
	var why := _can_cast(h, m)
	if why != "":
		_deny(why)
		return
	state = "acting"
	h["mp"] -= _mp_cost(m)
	h["g"] = maxf(h["g"] - 1.0, 0.0)
	combo["seq"].append(slot)
	var bid := _bid
	await _exec_magick(h, m, int(combo["step"]))
	if bid != _bid or mode != "battle" or combo.is_empty():
		return
	combo["step"] = int(combo["step"]) + 1
	if _alive_foes().is_empty() or h["g"] < 0.999 or combo["step"] >= 3 or not _combo_any(h) or h["hp"] <= 0:
		_combo_finish()
	else:
		state = "combo"
		_auto_wait = 0.5


func _combo_any(h: Dictionary) -> bool:
	for mm in _set_magicks(h):
		if _can_cast(h, mm) == "":
			return true
	return false


func _combo_cancel() -> void:
	if int(combo.get("step", 0)) == 0:
		combo = {}
		state = "acting"
		await _combo_step_out(cur)
		if mode == "battle" and state == "acting":
			state = "command"
		return
	_combo_finish()


func _combo_finish() -> void:
	var h := cur
	state = "acting"
	var n := int(combo.get("step", 0))
	var seq: Array = combo.get("seq", [])
	var bid := _bid
	if n >= 2:
		_pop_world(_hnode(h), "%d-HIT COMBO" % n, "", "cmbd")
	var f := D.finisher_for(seq) if seq.size() == 3 else {}
	if not f.is_empty() and not _alive_foes().is_empty() or (not f.is_empty() and f["kind"] in ["heal", "aegis", "mana"]):
		combo["fin"] = f
		await _wait(0.35)
		if bid != _bid:
			return
		await _exec_finisher(h, f)
		if bid != _bid:
			return
	elif seq.size() == 3:
		combo["fin"] = {"n": "-"}
	await _combo_step_out(h)
	if bid != _bid:
		return
	combo = {}
	_end_turn(h, 1.0)


func _combo_pow(step: int) -> float:
	var p: float = D.TUNE["COMBO_POW"][clampi(step, 0, 2)]
	if combo.get("full", false):
		p *= 1.0 + float(D.TUNE["FULL_BONUS"])
	if not cur.is_empty() and cur.has("fx"):
		p *= float(cur["fx"].get("cpow", 1.0))
	return p


## FINISHER — fired when a 3-spell combo matches a button pattern (mancer_data.gd → FINISHERS)
func _exec_finisher(h: Dictionary, f: Dictionary) -> void:
	var fm: float = float(h.get("fx", {}).get("fin", 1.0)) * _combo_pow(2)
	var col := _el_col(h["el"])
	_sfx("ult")
	_show_banner("FINISHER · " + f["n"], f["th"], C_GOLD)
	_flash_screen(C_GOLD)
	var hn := _hnode(h)
	hn.call("play_row", 1, 12.0, true)
	KIT.dim_sun(_root(), 0.6)
	await _wait(0.45)
	match f["kind"]:
		"aoe", "single", "hex", "break":
			var targets: Array = _alive_foes() if f["kind"] == "aoe" else [_target_foe()]
			KIT.shake(_root(), 2.0)
			for e in targets:
				if e.is_empty() or e["hp"] <= 0:
					continue
				var en := _enode(e)
				if en == null:
					continue
				var at := en.global_position + Vector3(0, 0.9, 0.3)
				KIT.impact_light(_root(), at + Vector3(0, 0.3, 0.6), col, 9.0, 8.0, 0.7)
				KIT.sprite_hit(_root(), at, h["el"], 2.0)
				KIT.ground_glow(_root(), at, col, 3.0, 4.0, 1.2)
				_sfx("hit_" + h["el"])
				en.call("hit", col)
				if f["kind"] == "break" and e["broken"] == 0:
					e["brk"] = 0.0
				_hit_enemy(h, e, float(f.get("pow", 1.0)) * fm, h["el"], "mag", {"combo": true, "fusion": false, "cp": fm, "brk": 10.0 if f["kind"] == "break" else 1.0})
				if f["kind"] == "hex" and e["hp"] > 0:
					_apply_status(e, {"defdown": 3, "slow": 2})
				await _wait(0.12)
		"heal", "aegis", "mana":
			for a in _alive_heroes():
				var an := _hnode(a)
				var at := an.global_position + Vector3(0, 0.9, 0.3)
				KIT.impact_light(_root(), at + Vector3(0, 0.3, 0.4), col.lerp(Color.WHITE, 0.5), 4.0, 4.0, 0.7)
				KIT.motes(_root(), at, {"color": col.lerp(Color(0.7, 1, 0.8), 0.5), "glow": 2.4, "motion": "pop", "amount": 20, "tex": "dot"}, 0.6)
				if f["kind"] == "heal":
					_heal(a, a["mhp"] * float(f["heal"]) * float(h.get("fx", {}).get("fin", 1.0)))
					_apply_status(a, {"regen": 3})
				elif f["kind"] == "aegis":
					_apply_status(a, {"protect": 3, "shell": 3})
				else:
					a["mp"] = mini(a["mp"] + int(a["mmp"] * 0.25), a["mmp"])
					_pop_world(an, "MP +25%", "", "heal")
					if not is_same(a, h):
						_gain(a, 1.0)
			_sfx("special")
		"time":
			for e in _alive_foes():
				e["next"] = maxf(e["next"], now) + _delay(e) * 0.8
				_pop_world(_enode(e), "DELAY", "", "txt")
			KIT.shake(_root(), 1.0)
	await _wait(0.9)


# ================================================================ magick execution
func _exec_magick(h: Dictionary, m: Dictionary, step: int) -> void:
	var cp := _combo_pow(step) if step >= 0 else 1.0
	_act(m["n"].to_upper() + ("  ·  COMBO %d  ×%.2f" % [step + 1, cp] if step >= 0 else ""), false)
	var hn := _hnode(h)
	var col := _el_col(m["el"])
	if m.has("pow"):
		var targets: Array = _alive_foes() if m["tg"] == "all" else [_target_foe()]
		var sc = hn.get_node("SpellCaster")
		var first := _enode(targets[0])
		sc.set("element", h["el"])
		sc.set("target", sc.get_path_to(first))
		var ct0: float = sc.get("charge_time")
		sc.set("charge_time", 0.32 if step > 0 else (0.5 if step == 0 else ct0))
		_sfx("cast_" + h["el"], -6.0)
		await sc.cast_part()
		sc.set("charge_time", ct0)
		_sfx("hit_" + h["el"])
		var sp := EL.spell(h["el"])
		var any_weak := false
		var i := 0
		for e in targets:
			if e["hp"] <= 0:
				continue
			if i > 0:
				await _wait(0.1)
			i += 1
			var en := _enode(e)
			if en == null:
				continue
			sc.call("_impact", en.global_position + Vector3(0, 0.75, 0.3), sp["color"], sp)
			var hits: int = m.get("hits", 1)
			for k in hits:
				if e["hp"] <= 0:
					break
				if k > 0:
					await _wait(0.16)
					KIT.sprite_hit(_root(), en.global_position + Vector3(0, 0.8, 0.3), h["el"], 0.6)
				en.call("hit", sp["color"])
				var r := _hit_enemy(h, e, float(m["pow"]) * cp, m["el"], m.get("k", "mag"), {"combo": step >= 0, "brk": m.get("brk", 1.0), "cp": cp})
				if r.get("weak", false):
					any_weak = true
				if m.has("drain") and r.get("d", 0) > 0:
					_heal(h, r["d"] * float(m["drain"]))
			if e["hp"] > 0 and m.has("st"):
				_apply_status(e, m["st"])
			if e["hp"] > 0:
				await _mark_or_fuse(h, e, m["el"], cp)
		if step < 0:
			_gain(h, D.TUNE["G_MAGICK"] + (D.TUNE["G_WEAK"] if any_weak else 0.0))
	else:
		hn.call("play_row", 2, 10.0, false)
		KIT.impact_light(_root(), hn.global_position + Vector3(0.6, 0.8, 0.4), col, 2.0, 3.0, 0.5)
		await _wait(0.4 if step >= 0 else 0.65)
		hn.call("play_row", 1, 12.0, true)
		_sfx("cast_" + h["el"], -6.0)
		await _wait(0.2)
		var allies: Array = []
		match m["tg"]:
			"self": allies = [h]
			"party": allies = _alive_heroes()
			"ally":
				var al := _alive_heroes()
				al.sort_custom(func(a, b): return float(a["hp"]) / a["mhp"] < float(b["hp"]) / b["mhp"])
				allies = [al[0]]
			"revive": allies = party.filter(func(x): return x["hp"] <= 0).slice(0, 1)
		for a in allies:
			var an := _hnode(a)
			var at := an.global_position + Vector3(0, 0.9, 0.3)
			KIT.impact_light(_root(), at + Vector3(0, 0.3, 0.4), col.lerp(Color.WHITE, 0.4), 3.0, 3.5, 0.6)
			KIT.motes(_root(), at, {"color": col.lerp(Color(0.7, 1, 0.8), 0.5 if m.has("heal") else 0.0), "glow": 2.2, "motion": "pop" if m.has("heal") else "swirl", "amount": 14, "tex": "dot"}, 0.6)
			if m["tg"] == "revive":
				_revive(a, float(m["heal"]))
			elif m.has("heal"):
				_heal(a, a["mhp"] * float(m["heal"]) * cp)
			if m.has("buff"):
				var b: Dictionary = m["buff"].duplicate()
				if step >= 1:
					for bk in b:
						b[bk] = int(b[bk]) + 1     # later combo steps last a turn longer
				_apply_status(a, b)
		if step < 0:
			_gain(h, D.TUNE["G_MAGICK"])
	await _wait(0.3 if step >= 0 else 0.45)


## element marks: a Magick leaves its element on the enemy; a different one on top fuses.
func _mark_or_fuse(h: Dictionary, e: Dictionary, el: String, cp: float) -> void:
	var mk: String = e["mark"]
	if mk != "" and mk != el:
		var f := D.fuse(mk, el)
		if f != "":
			e["mark"] = ""
			await _wait(0.25)
			var en := _enode(e)
			if en == null or e["hp"] <= 0:
				return
			var at := en.global_position + Vector3(0, 0.8, 0.3)
			if f == "Magma":
				KIT.lava(_root(), at, EL.combo("Lava"))
			elif f == "Steam":
				KIT.steam(_root(), at, EL.combo("Steam"))
			else:
				KIT.impact_light(_root(), at + Vector3(0, 0.3, 0.5), _el_col(f), 7.0, 7.0, 0.6)
				KIT.sprite_hit(_root(), at, f, 1.6)
				KIT.shake(_root(), 1.4)
			_sfx("special")
			_sfx("hit_" + f)
			_show_banner("FUSION · " + f.to_upper(), D.EL_TH[mk] + " + " + D.EL_TH[el] + " = " + D.EL_TH[f], _el_col(f))
			en.call("hit", _el_col(f))
			_hit_enemy(h, e, float(D.TUNE["FUSE_POW"]) * cp, f, "mag", {"combo": true, "fusion": true, "cp": 1.0})
			await _wait(0.5)
			return
	e["mark"] = el


func _hit_enemy(h: Dictionary, e: Dictionary, pw: float, el: String, k: String, o: Dictionary) -> Dictionary:
	if e["hp"] <= 0:
		return {"d": 0}
	var en := _enode(e)
	var s := _stats(h)
	var es := _stats(e)
	if k == "phys" and h["status"].has("blind") and randf() < 0.5:
		_pop_world(en, "MISS", "", "res")
		return {"d": 0, "miss": true}
	var atk: float = s["str"] if k == "phys" else s["mag"]
	var df: float = es["def"] if k == "phys" else es["mdef"]
	var mr := D.mult_raw(el, e["el"])
	var mm := D.mult(el, e["el"])
	var d: float = atk * pw * D.TUNE["DMG"] * 60.0 / (60.0 + df) * mr * randf_range(0.92, 1.08)
	if el != "None" and mm == 1.0:
		d *= D.TUNE["NEU"] / maxf(0.8, mr)
	if e["broken"] > 0:
		d *= D.TUNE["BRK_DMG"]
	if el != "None":
		d *= float(h.get("fx", {}).get("eldmg", 1.0))
	var dmg := maxi(1, int(round(d)))
	e["hp"] = maxi(e["hp"] - dmg, 0)
	# what the player has learned about this monster
	if el != "None" and not e["known"].has(el):
		e["known"][el] = mm
		if mm != 1.0:
			_show_info("%s %s ธาตุ%s" % [e["name"], "แพ้ทาง" if mm > 1.0 else "ต้านทาน", D.EL_TH.get(el, el)])
	# break gauge
	if e["broken"] == 0:
		var b := 0.0
		if o.get("attack", false):
			b = D.TUNE["BRK_ATK"]
		elif o.get("combo", false):
			b = D.TUNE["COMBO_BRK"]
		else:
			b = D.TUNE["BRK_MAG"]
		b *= float(o.get("brk", 1.0))
		var bm := D.mult(h["el"] if o.get("attack", false) else el, e["el"])
		b *= D.TUNE["BRK_W"] if bm >= 2.0 else (D.TUNE["BRK_R"] if bm < 1.0 else D.TUNE["BRK_N"])
		e["brk"] = maxf(e["brk"] - b, 0.0)
		if e["brk"] <= 0.0 and e["hp"] > 0:
			e["broken"] = 1
			e["next"] = maxf(e["next"], now) + _delay(e) * 0.5
			_sfx("stun")
			_show_banner("BREAK!", e["name"] + " เสียเทิร์นถัดไป · ดาเมจ ×1.5", C_BRK)
			_pop_world(en, "BREAK", "", "boost")
	if not o.get("combo", false):
		_gain(h, minf(D.TUNE["G_DEALT_MAX"], float(dmg) / e["mhp"] * D.TUNE["G_DEALT"]))
	var kind := "weak" if mm >= 2.0 else ("res" if mm < 1.0 else ("cmbd" if o.get("combo", false) else ""))
	var sub := ""
	if o.get("fusion", false):
		sub = "FUSION"
	elif mm >= 2.0:
		sub = "WEAK"
	elif mm < 1.0:
		sub = "RESIST"
	elif o.get("combo", false):
		sub = "COMBO ×%.2f" % float(o.get("cp", 1.0))
	_pop_world(en, str(dmg), sub, kind)
	if e["hp"] <= 0:
		_ko_enemy(e)
	return {"d": dmg, "weak": mm >= 2.0}


func _apply_status(u: Dictionary, st: Dictionary) -> void:
	var n := _unode(u)
	for k in st:
		if k == "stun":
			var x := 0.3 if u.get("boss", false) else 0.6
			u["next"] = maxf(u["next"], now) + _delay(u) * x
			_pop_world(n, "STUN", "", "txt")
			continue
		u["status"][k] = maxi(int(u["status"].get(k, 0)), int(st[k]))
		_pop_world(n, D.STATUS_TH.get(k, k.to_upper()), "", "heal" if not k in D.BAD else "txt")


func _heal(u: Dictionary, amt: float, quiet := false) -> void:
	if u["hp"] <= 0:
		return
	var a := mini(int(round(amt)), u["mhp"] - u["hp"])
	u["hp"] += a
	if a > 0 and not quiet:
		_pop_world(_unode(u), "+%d" % a, "", "heal")


func _gain(h: Dictionary, g: float) -> void:
	if h["side"] != "h" or h["hp"] <= 0:
		return
	var old: float = h["g"]
	g *= float(h.get("fx", {}).get("gauge", 1.0))
	h["g"] = minf(3.0, old + g)
	if int(old + 0.001) < int(h["g"] + 0.001) and int(h["g"] + 0.001) >= D.TUNE["COMBO_MIN"]:
		_pop_world(_hnode(h), "COMBO MAX" if h["g"] >= 2.999 else "COMBO READY", "", "boost")


func _ko_enemy(e: Dictionary) -> void:
	var n := _enode(e)
	if n == null:
		return
	_sfx("ko", -3.0)
	n.call("hit", Color(1, 1, 1))
	var aura := n.get_node_or_null("Aura")
	if aura:
		aura.visible = false
	var sc: float = e.get("sc", 1.0)
	var tw := n.create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(n, "scale", Vector3(sc * 1.35, 0.02, sc), 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): n.visible = false)
	KIT.motes(_root(), n.global_position + Vector3(0, 0.6, 0.2), {"color": _el_col(e["el"]), "glow": 2.0, "motion": "pop", "amount": 18, "tex": "dot"}, 0.0)


func _ko_hero(h: Dictionary) -> void:
	h["hp"] = 0
	h["status"] = {}
	var n := _hnode(h)
	_pop_world(n, "KO", "", "hurt")
	if n:
		n.create_tween().tween_property(n, "rotation:z", PI * 0.5, 0.35).set_ease(Tween.EASE_OUT)


func _revive(h: Dictionary, r: float) -> void:
	h["hp"] = maxi(1, int(h["mhp"] * r))
	h["next"] = now + _delay(h) * 0.5
	var n := _hnode(h)
	_pop_world(n, "REVIVE", "", "heal")
	if n:
		n.create_tween().tween_property(n, "rotation:z", 0.0, 0.3)


func _slide(n: Node3D, a: Vector3, b: Vector3, t: float) -> void:
	if n == null:
		return
	var tw := n.create_tween()
	tw.tween_method(func(v: Vector3): n.set("_home", v), a, b, t).set_trans(Tween.TRANS_SINE)
	await tw.finished


# ================================================================ enemies
func _foe_turn(e: Dictionary) -> void:
	state = "foe"
	await _wait(0.35)
	e["turns"] = int(e["turns"]) + 1
	var t: Dictionary = D.MONS[e["el"]]
	var heroes := _alive_heroes()
	if heroes.is_empty():
		_end_turn(e, 1.0)
		return
	var target: Dictionary = heroes.pick_random()
	if randf() < 0.35:
		heroes.sort_custom(func(a, b): return a["hp"] < b["hp"])
		target = heroes[0]
	var en := _enode(e)
	if e["boss"] and e["turns"] % 4 == 0:
		_show_banner(e["name"], "ULTIMATE · โจมตีทั้งปาร์ตี้", C_BAD)
		_sfx("ult")
		_act(e["name"] + "  ·  ULTIMATE", true)
		var aura := en.get_node_or_null("Aura") as OmniLight3D
		if aura and aura.visible:
			var tw := aura.create_tween()
			tw.tween_property(aura, "light_energy", 6.0, 0.4)
			tw.tween_property(aura, "light_energy", 0.9, 0.6)
		en.call("play_row", 1, 9.0, true)
		await _wait(0.7)
		KIT.dim_sun(_root(), 0.5)
		KIT.shake(_root(), 1.6)
		for h in _alive_heroes():
			_foe_impact(e, h, 0.8, "mag", e["el"], {})
			await _wait(0.12)
		await _wait(0.9)
	elif e["turns"] % 3 == 0:
		_act(str(t["sk"]).to_upper(), true)
		await _foe_strike(e, target, 1.25, t["sk_k"], e["el"], t.get("st", {}), int(t.get("hits", 1)))
	else:
		_act(e["name"] + "  ·  ATTACK", true)
		await _foe_strike(e, target, 1.0, "phys", "None", {}, 1)
	_end_turn(e, 1.0)


func _foe_strike(e: Dictionary, h: Dictionary, pw: float, k: String, el: String, st: Dictionary, hits: int) -> void:
	var en := _enode(e)
	var hn := _hnode(h)
	var home: Vector3 = en.get("_home")
	var to := home + Vector3(-1.1, 0, 0)
	await _slide(en, home, to, 0.18)
	en.call("play_row", 1, 10.0, true)
	await _wait(0.3)
	for i in hits:
		if h["hp"] <= 0:
			break
		_foe_impact(e, h, pw, k, el, st if i == hits - 1 else {})
		await _wait(0.22)
	await _wait(0.2)
	await _slide(en, to, home, 0.22)
	await _wait(0.3)


func _foe_impact(e: Dictionary, h: Dictionary, pw: float, k: String, el: String, st: Dictionary) -> void:
	var hn := _hnode(h)
	var vel: String = e["el"] if el == "None" else el
	var at := hn.global_position + Vector3(0, 0.9, 0.3)
	var col := _el_col(vel)
	KIT.impact_light(_root(), at + Vector3(0, 0.2, 0.5), col, 5.0, 5.5, 0.5)
	KIT.sprite_hit(_root(), at, vel, 0.75)
	KIT.shake(_root(), 0.7)
	hn.call("hit", col)
	if k == "phys" and e["status"].has("blind") and randf() < 0.5:
		_pop_world(hn, "MISS", "", "res")
		return
	var es := _stats(e)
	var hs := _stats(h)
	var atk: float = es["str"] if k == "phys" else es["mag"]
	var df: float = hs["def"] if k == "phys" else hs["mdef"]
	var d: float = atk * pw * D.TUNE["EDMG"] * 60.0 / (60.0 + df) * D.mult_def(el, h["el"]) * randf_range(0.9, 1.1)
	var tag := ""
	if k == "phys" and h["status"].has("protect"):
		d *= 0.5
		tag = "PROTECT"
	if k == "mag" and h["status"].has("shell"):
		d *= 0.5
		tag = "SHELL"
	if h["status"].has("guard"):
		d *= 0.5
		tag = "GUARD"
	var dmg := maxi(1, int(round(d)))
	_sfx("hurt", -3.0)
	h["hp"] = maxi(h["hp"] - dmg, 0)
	_pop_world(hn, str(dmg), tag, "hurt")
	_gain(h, float(dmg) / h["mhp"] * D.TUNE["G_TAKEN"])
	if h["hp"] <= 0:
		_ko_hero(h)
	elif not st.is_empty():
		_apply_status(h, st)


# ================================================================ results
func _victory() -> void:
	state = "win"
	combo = {}
	Engine.time_scale = 1.0
	_music("")
	_sfx("special")
	for h in _alive_heroes():
		_hnode(h).call("play_row", 1, 10.0, true)
	if not stage_i in save["cleared"]:
		save["cleared"].append(stage_i)
	var rows := []
	for h in party:
		var hs: Dictionary = save["heroes"][h["id"]]
		var gain := _exp_pool if h["hp"] > 0 else _exp_pool / 2
		var lv0 := int(hs["lv"])
		var xp := int(hs["exp"]) + gain
		var lv := lv0
		while lv < D.MAX_LV and xp >= D.exp_need(lv):
			xp -= D.exp_need(lv)
			lv += 1
		var learned := []
		for m in D.MAGICKS[h["id"]]:
			if m["lv"] > lv0 and m["lv"] <= lv:
				learned.append(m["n"])
		hs["lv"] = lv
		hs["exp"] = xp
		rows.append({"id": h["id"], "name": h["name"], "lv0": lv0, "lv": lv, "gain": gain, "exp": xp, "learned": learned})
	if stage_i + 1 < D.STAGES.size():
		save["stage"] = stage_i + 1
		camp_stage = stage_i + 1
	var loot := _roll_loot()
	SAVE.save_game(save)
	_result = {"win": true, "rows": rows, "t": _t, "loot": loot}
	_show_banner("VICTORY", "ชนะ!  +%d EXP" % _exp_pool)
	battle_finished.emit(true, stage_i, turns)


## drops: random items per defeated monster, a seed from the boss, first-clear equipment
func _roll_loot() -> Array:
	var out := []
	var got := {}
	var nfoes := int(_exp_pool / maxf(1.0, 10.0 + 6.0 * D.STAGES[stage_i]["lv"]))
	for k in nfoes:
		if randf() < 0.35:
			var r := randf()
			var it := "tome_s" if r < 0.6 else ("seed" if r < 0.8 else ("tome_l" if r < 0.93 else "forget"))
			got[it] = int(got.get(it, 0)) + 1
	got["seed"] = int(got.get("seed", 0)) + 1
	if not save.has("rewarded"):
		save["rewarded"] = []
	if not stage_i in save["rewarded"]:
		save["rewarded"].append(stage_i)
		var rw: Dictionary = D.CLEAR_REWARD[stage_i]
		for it in rw["items"]:
			got[it] = int(got.get(it, 0)) + int(rw["items"][it])
		for eid in rw["eq"]:
			if not eid in save["equips"]:
				save["equips"].append(eid)
				out.append("★ " + D.EQUIPS[eid]["n"])
	for it in got:
		save["items"][it] = int(save["items"].get(it, 0)) + int(got[it])
		out.append("%s ×%d" % [D.ITEMS[it]["n"], got[it]])
	return out


func _defeat() -> void:
	state = "lose"
	combo = {}
	Engine.time_scale = 1.0
	_music("")
	_sfx("ko")
	_result = {"win": false, "rows": [], "t": _t}
	_show_banner("DEFEAT", "ปาร์ตี้ล้มทั้งหมด", C_BAD)
	battle_finished.emit(false, stage_i, turns)


func _result_continue(ok: bool) -> void:
	if _t - float(_result.get("t", 0.0)) < 0.8:
		return
	var win: bool = _result.get("win", false)
	_sfx("confirm")
	_result = {}
	if not win and ok:
		_start_battle(stage_i)    # retry
	else:
		_enter_camp()


# ================================================================ auto battle
func _auto_step() -> void:
	_auto_wait = 0.45
	var h := cur
	if state == "magicks":
		state = "command"
		return
	if state == "combo":
		var best := -1
		var bv := -1.0
		var sm := _set_magicks(h)
		for i in 3:
			if _can_cast(h, sm[i]) != "":
				continue
			var v := _ai_value(h, sm[i])
			if v > bv:
				bv = v
				best = i
		if best < 0:
			_combo_cancel()
		else:
			cmb_sel = best
			_combo_cast(best)
		return
	# command
	_ai_target(h)
	if _combo_any(h) and (h["g"] >= 2.999 or (h["g"] >= D.TUNE["COMBO_MIN"] and randf() < 0.35)):
		_enter_combo()
		return
	var best_m := {}
	var bv2 := 0.0
	for m in h["mags"]:
		if _can_cast(h, m) != "":
			continue
		var v := _ai_value(h, m)
		if v > bv2:
			bv2 = v
			best_m = m
	var mp_ok: bool = float(h["mp"]) / h["mmp"] > 0.3
	if not best_m.is_empty() and (bv2 >= 2.0 or (mp_ok and bv2 > 1.0)):
		state = "magicks"
		mag_i = h["mags"].find(best_m)
		_cast_from_list(mag_i)
	else:
		_do_attack()


func _ai_target(h: Dictionary) -> void:
	var al := _alive_foes()
	if al.is_empty():
		return
	var best: Dictionary = al[0]
	var bv := -1.0
	for e in al:
		var v: float = D.mult(h["el"], e["el"]) * 2.0 - float(e["hp"]) / e["mhp"] + (1.5 if e["broken"] > 0 else 0.0)
		if v > bv:
			bv = v
			best = e
	tgt = foes.find(best)


func _ai_value(h: Dictionary, m: Dictionary) -> float:
	if m.is_empty():
		return -1.0
	if m.has("heal"):
		var low := 1.0
		for a in _alive_heroes():
			low = minf(low, float(a["hp"]) / a["mhp"])
		if m["tg"] == "revive":
			return 6.0
		return 4.0 if low < 0.45 else 0.1
	if not m.has("pow"):
		for k in m.get("buff", {}):
			if h["status"].has(k):
				return 0.2
		return 1.2 if randf() < 0.3 else 0.4
	var e := _target_foe()
	var v: float = float(m["pow"]) * int(m.get("hits", 1)) * D.mult_raw(m["el"], e.get("el", ""))
	if m["tg"] == "all":
		v *= _alive_foes().size() * 0.8
	return v


# ================================================================ feedback
func _act(text: String, enemy: bool) -> void:
	_act_text = text
	_act_enemy = enemy
	_act_t = _t


func _show_banner(title: String, sub: String, col := C_ACC) -> void:
	_banner = title
	_banner_sub = sub
	_banner_t = _t
	_banner_col = col


func _show_info(text: String) -> void:
	_info = text
	_info_t = _t


func _deny(why: String) -> void:
	_sfx("deny")
	_pop_screen(why, Vector2(1500, 560), "txt")


var _flash_t := -10.0
var _flash_c := C_ACC


func _flash_screen(c: Color) -> void:
	_flash_t = _t
	_flash_c = c


func _screen_of(n: Node3D, up: float) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if cam == null or n == null:
		return Vector2(960, 400)
	var p := cam.unproject_position(n.global_position + Vector3.UP * up)
	return p * (Vector2(1920, 1080) / get_viewport().get_visible_rect().size)


func _pop_world(n: Node3D, text: String, sub: String, kind: String) -> void:
	_pop_screen(text, _screen_of(n, 1.7) + Vector2(randf_range(-26, 26), randf_range(-10, 10)), kind, sub)


func _pop_screen(text: String, pos: Vector2, kind: String, sub := "") -> void:
	_pops.append({"text": text, "sub": sub, "pos": pos, "t0": _t, "kind": kind})



# ================================================================ audio
## sound effects + music from the web build (audio/sfx, audio/bgm)
func _sfx(key: String, db := 0.0) -> void:
	var path := "res://audio/sfx/%s.mp3" % key
	if not ResourceLoader.exists(path):
		return
	var ap: AudioStreamPlayer = _sfxp[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfxp.size()
	ap.stream = _texture_any(path)
	ap.volume_db = sfx_db + db
	ap.play()


func _music(key: String) -> void:
	if key == _bgm_key:
		return
	_bgm_key = key
	if key == "":
		var tw := _bgm.create_tween()
		tw.tween_property(_bgm, "volume_db", -60.0, 1.2)
		tw.tween_callback(_bgm.stop)
		return
	var file := "boss" if key == "boss" else "battle"
	var st := _texture_any("res://audio/bgm/%s.mp3" % file) as AudioStreamMP3
	if st:
		st.loop = true
	_bgm.stream = st
	_bgm.volume_db = music_db - (10.0 if key == "camp" else 0.0)
	_bgm.play()


func _texture_any(path: String) -> Resource:
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]


# ================================================================ options menu
func _open_menu() -> void:
	menu_open = true
	menu_i = 0
	Engine.time_scale = 0.0
	_sfx("confirm")


func _close_menu() -> void:
	menu_open = false
	Engine.time_scale = battle_speed if mode == "battle" else 1.0
	_sfx("cancel")


func _menu_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("m_up", true):
		menu_i = posmod(menu_i - 1, MENU.size())
		_sfx("cursor", -6.0)
	elif ev.is_action_pressed("m_down", true):
		menu_i = posmod(menu_i + 1, MENU.size())
		_sfx("cursor", -6.0)
	elif ev.is_action_pressed("m_cross"):
		_menu_pick(menu_i)
	elif ev.is_action_pressed("m_circle") or ev.is_action_pressed("m_back") or ev.is_action_pressed("m_auto"):
		_close_menu()


func _menu_pick(i: int) -> void:
	match i:
		0: _close_menu()
		1:
			auto_battle = not auto_battle
			_sfx("confirm")
		2:
			battle_speed = 2.0 if battle_speed < 2.0 else 1.0
			_sfx("confirm")
		3:
			menu_open = false
			_bid += 1
			Engine.time_scale = 1.0
			_show_banner("SURRENDER", "ยอมแพ้", C_BAD)
			_defeat()
		4:
			menu_open = false
			_bid += 1
			_result = {}
			_enter_camp()


func _draw_opt_button() -> void:
	var r := Rect2(1920 - 56 - 170, 30, 170, 44)
	_hud.draw_colored_polygon(_skew_poly(r, 9), Color(0, 0, 0, 0.55))
	_outline(_skew_poly(r, 9), Color(1, 1, 1, 0.25))
	_glyph(r.position + Vector2(28, 22), "opt", 14)
	_text(F_D, r.position + Vector2(52, 31), "OPTIONS", 22, C_INK)
	_hit(r, "opt:0")


func _draw_menu() -> void:
	_hud.draw_rect(Rect2(0, 0, 1920, 1080), Color(0, 0, 0, 0.6))
	var r := Rect2(660, 250, 600, 96 + 74 * MENU.size())
	_panel(r, 20, Color(0.05, 0.055, 0.07, 0.97), C_ACC)
	_text(F_D, r.position + Vector2(36, 62), "OPTIONS", 44, C_ACC)
	_text(F_UI, r.position + Vector2(240, 58), "หยุดเกมชั่วคราว", 18, C_DIM)
	for i in MENU.size():
		var rr := Rect2(r.position.x + 30, r.position.y + 90 + i * 74, r.size.x - 60, 62)
		var sel := i == menu_i
		var danger := i >= 3
		_hud.draw_colored_polygon(_skew_poly(rr, 12), (C_BAD if danger else C_ACC) if sel else Color(0.1, 0.1, 0.12, 0.95))
		var fg := (Color.WHITE if danger else C_ACC_INK) if sel else (Color("FF8A9A") if danger else C_INK)
		_text(F_D, rr.position + Vector2(26, 43), MENU[i][0], 32, fg)
		var right: String = MENU[i][1]
		if i == 1:
			right = "ON" if auto_battle else "OFF"
		elif i == 2:
			right = "×%d" % int(battle_speed)
		_text(F_UI2 if i < 1 or i > 2 else F_D, Vector2(rr.end.x - 24, rr.position.y + 41), right, 22, Color(fg, 0.85), HORIZONTAL_ALIGNMENT_RIGHT, 0)
		_hit(rr, "menu:%d" % i)


# ================================================================ turn glow + combo screen fx
## glowing outline (blue = ally, red = enemy) on whoever is taking their turn
func _update_glow() -> void:
	var on := {}
	var tg := get_tree().get_first_node_in_group("turn_glow")
	var ca := C_ALLY
	var cf := C_FOE
	var br := 2.2
	var pu := 1.3
	var ps := 5.0
	var shape := Vector2(2.0, 0.5)
	var foes_glow := true
	if tg:
		ca = tg.ally_color
		cf = tg.enemy_color
		br = tg.brightness
		pu = tg.pulse
		ps = tg.pulse_speed
		shape = Vector2(tg.width, tg.roundness)
		foes_glow = tg.glow_enemies
	if mode == "battle" and not cur.is_empty() and state in ["command", "magicks", "combo", "acting", "foe"] and (cur["side"] == "h" or foes_glow):
		var n := _unode(cur)
		if n:
			var c := ca if cur["side"] == "h" else cf
			var k := br + pu * _blink(ps)
			on[n] = Vector4(c.r * k, c.g * k, c.b * k, 1.0)
	var nodes := []
	for h in D.HEROES:
		var hn := get_node_or_null("../Actors/" + h["id"])
		if hn:
			nodes.append(hn)
	for e in foes:
		var en := _enode(e)
		if en:
			nodes.append(en)
	for n in nodes:
		(n as GeometryInstance3D).set_instance_shader_parameter("outline", on.get(n, Vector4.ZERO))
		(n as GeometryInstance3D).set_instance_shader_parameter("outline_shape", shape)


func _update_cfx(_delta: float) -> void:
	var cc := get_tree().get_first_node_in_group("combo_cinematic")
	if cc == null:
		return
	var on: bool = mode == "battle" and not combo.is_empty() and not cur.is_empty()
	if on:
		var e := _target_foe()
		cc.call("set_active", true, _unode(cur), _enode(e) if not e.is_empty() else null)
	else:
		cc.call("set_active", false)


# ================================================================ drawing: primitives
func _skew_poly(r: Rect2, k: float) -> PackedVector2Array:
	return PackedVector2Array([r.position + Vector2(k, 0), Vector2(r.end.x + k, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


func _chamfer(r: Rect2, cut: float) -> PackedVector2Array:
	var x := r.position.x; var y := r.position.y; var w := r.size.x; var h := r.size.y
	return PackedVector2Array([Vector2(x, y), Vector2(x + w - cut, y), Vector2(x + w, y + cut), Vector2(x + w, y + h), Vector2(x + cut, y + h), Vector2(x, y + h - cut)])


func _panel(r: Rect2, cut := 14.0, fill := C_PANEL, line := C_LINE) -> void:
	var p := _chamfer(r, cut)
	_hud.draw_colored_polygon(p, fill)
	var q := p.duplicate(); q.append(p[0])
	_hud.draw_polyline(q, line, 1.5)


func _outline(p: PackedVector2Array, col: Color, w := 1.5) -> void:
	var q := p.duplicate(); q.append(p[0])
	_hud.draw_polyline(q, col, w)


func _tag(text: String, pos: Vector2, size: int, bg := C_ACC, fg := C_ACC_INK, font: Font = null) -> float:
	var f: Font = font if font else F_D
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + size * 0.7
	var h := size * 1.05
	_hud.draw_colored_polygon(_skew_poly(Rect2(pos, Vector2(w, h)), h * 0.22), bg)
	_hud.draw_string(f, pos + Vector2(size * 0.4, h * 0.82), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fg)
	return w


func _text(f: Font, pos: Vector2, text: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 0) -> void:
	if align == HORIZONTAL_ALIGNMENT_RIGHT and width <= 0.0:
		pos.x -= f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		align = HORIZONTAL_ALIGNMENT_LEFT
		width = -1.0
	if outline > 0:
		_hud.draw_string_outline(f, pos, text, align, width, size, outline, Color(0, 0, 0, col.a))
	_hud.draw_string(f, pos, text, align, width, size, col)


func _tw(f: Font, text: String, size: int) -> float:
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _bar(r: Rect2, ratio: float, col: Color, trail: float = -1.0) -> void:
	var k := r.size.y * 0.6
	_hud.draw_colored_polygon(_skew_poly(r, k), Color(0, 0, 0, 0.85))
	if trail > ratio:
		_hud.draw_colored_polygon(_skew_poly(Rect2(r.position, Vector2(r.size.x * clampf(trail, 0, 1), r.size.y)), k), Color(1, 1, 1, 0.85))
	if ratio > 0.0:
		_hud.draw_colored_polygon(_skew_poly(Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0, 1), r.size.y)), k), col)


func _smooth(key: String, target: float, speed := 3.0) -> float:
	var v: float = _shown.get(key, target)
	v = move_toward(v, target, get_process_delta_time() / maxf(Engine.time_scale, 0.01) * speed)
	_shown[key] = v
	return v


func _diamond(c: Vector2, r: float, col: Color) -> void:
	_hud.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)


func _blink(speed := 8.0) -> float:
	return 0.5 + 0.5 * sin(_t * speed)


func _hit(r: Rect2, id: String) -> void:
	_hits.append([r, id])


func _texture(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]


## face/body icon of a unit inside rect r
func _portrait(u: Dictionary, r: Rect2, dim := false) -> void:
	var tex: Texture2D
	var src: Rect2
	if u["side"] == "h":
		var n := _hnode(u) as Sprite3D
		if n == null:
			return
		tex = n.texture
		src = D.hero_def(u["id"])["icon"]
	else:
		tex = _texture("res://art/mon/mon_%s.png" % u["el"])
		var bb: Array = D.MONS[u["el"]]["bb"]
		var s := minf(bb[2] - bb[0], bb[3] - bb[1]) * 0.8
		src = Rect2(bb[0] + 2, bb[1], s, s)
	_hud.draw_texture_rect_region(tex, r, src, Color(0.45, 0.45, 0.5) if dim else Color.WHITE)


func _glyph(c: Vector2, kind: String, rad := 15.0) -> void:
	_hud.draw_circle(c, rad, Color(0, 0, 0, 0.8))
	_hud.draw_arc(c, rad, 0, TAU, 28, Color(1, 1, 1, 0.35), 1.5)
	var s := rad / 15.0
	match kind:
		"cross":
			var col := Color("8FB4FF")
			_hud.draw_line(c + Vector2(-6, -6) * s, c + Vector2(6, 6) * s, col, 3 * s)
			_hud.draw_line(c + Vector2(6, -6) * s, c + Vector2(-6, 6) * s, col, 3 * s)
		"circle":
			_hud.draw_arc(c, 7 * s, 0, TAU, 20, Color("FF6B7A"), 3 * s)
		"triangle":
			_outline(PackedVector2Array([c + Vector2(0, -8) * s, c + Vector2(8, 6) * s, c + Vector2(-8, 6) * s]), Color("4FE0B0"), 3 * s)
		"square":
			_outline(PackedVector2Array([c + Vector2(-6, -6) * s, c + Vector2(6, -6) * s, c + Vector2(6, 6) * s, c + Vector2(-6, 6) * s]), Color("F59AE0"), 3 * s)
		"lr":
			_hud.draw_string(F_D, c + Vector2(-12, 7) * s, "L1R1", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * s), Color(1, 1, 1, 0.9))
		"dpad":
			var col3 := Color(1, 1, 1, 0.85)
			_hud.draw_rect(Rect2(c - Vector2(3, 9) * s, Vector2(6, 18) * s), col3)
			_hud.draw_rect(Rect2(c - Vector2(9, 3) * s, Vector2(18, 6) * s), col3)
		"opt":
			_hud.draw_string(F_D, c + Vector2(-10, 6) * s, "OPT", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * s), Color(1, 1, 1, 0.9))


func _kind_icon(c: Vector2, kind: String, col: Color) -> void:
	match kind:
		"single": _diamond(c, 6, col)
		"aoe":
			_diamond(c + Vector2(-5, 0), 4, col); _diamond(c + Vector2(5, 0), 4, col); _diamond(c + Vector2(0, -5), 4, col)
		"heal":
			_hud.draw_rect(Rect2(c - Vector2(2, 7), Vector2(4, 14)), col); _hud.draw_rect(Rect2(c - Vector2(7, 2), Vector2(14, 4)), col)
		"buff":
			_hud.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 3), c + Vector2(-7, 3)]), col)
		_:
			_hud.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 7), c + Vector2(7, -3), c + Vector2(-7, -3)]), col)


# ================================================================ drawing: frame
func _draw_hud() -> void:
	_sc = (_hud.size.x / 1920.0) * ui_scale
	_hud.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _sc)
	_hits.clear()
	if mode == "camp":
		if sysm.open:
			sysm.draw()
		else:
			_draw_camp()
	elif mode == "battle":
		_draw_battle()
	_draw_pops()
	_draw_banner()
	var fa := 1.0 - (_t - _flash_t) * 2.5
	if fa > 0.0:
		_hud.draw_rect(Rect2(0, 0, 1920, 1080), Color(_flash_c, 0.25 * fa))


func _draw_battle() -> void:
	_draw_stage_tag()
	_draw_timeline()
	for e in foes:
		_draw_foe_tag(e)
	_draw_party(Vector2(40, 1080 - 40))
	if state in ["command", "magicks"] and not cur.is_empty() and cur["side"] == "h":
		_draw_commands(Vector2(1920 - 56, 1080 - 64))
	if state == "magicks":
		_draw_magicks()
	if not combo.is_empty() and not cur.is_empty():
		_draw_combo()
	_draw_actbox()
	_draw_info()
	_draw_hints(Vector2(1920 - 56, 1080 - 20))
	if state == "win" or state == "lose":
		_draw_result()
	else:
		_draw_opt_button()
	if menu_open:
		_draw_menu()


func _draw_stage_tag() -> void:
	var stg: Dictionary = D.STAGES[stage_i]
	_tag(stg["n"], Vector2(56, 34), 26)
	_text(F_D2, Vector2(58, 90), "STAGE %d  ·  %s" % [stage_i + 1, stg["th"]], 19, C_DIM)
	var nw: int = stg["waves"].size()
	var x := 58.0
	_text(F_D, Vector2(x, 128), "WAVE", 18, C_DIM)
	for i in nw:
		var r := Rect2(x + 52 + i * 34, 112, 28, 16)
		_hud.draw_colored_polygon(_skew_poly(r, 5), C_ACC if i <= wave else Color(0, 0, 0, 0.6))
	if auto_battle:
		_tag("AUTO", Vector2(x + 60 + nw * 34, 108), 18, C_PINK, Color.WHITE)
	if battle_speed > 1.0:
		_tag("×%d" % int(battle_speed), Vector2(x + 128 + nw * 34, 108), 18, C_INK, C_ACC_INK)


func _draw_timeline() -> void:
	if cur.is_empty():
		return
	var order := _timeline(9, _preview_w())
	var x0 := 600.0
	var ly := 70.0
	var step := 60.0
	var x1 := x0 + 110 + step * order.size()
	_hud.draw_line(Vector2(x0, ly), Vector2(x1, ly), Color(1, 1, 1, 0.28), 2.0)
	# NOW: big icon with a glowing frame
	var nc := C_ALLY if cur["side"] == "h" else C_FOE
	var nr := Rect2(x0, ly - 32, 64, 64)
	for g in 3:
		_hud.draw_rect(nr.grow(3 + g * 3), Color(nc, (0.22 - g * 0.06) * (0.6 + 0.4 * _blink(5))))
	_hud.draw_rect(nr, Color(0, 0, 0, 0.7))
	_portrait(cur, nr.grow(-3))
	_hud.draw_rect(nr, nc, false, 3.0)
	var x := x0 + 104.0
	var choosing := state in ["command", "magicks", "combo"]
	var marked := false
	for o in order:
		var u: Dictionary = o["u"]
		var ally: bool = u["side"] == "h"
		var col := C_ALLY if ally else C_FOE
		var r := Rect2(x - 20, (ly - 46) if ally else (ly + 6), 40, 40)
		var is_cur: bool = is_same(u, cur) and not marked and choosing
		_hud.draw_line(Vector2(x, ly), Vector2(x, r.end.y if ally else r.position.y), Color(col, 0.6), 2.0)
		_hud.draw_circle(Vector2(x, ly), 3.0, col)
		if is_cur:
			marked = true
			_hud.draw_rect(r.grow(4), Color(col, 0.25 + 0.3 * _blink(6)))
		_hud.draw_rect(r, Color(0, 0, 0, 0.55))
		_portrait(u, r.grow(-2), false)
		_hud.draw_rect(r, col if is_cur else Color(col, 0.75), false, 2.5 if is_cur else 1.5)
		if is_cur:
			var t := Vector2(x, r.position.y - 6)
			_hud.draw_colored_polygon(PackedVector2Array([t + Vector2(-6, -8), t + Vector2(6, -8), t]), col)
		if not ally and u["broken"] > 0:
			_hud.draw_rect(Rect2(r.position.x, r.end.y + 3, r.size.x, 4), C_BRK)
		x += step


func _draw_party(bl: Vector2) -> void:
	var row_h := 84.0
	var y0 := bl.y - row_h * party.size()
	for i in party.size():
		var hd: Dictionary = party[i]
		var x := bl.x
		var y := y0 + i * row_h
		var ko: bool = hd["hp"] <= 0
		var active: bool = is_same(hd, cur) and mode == "battle" and state in ["command", "magicks", "combo", "acting"]
		var ec := _el_col(hd["el"])
		if active:
			# soft blue glow behind the active hero's row
			for g in 4:
				var gr := Rect2(x - 14 - g * 6, y - 4 - g * 3, 600 + g * 12, row_h - 4 + g * 6)
				_hud.draw_colored_polygon(_skew_poly(gr, 18), Color(C_ALLY, (0.10 - g * 0.02) * (0.7 + 0.3 * _blink(5))))
			_hud.draw_rect(Rect2(x - 14, y + 2, 4, row_h - 16), C_ALLY)
		_diamond(Vector2(x + 6, y + 22), 6, ec if not ko else C_DIM)
		var nc := C_DIM if ko else (C_ALLY.lerp(Color.WHITE, 0.25) if active else C_INK)
		_text(F_D, Vector2(x + 20, y + 32), hd["name"], 28, nc, HORIZONTAL_ALIGNMENT_LEFT, -1, 6)
		var tw := _tw(F_D, hd["name"], 28)
		_text(F_D2, Vector2(x + 28 + tw, y + 32), "Lv %d" % hd["lv"], 16, C_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
		var sx := x + 20
		if ko:
			_tag("KO", Vector2(sx, y + 42), 14, C_BAD, Color.WHITE)
			sx += 40
		for k in hd["status"]:
			var good: bool = not k in D.BAD
			var stx: String = ("%s %d" % [D.STATUS_TH.get(k, k), hd["status"][k]]) if k != "guard" else "GUARD"
			_text(F_D2, Vector2(sx, y + 58), stx, 14, C_OK if good else Color("FF9AAA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
			sx += _tw(F_D2, stx, 14) + 10
		# HP / MP / combo
		var bx := x + 290
		var hp_r: float = float(hd["hp"]) / hd["mhp"]
		_bar(Rect2(bx, y + 10, 190, 10), hp_r, C_HP, _smooth("hp%d" % i, hp_r, 0.6))
		_text(F_D2, Vector2(bx + 200, y + 21), "%d" % hd["hp"], 20, C_INK, HORIZONTAL_ALIGNMENT_LEFT, -1, 5)
		var mp_r: float = float(hd["mp"]) / hd["mmp"]
		var mpr := Rect2(bx, y + 28, 190, 6)
		_bar(mpr, mp_r, C_MP)
		var cost := _preview_cost(hd)
		if cost > 0:
			var after: float = float(hd["mp"] - cost) / hd["mmp"]
			var k := mpr.size.y * 0.6
			if after >= 0.0:
				var seg := Rect2(mpr.position + Vector2(mpr.size.x * after, 0), Vector2(mpr.size.x * (mp_r - after), mpr.size.y))
				_hud.draw_colored_polygon(_skew_poly(seg, k), Color(1, 1, 1, 0.35 + 0.65 * _blink(14)))
			else:
				_hud.draw_colored_polygon(_skew_poly(mpr, k), Color(C_BAD, 0.3 + 0.5 * _blink(14)))
		_text(F_D2, Vector2(bx + 200, y + 40), "%d MP" % hd["mp"], 14, C_MP, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
		if cost > 0:
			_text(F_D, Vector2(bx + 254, y + 40), "−%d" % cost, 15, Color(1, 1, 1, 0.5 + 0.5 * _blink(14)) if hd["mp"] >= cost else C_BAD, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
		_draw_gauge(Rect2(bx, y + 52, 190, 10), hd, active and state == "combo")
		var g: float = hd["g"]
		if g >= 2.999:
			_text(F_D, Vector2(bx + 200, y + 64), "COMBO MAX", 15, C_PINK.lerp(C_GOLD, _blink(8)), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
		elif g >= D.TUNE["COMBO_MIN"] - 0.001:
			_text(F_D, Vector2(bx + 200, y + 64), "COMBO READY", 15, C_GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)


func _draw_gauge(r: Rect2, hd: Dictionary, spending: bool) -> void:
	var g: float = hd["g"]
	var gap := 6.0
	var sw := (r.size.x - gap * 2) / 3.0
	var full := g >= 2.999
	var ready: bool = g >= D.TUNE["COMBO_MIN"] - 0.001
	for s in 3:
		var sr := Rect2(r.position.x + s * (sw + gap), r.position.y, sw, r.size.y)
		_hud.draw_colored_polygon(_skew_poly(sr, 6), Color(0, 0, 0, 0.85))
		var f := clampf(g - s, 0.0, 1.0)
		if f > 0.0:
			var col := Color(0.85, 0.87, 0.92)
			if full:
				col = C_PINK.lerp(C_GOLD, _blink(8))
			elif ready:
				col = C_GOLD
			# the segment the next combo spell would spend blinks
			if spending and s == int(ceil(g)) - 1:
				col = col.lerp(Color.WHITE, _blink(14))
			_hud.draw_colored_polygon(_skew_poly(Rect2(sr.position, Vector2(sw * f, sr.size.y)), 6), col)
		_outline(_skew_poly(sr, 6), Color(1, 1, 1, 0.18), 1.0)
	if full:
		_outline(_skew_poly(r.grow(3), 8), Color(C_GOLD, 0.4 + 0.5 * _blink(8)), 2.0)


func _preview_cost(hd: Dictionary) -> int:
	if not is_same(hd, cur):
		return 0
	if state == "magicks":
		var ms: Array = hd["mags"]
		if mag_i < ms.size():
			return _mp_cost(ms[mag_i])
	if state == "combo" and cmb_sel >= 0:
		var m: Dictionary = _set_magicks(hd)[cmb_sel]
		return _mp_cost(m) if not m.is_empty() else 0
	return 0


func _draw_foe_tag(e: Dictionary) -> void:
	var n := _enode(e)
	if n == null or (e["hp"] <= 0 and not n.visible):
		return
	if e["hp"] <= 0:
		return
	var bb: Array = D.MONS[e["el"]]["bb"]
	var top: float = float(bb[3] - bb[1]) / 32.0 * float(e.get("sc", 1.0))
	var p := _screen_of(n, top)
	var w := 200.0
	var x := p.x - w * 0.5
	var y := p.y - 30
	var ec := _el_col(e["el"])
	_diamond(Vector2(x + 8, y - 8), 8, ec)
	_text(F_D, Vector2(x + 22, y), e["name"], 24, C_INK, HORIZONTAL_ALIGNMENT_LEFT, -1, 6)
	var tx := x + 28 + _tw(F_D, e["name"], 24)
	if e["boss"]:
		tx += _tag("BOSS", Vector2(tx, y - 20), 14, C_BAD, Color.WHITE) + 4
	if e["mark"] != "":
		var mc := _el_col(e["mark"])
		_diamond(Vector2(tx + 10, y - 9), 9 + 2 * _blink(5), Color(mc, 0.9))
		_hud.draw_arc(Vector2(tx + 10, y - 9), 14, 0, TAU, 20, Color(mc, 0.6), 2.0)
	# known weak / resist
	var kx := x
	for el in e["known"]:
		var m: float = e["known"][el]
		if m >= 2.0:
			kx += _tag("WEAK " + D.EL_TH.get(el, el), Vector2(kx, y - 48), 15, C_ACC, C_ACC_INK) + 4
		elif m < 1.0:
			kx += _tag("RES " + D.EL_TH.get(el, el), Vector2(kx, y - 48), 15, Color(0, 0, 0, 0.75), C_DIM) + 4
	var hp_r: float = float(e["hp"]) / e["mhp"]
	_bar(Rect2(x, y + 8, w, 12), hp_r, C_BAD, _smooth("foe%d_%d" % [e["slot"], wave], hp_r, 0.5))
	var br: float = float(e["brk"]) / e["mbrk"]
	if e["broken"] > 0:
		_bar(Rect2(x + 4, y + 25, w * 0.82, 6), 1.0, Color(C_BRK, 0.4 + 0.6 * _blink(10)))
		_tag("BREAK", Vector2(x + w * 0.82 + 10, y + 19), 13, C_BRK, C_ACC_INK)
	else:
		_bar(Rect2(x + 4, y + 25, w * 0.82, 6), br, C_BRK)
	var sx := x
	for k in e["status"]:
		sx += _tag("%s %d" % [D.STATUS_TH.get(k, k), e["status"][k]], Vector2(sx, y + 36), 13, Color("4A1A24"), Color("FF9AAA")) + 3
	_hit(Rect2(x - 10, y - 30, w + 20, 200), "tgt:%d" % foes.find(e))
	# target arrows
	if is_same(e, _target_foe()) and state in ["command", "magicks", "combo", "acting"] and not cur.is_empty() and cur["side"] == "h":
		var bob := sin(_t * 10.0) * 5.0
		var ac := C_ACC if _blink(12) > 0.5 else Color.WHITE
		var tc := Vector2(p.x, y - 58 + bob - (20 if not e["known"].is_empty() else 0))
		var tri := PackedVector2Array([tc + Vector2(-13, -20), tc + Vector2(13, -20), tc])
		_hud.draw_colored_polygon(tri, ac)
		_outline(tri, Color.BLACK, 2.0)


func _draw_commands(br: Vector2) -> void:
	var hd := cur
	var row := 62.0
	var w := 340.0
	var x := br.x - w
	var y0 := br.y - row * COMMANDS.size()
	_tag(hd["name"] + "'S TURN", Vector2(x, y0 - 48), 22, Color(0, 0, 0, 0.8), C_ACC)
	for i in COMMANDS.size():
		var sel := i == cmd and state == "command"
		var held := i == cmd and state == "magicks"
		var r := Rect2(Vector2(x, y0 + i * row), Vector2(w, row - 10))
		var off: bool = i == 2 and (hd["g"] < D.TUNE["COMBO_MIN"] - 0.001 or not _combo_any(hd))
		var bg := C_ACC if sel else (C_INK if held else Color(0.08, 0.085, 0.1, 0.9))
		if i == 2 and not off and not sel:
			bg = Color(0.25, 0.08, 0.17, 0.95).lerp(Color(0.45, 0.1, 0.28, 0.95), _blink(6)) if hd["g"] >= 2.999 else Color(0.2, 0.17, 0.05, 0.95)
		_hud.draw_colored_polygon(_skew_poly(r, 12), bg)
		if not sel and not held:
			_outline(_skew_poly(r, 12), C_LINE)
		var fg := C_ACC_INK if (sel or held) else (C_DIM if off else C_INK)
		_glyph(r.position + Vector2(34, 26), ["square", "triangle", "circle", "cross"][i], 15)
		_text(F_D, r.position + Vector2(60, 40), COMMANDS[i][0], 34, fg)
		if i == 2:
			_draw_gauge(Rect2(r.position.x + 175, r.position.y + 20, 120, 12), hd, false)
		else:
			_text(F_UI, r.position + Vector2(w - 20, 36), COMMANDS[i][1], 18, Color(fg, 0.7), HORIZONTAL_ALIGNMENT_RIGHT, 0)
		_hit(r, "cmd:%d" % i)


func _draw_magicks() -> void:
	var hd := cur
	var ms: Array = hd["mags"]
	var row := 56.0
	var vis := mini(6, ms.size())
	var w := 560.0
	var h := row * vis + 118
	var r := Rect2(Vector2(1920 - 56 - 340 - 24 - w, 1080 - 64 - h), Vector2(w, h))
	_panel(r, 14, Color(0.06, 0.065, 0.08, 0.95))
	_text(F_D, r.position + Vector2(18, 32), "MAGICKS", 24, C_ACC)
	_text(F_D2, r.position + Vector2(126, 32), "%d / %d  ·  Lv %d" % [ms.size(), D.MAGICKS[hd["id"]].size(), hd["lv"]], 17, C_DIM)
	var e := _target_foe()
	for vi in vis:
		var i := mag_top + vi
		if i >= ms.size():
			break
		var m: Dictionary = ms[i]
		var ok := _can_cast(hd, m) == ""
		var y := r.position.y + 44 + vi * row
		var sel := i == mag_i
		var rr := Rect2(r.position.x + 10, y, w - 26, row - 6)
		if sel:
			_hud.draw_colored_polygon(_skew_poly(rr, 8), C_ACC)
		_hit(rr, "mag:%d" % i)
		var fg := C_ACC_INK if sel else (C_INK if ok else C_DIM)
		var kd := D.kind(m)
		_kind_icon(Vector2(rr.position.x + 22, y + 24), kd, fg if sel else _el_col(m["el"]))
		_text(F_D, Vector2(rr.position.x + 40, y + 30), m["n"].to_upper(), 26, fg)
		_text(F_UI, Vector2(rr.position.x + 42, y + 47), m["th"] + "  ·  " + D.KIND_TAG[kd], 13, Color(fg, 0.75))
		var slot: int = hd["set"].find(m["id"])
		if slot >= 0:
			_glyph(Vector2(rr.end.x - 130, y + 24), SLOT_GLYPH[slot], 11)
		if m.has("pow") and not e.is_empty() and e["known"].get(m["el"], 1.0) >= 2.0:
			_tag("WEAK", Vector2(rr.end.x - 200, y + 12), 14, C_ACC_INK if sel else C_ACC, C_ACC if sel else C_ACC_INK)
		var cost := _mp_cost(m)
		_text(F_D2, Vector2(rr.end.x - 14, y + 33), "%d MP" % cost, 24, C_ACC_INK if sel else (C_MP if hd["mp"] >= cost else C_BAD), HORIZONTAL_ALIGNMENT_RIGHT, 0)
	if ms.size() > vis:
		_text(F_D2, Vector2(r.end.x - 20, r.position.y + 32), "▲▼ %d" % ms.size(), 15, C_DIM, HORIZONTAL_ALIGNMENT_RIGHT, 0)
	# description of the highlighted magick
	if mag_i < ms.size():
		var m: Dictionary = ms[mag_i]
		var dy := r.end.y - 62
		_hud.draw_line(Vector2(r.position.x + 14, dy), Vector2(r.end.x - 14, dy), C_LINE, 1.0)
		var why := _can_cast(hd, m)
		_hud.draw_multiline_string(F_UI, Vector2(r.position.x + 18, dy + 24), m["d"], HORIZONTAL_ALIGNMENT_LEFT, w - 40, 16, 2, C_INK)
		var tgt_txt := {"one": "ศัตรู 1 ตัว", "all": "ศัตรูทั้งหมด", "self": "ตัวเอง", "party": "ทั้งปาร์ตี้", "ally": "เพื่อน HP น้อยสุด", "revive": "เพื่อนที่ล้ม"}
		_text(F_D2, Vector2(r.position.x + 18, dy + 52), "เป้า: " + tgt_txt.get(m["tg"], ""), 14, C_DIM)
		if why != "":
			_text(F_UI2, Vector2(r.end.x - 18, dy + 52), why, 15, C_BAD, HORIZONTAL_ALIGNMENT_RIGHT, 0)


## input so far + which finisher patterns are still possible
func _draw_finisher_panel(pos: Vector2) -> void:
	var seq: Array = combo.get("seq", [])
	var can: bool = int(combo.get("max", 0)) >= 3
	var r := Rect2(pos, Vector2(300, 64 + 30 * D.FINISHERS.size()))
	_panel(r, 12, Color(0, 0, 0, 0.62), Color(C_GOLD, 0.5))
	_text(F_D, pos + Vector2(16, 30), "FINISHER", 22, C_GOLD)
	for k in 3:
		var bc := pos + Vector2(170 + k * 40, 22)
		_hud.draw_rect(Rect2(bc - Vector2(15, 15), Vector2(30, 30)), Color(1, 1, 1, 0.08))
		if k < seq.size():
			_glyph(bc, SLOT_GLYPH[seq[k]], 13)
	if not can:
		_text(F_UI, pos + Vector2(16, 54), "ต้องเปิดคอมโบด้วยเกจ 3 ช่อง", 14, C_DIM)
	var fin: Dictionary = combo.get("fin", {})
	for i in D.FINISHERS.size():
		var f: Dictionary = D.FINISHERS[i]
		var fs: Array = f["seq"]
		var ok := can
		for k in seq.size():
			if k >= 3 or fs[k] != seq[k]:
				ok = false
		var hit: bool = fin.get("n", "") == f["n"]
		var y := pos.y + 82 + i * 30
		var col := C_GOLD if hit else (C_INK if ok else Color(1, 1, 1, 0.22))
		if hit:
			_hud.draw_rect(Rect2(pos.x + 8, y - 22, 284, 28), Color(C_GOLD, 0.25 + 0.2 * _blink(8)))
		for k in 3:
			var gc := Vector2(pos.x + 24 + k * 26, y - 8)
			if ok or hit:
				_glyph(gc, SLOT_GLYPH[fs[k]], 10)
			else:
				_hud.draw_circle(gc, 10, Color(1, 1, 1, 0.06))
		_text(F_D, Vector2(pos.x + 108, y), f["n"], 17, col)


func _draw_combo() -> void:
	var hd := cur
	var step := int(combo.get("step", 0))
	var full: bool = combo.get("full", false)
	# big combo readout (left)
	var cx := 60.0
	var cy := 170.0
	_panel(Rect2(cx - 20, cy - 20, 300, 228), 14, Color(0, 0, 0, 0.6), Color(C_PINK if full else C_ACC, 0.6))
	_draw_finisher_panel(Vector2(cx - 20, cy + 224))
	_tag("COMBO", Vector2(cx, cy), 26, C_PINK if full else C_ACC, Color.WHITE if full else C_ACC_INK)
	if full:
		_tag("FULL +%d%%" % int(D.TUNE["FULL_BONUS"] * 100), Vector2(cx + 120, cy), 20, C_GOLD, C_ACC_INK)
	_text(F_D, Vector2(cx, cy + 80), "%d" % mini(step + 1, 3), 72, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
	_text(F_D, Vector2(cx + 44, cy + 80), "/ %d" % int(combo.get("max", 3)), 30, C_DIM, HORIZONTAL_ALIGNMENT_LEFT, -1, 6)
	_text(F_D, Vector2(cx, cy + 150), "×%.2f" % _combo_pow(step), 64, C_ACC, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
	_text(F_UI, Vector2(cx, cy + 184), "พลังเวทครั้งถัดไป", 16, C_INK)
	if state != "combo" and state != "acting":
		return
	# 4 buttons: □ left, △ top, ○ right, ✕ bottom
	var C := Vector2(1530, 896)
	var bs := Vector2(330, 104)
	var rects := [Rect2(C + Vector2(-345, -bs.y * 0.5 + 6), bs), Rect2(C + Vector2(-bs.x * 0.5, -bs.y - 64), bs), Rect2(C + Vector2(15, -bs.y * 0.5 + 6), bs)]
	var sm := _set_magicks(hd)
	var e := _target_foe()
	for i in 3:
		var m: Dictionary = sm[i]
		var r: Rect2 = rects[i]
		var ok := _can_cast(hd, m) == "" and state == "combo"
		var sel := i == cmb_sel
		var bg := Color(0.07, 0.075, 0.09, 0.94)
		if sel:
			bg = C_ACC
		elif ok:
			bg = Color(0.12, 0.12, 0.15, 0.95)
		_hud.draw_colored_polygon(_chamfer(r, 16), bg)
		_outline(_chamfer(r, 16), C_ACC if sel else (_el_col(m.get("el", "None")) if ok else C_LINE), 2.0 if ok else 1.0)
		_hit(r, "cmb:%d" % i)
		var fg := C_ACC_INK if sel else (C_INK if ok else C_DIM)
		_glyph(r.position + Vector2(24, 26), SLOT_GLYPH[i], 15)
		if m.is_empty():
			_text(F_D, r.position + Vector2(50, 38), "— EMPTY —", 26, C_DIM)
			continue
		_text(F_D, r.position + Vector2(48, 38), m["n"].to_upper(), 28, fg)
		var kd := D.kind(m)
		_kind_icon(Vector2(r.end.x - 22, r.position.y + 24), kd, fg if sel else _el_col(m["el"]))
		_hud.draw_string(F_UI, r.position + Vector2(16, 64), m["d"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 30, 15, Color(fg, 0.85))
		var cost := _mp_cost(m)
		_text(F_D2, r.position + Vector2(16, 92), "%d MP" % cost, 22, (C_ACC_INK if sel else C_MP) if hd["mp"] >= cost else C_BAD)
		var pw := "×%.2f" % _combo_pow(step)
		_text(F_D, Vector2(r.end.x - 16, r.position.y + 92), pw, 22, C_ACC_INK if sel else C_ACC, HORIZONTAL_ALIGNMENT_RIGHT, 0)
		if m.has("pow") and not e.is_empty() and e["known"].get(m["el"], 1.0) >= 2.0:
			_tag("WEAK", Vector2(r.position.x + 110, r.position.y + 74), 14, C_ACC_INK if sel else C_ACC, C_ACC if sel else C_ACC_INK)
		var sq: Array = combo.get("seq", []).duplicate()
		if sq.size() == 2 and int(combo.get("max", 0)) >= 3:
			sq.append(i)
			var fn := D.finisher_for(sq)
			if not fn.is_empty():
				_tag("FINISHER: " + fn["n"], Vector2(r.position.x + 12, r.position.y - 14), 14, C_GOLD, C_ACC_INK)
	# ✕ cancel / end
	var xr := Rect2(C + Vector2(-110, 66), Vector2(220, 54))
	_hud.draw_colored_polygon(_skew_poly(xr, 10), Color(0, 0, 0, 0.85))
	_outline(_skew_poly(xr, 10), C_LINE)
	_glyph(xr.position + Vector2(30, 27), "cross", 14)
	_text(F_D, xr.position + Vector2(54, 37), "CANCEL" if step == 0 else "END COMBO", 24, C_INK)
	_hit(xr, "cmbx:0")
	# detail of the previewed spell
	if cmb_sel >= 0 and not sm[cmb_sel].is_empty():
		var m: Dictionary = sm[cmb_sel]
		var dr := Rect2(Vector2(776, 870), Vector2(380, 150))
		_panel(dr, 12, Color(0, 0, 0, 0.85), C_ACC)
		_glyph(dr.position + Vector2(26, 30), SLOT_GLYPH[cmb_sel], 14)
		_text(F_D, dr.position + Vector2(50, 38), m["n"].to_upper(), 28, C_ACC)
		_text(F_UI, dr.position + Vector2(52 + _tw(F_D, m["n"].to_upper(), 28) + 8, 36), m["th"], 16, C_DIM)
		_hud.draw_multiline_string(F_UI, dr.position + Vector2(16, 68), m["d"], HORIZONTAL_ALIGNMENT_LEFT, dr.size.x - 32, 16, 2, C_INK)
		_text(F_D2, dr.position + Vector2(16, 136), "%d MP  →  เหลือ %d" % [_mp_cost(m), hd["mp"] - _mp_cost(m)], 22, C_MP if hd["mp"] >= _mp_cost(m) else C_BAD)


func _draw_hints(br: Vector2) -> void:
	var items := []
	if mode == "camp":
		items = [["dpad", "เลือกด่าน"], ["cross", "เริ่มด่าน"], ["triangle", "SYSTEM MENU"], ["lr", "ดูตัวละคร"]]
	elif state == "combo":
		items = [["dpad", "ดูเวท"], ["square", ""], ["triangle", ""], ["circle", "ร่าย"], ["cross", "จบคอมโบ"], ["lr", "เป้า"]]
	elif state == "magicks":
		items = [["dpad", "เลือก"], ["cross", "ร่าย"], ["circle", "ย้อนกลับ"], ["lr", "เป้า"]]
	elif state == "command":
		items = [["square", ""], ["triangle", ""], ["circle", ""], ["cross", "กดคำสั่งได้เลย"], ["lr", "เป้า"]]
	items.append(["opt", "เมนู" if mode == "battle" else "AUTO " + ("ON" if auto_battle else "OFF")])
	var x := br.x
	for k in range(items.size() - 1, -1, -1):
		var label: String = items[k][1]
		var tw := _tw(F_UI, label, 17)
		x -= tw
		_text(F_UI, Vector2(x, br.y), label, 17, C_INK if items[k][0] != "opt" or not auto_battle else C_ACC)
		x -= 22 if label != "" else 16
		_glyph(Vector2(x, br.y - 6), items[k][0])
		x -= 24


func _draw_actbox() -> void:
	var age := _t - _act_t
	if age > 1.6 or _act_text == "":
		return
	var a := clampf(minf(age * 8.0, (1.6 - age) * 4.0), 0.0, 1.0)
	var size := 32
	var w := _tw(F_D, _act_text, size) + 44
	var pos := Vector2(960 - w * 0.5, 150)
	var bg := (C_BAD if _act_enemy else C_ACC)
	_hud.draw_colored_polygon(_skew_poly(Rect2(pos, Vector2(w, 44)), 10), Color(bg, a))
	_text(F_D, pos + Vector2(22, 34), _act_text, size, Color((Color.WHITE if _act_enemy else C_ACC_INK), a))


func _draw_info() -> void:
	var age := _t - _info_t
	if age > 3.0 or _info == "":
		return
	var a := clampf(minf(age * 6.0, (3.0 - age) * 3.0), 0.0, 1.0)
	var w := _tw(F_UI2, _info, 19) + 40
	var r := Rect2(960 - w * 0.5, 204, w, 34)
	_hud.draw_rect(r, Color(0, 0, 0, 0.8 * a))
	_hud.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), Color(C_ACC, a))
	_text(F_UI2, r.position + Vector2(20, 25), _info, 19, Color(C_INK, a))


func _draw_pops() -> void:
	var keep := []
	for p in _pops:
		var age: float = _t - p["t0"]
		if age > 1.15:
			continue
		keep.append(p)
		var a := clampf((1.15 - age) * 3.0, 0.0, 1.0)
		var rise := -age * 46.0
		var size := 56
		var col := Color.WHITE
		match p["kind"]:
			"weak": col = C_ACC; size = 70
			"cmbd": col = Color("FFC6E2"); size = 62
			"heal": col = C_OK; size = 40
			"hurt": col = Color("FF8A8A"); size = 50
			"res": col = Color("9AA0B0"); size = 44
			"txt": size = 30
			"boost": col = C_GOLD; size = 34
		var pos: Vector2 = p["pos"] + Vector2(0, rise)
		_text(F_D, pos + Vector2(-260, 0), p["text"], size, Color(col, a), HORIZONTAL_ALIGNMENT_CENTER, 520, 10)
		if p["sub"] != "":
			var sw := _tw(F_D, p["sub"], 18) + 14
			var sb := Color(C_ACC, a) if p["kind"] == "weak" else Color(0, 0, 0, a)
			_tag(p["sub"], pos + Vector2(-sw * 0.5, 8), 18, sb, Color(C_ACC_INK, a) if p["kind"] == "weak" else Color(1, 1, 1, a))
	_pops = keep


func _draw_banner() -> void:
	var age := _t - _banner_t
	if age > 1.8 or _banner == "":
		return
	var a := clampf(minf(age * 6.0, (1.8 - age) * 3.0), 0.0, 1.0)
	var slide := (1.0 - clampf(age * 6.0, 0.0, 1.0)) * -60.0 + maxf(0.0, age - 1.4) * 80.0
	var size := 88
	var w := _tw(F_D, _banner, size) + 80
	var pos := Vector2(960 - w * 0.5 + slide, 380)
	_hud.draw_colored_polygon(_skew_poly(Rect2(pos + Vector2(12, 12), Vector2(w, 104)), 22), Color(_banner_col, a))
	_hud.draw_colored_polygon(_skew_poly(Rect2(pos, Vector2(w, 104)), 22), Color(0, 0, 0, a))
	_text(F_D, pos + Vector2(40, 86), _banner, size, Color(1, 1, 1, a))
	if _banner_sub != "":
		var sw := _tw(F_UI2, _banner_sub, 22) + 30
		_tag(_banner_sub, Vector2(960 - sw * 0.5 + slide, pos.y + 128), 22, Color(_banner_col, a), Color(C_ACC_INK, a), F_UI2)


func _draw_result() -> void:
	var age := _t - float(_result.get("t", 0.0))
	if age < 1.6:
		return
	var a := clampf((age - 1.6) * 4.0, 0.0, 1.0)
	_hud.draw_rect(Rect2(0, 0, 1920, 1080), Color(0, 0, 0, 0.55 * a))
	var win: bool = _result.get("win", false)
	var r := Rect2(560, 240, 800, 560 if win else 300)
	_panel(r, 22, Color(0.06, 0.065, 0.08, 0.96 * a), C_ACC if win else C_BAD)
	_text(F_D, r.position + Vector2(40, 74), "VICTORY" if win else "DEFEAT", 64, Color(C_ACC if win else C_BAD, a))
	var stg: Dictionary = D.STAGES[stage_i]
	_text(F_D2, r.position + Vector2(44, 108), "STAGE %d · %s · %d turns" % [stage_i + 1, stg["n"], turns], 20, Color(C_DIM, a))
	if win and not _result.get("loot", []).is_empty():
		var lx := r.position.x + 300
		_text(F_D, Vector2(lx, r.position.y + 74), "LOOT", 22, Color(C_GOLD, a))
		var lt := ", ".join(PackedStringArray(_result["loot"]))
		_hud.draw_multiline_string(F_UI, Vector2(lx + 70, r.position.y + 54), lt, HORIZONTAL_ALIGNMENT_LEFT, 420, 16, 3, Color(C_INK, a))
	if win:
		var y := r.position.y + 140
		for row in _result["rows"]:
			var hd := D.hero_def(row["id"])
			var u := {"side": "h", "id": row["id"]}
			_portrait(u, Rect2(r.position.x + 40, y, 64, 64))
			_text(F_D, Vector2(r.position.x + 120, y + 30), row["name"], 30, Color(C_INK, a))
			var lvt := "Lv %d" % row["lv"] if row["lv"] == row["lv0"] else "Lv %d → %d" % [row["lv0"], row["lv"]]
			_text(F_D, Vector2(r.position.x + 420, y + 30), lvt, 28, Color(C_ACC if row["lv"] > row["lv0"] else C_INK, a))
			if row["lv"] > row["lv0"]:
				_tag("LEVEL UP!", Vector2(r.position.x + 600, y + 6), 18, Color(C_PINK, a), Color(1, 1, 1, a))
			var need := D.exp_need(row["lv"])
			_bar(Rect2(r.position.x + 120, y + 42, 420, 10), float(row["exp"]) / need if row["lv"] < D.MAX_LV else 1.0, Color(C_GOLD, a))
			_text(F_D2, Vector2(r.position.x + 556, y + 54), "+%d EXP" % row["gain"], 18, Color(C_GOLD, a))
			var lx := r.position.x + 120
			for nm in row["learned"]:
				lx += _tag("NEW  " + str(nm).to_upper(), Vector2(lx, y + 60), 15, Color(C_ACC, a), Color(C_ACC_INK, a)) + 6
			y += 112
		var br := Rect2(r.end.x - 300, r.end.y - 70, 260, 50)
		_hud.draw_colored_polygon(_skew_poly(br, 10), Color(C_ACC, a))
		_glyph(br.position + Vector2(28, 25), "cross", 13)
		_text(F_D, br.position + Vector2(52, 36), "CONTINUE", 26, Color(C_ACC_INK, a))
		_hit(br, "res:0")
	else:
		_text(F_UI, r.position + Vector2(44, 160), "ลองเลเวลอัปที่ด่านก่อนหน้า หรือเปลี่ยนเวทคอมโบในแคมป์", 20, Color(C_INK, a))
		var b1 := Rect2(r.position.x + 40, r.end.y - 80, 300, 50)
		var b2 := Rect2(r.end.x - 340, r.end.y - 80, 300, 50)
		_hud.draw_colored_polygon(_skew_poly(b1, 10), Color(C_ACC, a))
		_glyph(b1.position + Vector2(28, 25), "cross", 13)
		_text(F_D, b1.position + Vector2(52, 36), "RETRY", 26, Color(C_ACC_INK, a))
		_hud.draw_colored_polygon(_skew_poly(b2, 10), Color(0.1, 0.1, 0.12, a))
		_glyph(b2.position + Vector2(28, 25), "circle", 13)
		_text(F_D, b2.position + Vector2(52, 36), "CAMP", 26, Color(C_INK, a))
		_hit(b1, "res:1")
		_hit(b2, "res:0")


# ================================================================ drawing: camp
func _draw_camp() -> void:
	# darken for readability
	var grad := PackedColorArray([Color(0, 0, 0, 0.82), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.82)])
	_hud.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1920, 0), Vector2(1920, 1080), Vector2(0, 1080)]), grad)
	# logo
	_text(F_D, Vector2(56, 112), "MANCER", 96, C_INK, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
	_tag("PARTY BATTLE · HD-2D", Vector2(62, 128), 18)
	# stages
	var sx := 56.0
	var sy := 200.0
	_text(F_D, Vector2(sx, sy), "STAGES", 26, C_ACC if camp_focus == "stage" else C_DIM)
	for i in D.STAGES.size():
		var s: Dictionary = D.STAGES[i]
		var r := Rect2(sx, sy + 16 + i * 104, 660, 94)
		var open := _stage_open(i)
		var sel := i == camp_stage
		var fill := Color(0.08, 0.085, 0.1, 0.92)
		if sel:
			fill = Color(C_ACC, 0.95) if camp_focus == "stage" else Color(0.22, 0.24, 0.12, 0.95)
		_hud.draw_colored_polygon(_chamfer(r, 14), fill)
		_outline(_chamfer(r, 14), C_LINE)
		_hit(r, "stage:%d" % i)
		var fg := C_ACC_INK if sel and camp_focus == "stage" else (C_INK if open else C_DIM)
		_text(F_D, r.position + Vector2(20, 62), "%d" % (i + 1), 56, C_ACC_INK if sel and camp_focus == "stage" else C_ACC)
		_text(F_D, r.position + Vector2(76, 42), s["n"], 32, fg)
		_text(F_UI, r.position + Vector2(78, 72), s["th"] + "  ·  แนะนำ Lv %d+" % s["lv"], 16, Color(fg, 0.8))
		var fx := r.end.x - 24
		var foes_el := D.stage_foes(i)
		for k in range(foes_el.size() - 1, -1, -1):
			_diamond(Vector2(fx, r.position.y + 70), 8, _el_col(foes_el[k]))
			fx -= 22
		if i in save["cleared"]:
			_tag("CLEAR", Vector2(r.end.x - 90, r.position.y + 12), 16, C_ACC_INK if sel and camp_focus == "stage" else C_ACC, C_ACC if sel and camp_focus == "stage" else C_ACC_INK)
		elif not open:
			_tag("LOCK", Vector2(r.end.x - 80, r.position.y + 12), 16, Color(0, 0, 0, 0.8), C_DIM)
	# party
	var px := 760.0
	var py := 200.0
	var pw := 1104.0
	_text(F_D, Vector2(px, py), "PARTY · COMBO MAGICKS", 26, C_ACC if camp_focus == "party" else C_DIM)
	for i in D.HEROES.size():
		var hd: Dictionary = D.HEROES[i]
		var tr := Rect2(px + i * 250, py + 16, 240, 64)
		var on := i == camp_hero
		_hud.draw_colored_polygon(_skew_poly(tr, 10), C_ACC if on else Color(0.08, 0.085, 0.1, 0.92))
		_portrait({"side": "h", "id": hd["id"]}, Rect2(tr.position + Vector2(14, 4), Vector2(56, 56)))
		var hs: Dictionary = save["heroes"][hd["id"]]
		_text(F_D, tr.position + Vector2(78, 32), hd["short"], 28, C_ACC_INK if on else C_INK)
		_text(F_D2, tr.position + Vector2(80, 56), "Lv %d" % hs["lv"], 18, C_ACC_INK if on else C_DIM)
		_diamond(tr.position + Vector2(220, 18), 7, _el_col(hd["el"]))
		_hit(tr, "hero:%d" % i)
	_glyph(Vector2(px + 770, py + 48), "lr")
	var hid := _camp_hero_id()
	var hd2 := D.hero_def(hid)
	var hs2: Dictionary = save["heroes"][hid]
	var lv := int(hs2["lv"])
	var st := D.final_stats(hid, hs2)
	var ir := Rect2(px, py + 96, pw, 120)
	_panel(ir, 14)
	_text(F_D, ir.position + Vector2(20, 46), hd2["name"], 40, C_INK)
	_text(F_UI, ir.position + Vector2(22, 76), hd2["th"], 17, C_DIM)
	var need := D.exp_need(lv)
	_text(F_D2, ir.position + Vector2(22, 106), "EXP", 16, C_DIM)
	_bar(Rect2(ir.position.x + 60, ir.position.y + 96, 260, 10), float(hs2["exp"]) / need if lv < D.MAX_LV else 1.0, C_GOLD)
	_text(F_D2, ir.position + Vector2(330, 107), "%d / %d" % [hs2["exp"], need], 16, C_DIM)
	var stx := ir.position.x + 470
	var stats := [["HP", st["mhp"]], ["MP", st["mmp"]], ["STR", st["str"]], ["MAG", st["mag"]], ["DEF", st["def"]], ["MDEF", st["mdef"]], ["SPD", st["spd"]]]
	for k in stats.size():
		var cx := stx + (k % 4) * 155
		var cy := ir.position.y + 44 + (k / 4) * 44
		_text(F_D2, Vector2(cx, cy), stats[k][0], 17, C_DIM)
		_text(F_D, Vector2(cx + 50, cy), "%d" % int(stats[k][1]), 26, C_INK)
	# combo slots
	var cr := Rect2(px, py + 232, pw, 84)
	_panel(cr, 14, Color(0.1, 0.06, 0.09, 0.92), C_PINK)
	_text(F_D, cr.position + Vector2(20, 34), "COMBO SET", 22, C_PINK)
	_text(F_UI, cr.position + Vector2(20, 62), "เวท 3 อย่างที่ใช้ในโหมดคอมโบ", 14, C_DIM)
	for s in 3:
		var m := D.magick(hid, hs2["set"][s])
		var sr := Rect2(cr.position.x + 230 + s * 290, cr.position.y + 12, 278, 60)
		_hud.draw_colored_polygon(_skew_poly(sr, 10), Color(0, 0, 0, 0.7))
		_outline(_skew_poly(sr, 10), _el_col(m.get("el", "None")) if not m.is_empty() else C_LINE)
		_glyph(sr.position + Vector2(30, 30), SLOT_GLYPH[s], 15)
		_text(F_D, sr.position + Vector2(56, 30), m["n"].to_upper() if not m.is_empty() else "—", 24, C_INK)
		if not m.is_empty():
			_text(F_D2, sr.position + Vector2(58, 52), "%d MP · %s" % [_mp_cost(m), D.KIND_TAG[D.kind(m)]], 15, C_MP)
		_hit(sr, "slot:%d" % s)
	# magicks list
	var all: Array = D.MAGICKS[hid]
	var lr := Rect2(px, py + 332, pw, 44 * all.size() + 20)
	_panel(lr, 14, Color(0.06, 0.065, 0.08, 0.94))
	for i in all.size():
		var m: Dictionary = all[i]
		var locked: bool = m["lv"] > lv
		var y := lr.position.y + 10 + i * 44
		var rr := Rect2(lr.position.x + 10, y, pw - 24, 40)
		var sel := i == camp_mag and camp_focus == "party"
		if sel:
			_hud.draw_colored_polygon(_skew_poly(rr, 8), C_ACC)
		_hit(rr, "cmag:%d" % i)
		var fg := C_ACC_INK if sel else (C_DIM if locked else C_INK)
		var kd := D.kind(m)
		_kind_icon(Vector2(rr.position.x + 20, y + 21), kd, fg if sel or locked else _el_col(m["el"]))
		_text(F_D, Vector2(rr.position.x + 40, y + 30), m["n"].to_upper(), 24, fg)
		_text(F_UI, Vector2(rr.position.x + 250, y + 28), m["th"] + "  ·  " + D.KIND_TAG[kd], 15, Color(fg, 0.8))
		_hud.draw_string(F_UI, Vector2(rr.position.x + 440, y + 28), m["d"], HORIZONTAL_ALIGNMENT_LEFT, 480, 14, Color(fg, 0.75))
		if locked:
			_tag("Lv %d" % m["lv"], Vector2(rr.end.x - 70, y + 8), 16, Color(0, 0, 0, 0.8), C_DIM)
		else:
			_text(F_D2, Vector2(rr.end.x - 14, y + 30), "%d MP" % _mp_cost(m), 20, C_ACC_INK if sel else C_MP, HORIZONTAL_ALIGNMENT_RIGHT, 0)
			var slot: int = hs2["set"].find(m["id"])
			if slot >= 0:
				_glyph(Vector2(rr.end.x - 100, y + 21), SLOT_GLYPH[slot], 12)
	# start button
	var br := Rect2(sx, 870, 660, 70)
	var open2 := _stage_open(camp_stage)
	_hud.draw_colored_polygon(_skew_poly(br, 14), C_ACC if open2 else Color(0.15, 0.15, 0.17))
	_glyph(br.position + Vector2(40, 35), "cross", 16)
	_text(F_D, br.position + Vector2(70, 50), "START  STAGE %d" % (camp_stage + 1), 38, C_ACC_INK if open2 else C_DIM)
	_hit(br, "stage:%d" % camp_stage)
	var mr := Rect2(sx, 956, 660, 56)
	_hud.draw_colored_polygon(_skew_poly(mr, 12), Color(0.1, 0.1, 0.13, 0.95))
	_outline(_skew_poly(mr, 12), Color("4FE0B0"))
	_glyph(mr.position + Vector2(40, 28), "triangle", 15)
	_text(F_D, mr.position + Vector2(70, 40), "SYSTEM MENU", 30, C_INK)
	_text(F_UI, Vector2(mr.end.x - 24, mr.position.y + 37), "ไอเท็ม · เวท · ของสวมใส่ · สกิลทรี · ตั้งค่า", 16, C_DIM, HORIZONTAL_ALIGNMENT_RIGHT, 0)
	_hit(mr, "sysm:0")
	if not sysm.open:
		_draw_hints(Vector2(1920 - 56, 1080 - 20))
