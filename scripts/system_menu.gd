extends RefCounted
## SYSTEM MENU (camp only, △) — FF-style main menu:
##   ITEMS · MAGICKS (combo set) · EQUIPMENT · SKILL TREE · OPTIONS
## Pages list on the left (↑↓ + ✕ to enter, ○ back). Inside a page L1 / R1 switches hero.
## Drawn with BattleUI's helpers (ui = the BattleUI node).

const D := preload("res://scripts/mancer_data.gd")
const SAVE := preload("res://scripts/mancer_save.gd")

const C_ACC := Color("E4FF32")
const C_INK := Color("F2F2EC")
const C_DIM := Color("8E919B")
const C_INKD := Color("0A0B0C")
const C_LINE := Color("33363F")
const C_MP := Color("3AD3FF")
const C_GOLD := Color("FFD23A")
const C_OK := Color("7CFFB2")
const C_BAD := Color("FF5A6A")
const C_PINK := Color("FF3F9A")

const PAGES := [["ITEMS", "ไอเท็ม"], ["MAGICKS", "เวท / คอมโบ"], ["EQUIPMENT", "ของสวมใส่"], ["SKILL TREE", "สกิลทรี"], ["OPTIONS", "ตั้งค่า"]]
const SLOT_GLYPH := ["square", "triangle", "circle"]

var ui
var open := false
var focus := "pages"      # pages, page, equip_list
var page := 0
var hero := 0
var cur := 0              # cursor inside a page
var tree_c := Vector2i(0, 0)
var eq_list := 0
var reset_armed := false


func _init(owner) -> void:
	ui = owner


func show() -> void:
	open = true
	focus = "pages"
	cur = 0
	reset_armed = false
	ui._sfx("confirm")


func _save() -> void:
	SAVE.save_game(ui.save)


func _hid() -> String:
	return D.HEROES[hero]["id"]


func _hs() -> Dictionary:
	return ui.save["heroes"][_hid()]


# ---------------------------------------------------------------- input
func input(ev: InputEvent) -> void:
	var up: bool = ev.is_action_pressed("m_up", true)
	var down: bool = ev.is_action_pressed("m_down", true)
	var left: bool = ev.is_action_pressed("m_left", true)
	var right: bool = ev.is_action_pressed("m_right", true)
	var ok: bool = ev.is_action_pressed("m_cross")
	var back: bool = ev.is_action_pressed("m_circle") or ev.is_action_pressed("m_back")
	if up or down or left or right:
		ui._sfx("cursor", -8.0)
	if ev.is_action_pressed("m_l1") or ev.is_action_pressed("m_r1"):
		hero = posmod(hero + (-1 if ev.is_action_pressed("m_l1") else 1), D.HEROES.size())
		focus = "page" if focus == "equip_list" else focus
		ui._sfx("cursor", -6.0)
		return
	if focus == "pages":
		if up: page = posmod(page - 1, PAGES.size())
		elif down: page = posmod(page + 1, PAGES.size())
		elif ok:
			focus = "page"
			cur = 0
			tree_c = Vector2i(0, 0)
			reset_armed = false
			ui._sfx("confirm")
		elif back or ev.is_action_pressed("m_triangle"):
			open = false
			ui._sfx("cancel")
		return
	if focus == "equip_list":
		var lst := _equip_choices()
		if up: eq_list = posmod(eq_list - 1, lst.size())
		elif down: eq_list = posmod(eq_list + 1, lst.size())
		elif ok:
			_equip(D.SLOTS[cur], lst[eq_list])
			focus = "page"
		elif back:
			focus = "page"
			ui._sfx("cancel")
		return
	if back:
		focus = "pages"
		ui._sfx("cancel")
		return
	match page:
		0: _items_input(up, down, ok)
		1: _magicks_input(ev, up, down)
		2: _equip_input(up, down, ok)
		3: _tree_input(up, down, left, right, ok)
		4: _options_input(up, down, left, right, ok)


func mouse(id: String, i: int, click: bool) -> void:
	match id:
		"sm_page":
			page = i
			if click:
				focus = "page"
				cur = 0
				ui._sfx("confirm")
		"sm_hero":
			if click:
				hero = i
		"sm_row":
			focus = "page" if focus != "equip_list" else focus
			cur = i
			if page == 3:
				tree_c = Vector2i(i % 3, i / 3)
			if click:
				match page:
					0: _use_item()
					2:
						focus = "equip_list"
						eq_list = 0
					3: _learn()
					4: _option_change(1, true)
		"sm_slot":
			if click and page == 1:
				_assign(i)
		"sm_eq":
			eq_list = i
			if click:
				_equip(D.SLOTS[cur], _equip_choices()[i])
				focus = "page"
		"sm_close":
			if click:
				open = false


# ---------------------------------------------------------------- items
func _item_list() -> Array:
	var out := []
	for k in D.ITEMS:
		if int(ui.save["items"].get(k, 0)) > 0:
			out.append(k)
	return out


func _items_input(up: bool, down: bool, ok: bool) -> void:
	var lst := _item_list()
	if lst.is_empty():
		return
	if up: cur = posmod(cur - 1, lst.size())
	elif down: cur = posmod(cur + 1, lst.size())
	elif ok: _use_item()


func _use_item() -> void:
	var lst := _item_list()
	if cur >= lst.size():
		return
	var k: String = lst[cur]
	var it: Dictionary = D.ITEMS[k]
	var hs := _hs()
	var u: Dictionary = it["use"]
	if u.has("exp"):
		if int(hs["lv"]) >= D.MAX_LV:
			ui._deny("เลเวลสูงสุดแล้ว")
			return
		hs["exp"] = int(hs["exp"]) + int(u["exp"])
		var lv0 := int(hs["lv"])
		while int(hs["lv"]) < D.MAX_LV and int(hs["exp"]) >= D.exp_need(int(hs["lv"])):
			hs["exp"] = int(hs["exp"]) - D.exp_need(int(hs["lv"]))
			hs["lv"] = int(hs["lv"]) + 1
		if int(hs["lv"]) > lv0:
			ui._pop_screen("LEVEL UP!  Lv %d" % int(hs["lv"]), Vector2(1200, 300), "boost")
	elif u.has("sp"):
		hs["sp_bonus"] = int(hs.get("sp_bonus", 0)) + int(u["sp"])
	elif u.has("reset"):
		if hs.get("tree", []).is_empty():
			ui._deny("ยังไม่ได้เรียนสกิลทรี")
			return
		hs["tree"] = []
	ui.save["items"][k] = int(ui.save["items"][k]) - 1
	ui._sfx("special")
	ui._pop_screen("%s → %s" % [it["n"].to_upper(), D.HEROES[hero]["short"]], Vector2(1200, 340), "heal")
	cur = clampi(cur, 0, maxi(0, _item_list().size() - 1))
	_save()


# ---------------------------------------------------------------- magicks
func _magicks_input(ev: InputEvent, up: bool, down: bool) -> void:
	var all: Array = D.MAGICKS[_hid()]
	if up: cur = posmod(cur - 1, all.size())
	elif down: cur = posmod(cur + 1, all.size())
	else:
		for i in 3:
			if ev.is_action_pressed(["m_square", "m_triangle", "m_circle"][i]):
				_assign(i)


func _assign(slot: int) -> void:
	var hs := _hs()
	var m: Dictionary = D.MAGICKS[_hid()][cur]
	if m["lv"] > int(hs["lv"]):
		ui._deny("ปลดล็อกที่ Lv %d" % m["lv"])
		return
	var st: Array = hs["set"]
	var old := st.find(m["id"])
	if old >= 0:
		st[old] = st[slot]
	st[slot] = m["id"]
	ui._sfx("confirm")
	_save()


# ---------------------------------------------------------------- equipment
func _owner_of(eid: String) -> String:
	for h in D.HEROES:
		if ui.save["heroes"][h["id"]].get("eq", {}).values().has(eid):
			return h["id"]
	return ""


func _equip_choices() -> Array:
	var sl: String = D.SLOTS[cur]
	var out := [""]
	for eid in ui.save["equips"]:
		if D.EQUIPS.has(eid) and D.EQUIPS[eid]["slot"] == sl:
			out.append(eid)
	return out


func _equip_input(up: bool, down: bool, ok: bool) -> void:
	if up: cur = posmod(cur - 1, 3)
	elif down: cur = posmod(cur + 1, 3)
	elif ok:
		focus = "equip_list"
		eq_list = 0
		ui._sfx("confirm")


func _equip(sl: String, eid: String) -> void:
	var hs := _hs()
	if eid != "":
		var ow := _owner_of(eid)
		if ow != "" and ow != _hid():
			ui.save["heroes"][ow]["eq"].erase(sl)
	if not hs.has("eq"):
		hs["eq"] = {}
	if eid == "":
		hs["eq"].erase(sl)
	else:
		hs["eq"][sl] = eid
	ui._sfx("confirm")
	_save()


# ---------------------------------------------------------------- skill tree
func _tree_input(up: bool, down: bool, left: bool, right: bool, ok: bool) -> void:
	if up: tree_c.y = posmod(tree_c.y - 1, 3)
	elif down: tree_c.y = posmod(tree_c.y + 1, 3)
	elif left: tree_c.x = posmod(tree_c.x - 1, 3)
	elif right: tree_c.x = posmod(tree_c.x + 1, 3)
	elif ok: _learn()
	cur = tree_c.y * 3 + tree_c.x


func _node_at(br: int, t: int) -> Dictionary:
	for n in D.TREE:
		if n["br"] == br and n["t"] == t:
			return n
	return {}


func _tree_why(n: Dictionary) -> String:
	var hs := _hs()
	var learned: Array = hs.get("tree", [])
	if n["id"] in learned:
		return "เรียนแล้ว"
	if n["t"] > 0 and not _node_at(n["br"], n["t"] - 1)["id"] in learned:
		return "ต้องเรียนขั้นก่อนหน้า"
	if D.sp_total(hs) - D.sp_spent(hs) < int(n["cost"]):
		return "SP ไม่พอ"
	return ""


func _learn() -> void:
	var n := _node_at(tree_c.x, tree_c.y)
	var why := _tree_why(n)
	if why != "":
		ui._deny(why)
		return
	var hs := _hs()
	if not hs.has("tree"):
		hs["tree"] = []
	hs["tree"].append(n["id"])
	ui._sfx("special")
	ui._pop_screen("LEARNED  " + n["n"].to_upper(), Vector2(1200, 300), "boost")
	_save()


# ---------------------------------------------------------------- options
func _opt_rows() -> Array:
	var o: Dictionary = ui.save["opt"]
	return [
		["AUTO BATTLE", "ON" if ui.auto_battle else "OFF"],
		["BATTLE SPEED", "×%d" % int(ui.battle_speed)],
		["MUSIC", "%d dB" % int(o.get("music", -10.0))],
		["SOUND FX", "%d dB" % int(o.get("sfx", -4.0))],
		["RESET SAVE", "กด ✕ อีกครั้งเพื่อยืนยัน" if reset_armed else "ลบเซฟทั้งหมด"],
	]


func _options_input(up: bool, down: bool, left: bool, right: bool, ok: bool) -> void:
	if up:
		cur = posmod(cur - 1, 5)
		reset_armed = false
	elif down:
		cur = posmod(cur + 1, 5)
		reset_armed = false
	elif left: _option_change(-1, false)
	elif right: _option_change(1, false)
	elif ok: _option_change(1, true)


func _option_change(dir: int, confirm: bool) -> void:
	var o: Dictionary = ui.save["opt"]
	match cur:
		0:
			ui.auto_battle = not ui.auto_battle
			o["auto"] = ui.auto_battle
		1:
			ui.battle_speed = 2.0 if ui.battle_speed < 2.0 else 1.0
			o["speed"] = ui.battle_speed
		2:
			o["music"] = clampf(float(o.get("music", -10.0)) + 2.0 * dir, -40.0, 6.0)
			ui.music_db = o["music"]
			ui._bgm.volume_db = ui.music_db - 10.0
		3:
			o["sfx"] = clampf(float(o.get("sfx", -4.0)) + 2.0 * dir, -40.0, 6.0)
			ui.sfx_db = o["sfx"]
		4:
			if not confirm:
				return
			if not reset_armed:
				reset_armed = true
				ui._sfx("deny")
				return
			ui.save = SAVE.fresh()
			reset_armed = false
			ui.camp_stage = 0
			ui._preview_stage()
			ui._pop_screen("RESET", Vector2(1200, 300), "txt")
	ui._sfx("confirm")
	_save()


# ---------------------------------------------------------------- drawing
func draw() -> void:
	var h = ui._hud
	h.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.02, 0.025, 0.04, 0.86))
	ui._text(ui.F_D, Vector2(60, 100), "SYSTEM MENU", 64, C_INK)
	ui._tag("CAMP", Vector2(66, 116), 18)
	# close button
	var cr := Rect2(1920 - 60 - 170, 50, 170, 44)
	h.draw_colored_polygon(ui._skew_poly(cr, 9), Color(0, 0, 0, 0.6))
	ui._glyph(cr.position + Vector2(28, 22), "triangle", 14)
	ui._text(ui.F_D, cr.position + Vector2(52, 31), "CLOSE", 22, C_INK)
	ui._hit(cr, "sm_close:0")
	# page list
	for i in PAGES.size():
		var r := Rect2(60, 180 + i * 84, 330, 70)
		var sel := i == page
		var bg := C_ACC if sel and focus == "pages" else (Color(0.25, 0.27, 0.12) if sel else Color(0.08, 0.085, 0.1, 0.95))
		h.draw_colored_polygon(ui._skew_poly(r, 12), bg)
		var fg := C_INKD if sel and focus == "pages" else (C_ACC if sel else C_INK)
		ui._text(ui.F_D, r.position + Vector2(26, 42), PAGES[i][0], 32, fg)
		ui._text(ui.F_UI, r.position + Vector2(28, 62), PAGES[i][1], 14, Color(fg, 0.7))
		ui._hit(r, "sm_page:%d" % i)
	# hero bar (pages that use a hero)
	if page != 4:
		for i in D.HEROES.size():
			var hd: Dictionary = D.HEROES[i]
			var hs: Dictionary = ui.save["heroes"][hd["id"]]
			var r := Rect2(440 + i * 300, 160, 286, 76)
			var on := i == hero
			h.draw_colored_polygon(ui._skew_poly(r, 10), Color(C_ACC, 0.95) if on else Color(0.08, 0.085, 0.1, 0.95))
			ui._portrait({"side": "h", "id": hd["id"]}, Rect2(r.position + Vector2(14, 6), Vector2(64, 64)))
			ui._text(ui.F_D, r.position + Vector2(86, 36), hd["short"], 30, C_INKD if on else C_INK)
			ui._text(ui.F_D2, r.position + Vector2(88, 62), "Lv %d · SP %d" % [hs["lv"], D.sp_total(hs) - D.sp_spent(hs)], 18, C_INKD if on else C_DIM)
			ui._hit(r, "sm_hero:%d" % i)
		ui._glyph(Vector2(1360, 198), "lr")
	var body := Rect2(440, 256, 1420, 740)
	ui._panel(body, 16, Color(0.05, 0.055, 0.07, 0.96))
	match page:
		0: _draw_items(body)
		1: _draw_magicks(body)
		2: _draw_equip(body)
		3: _draw_tree(body)
		4: _draw_options(body)
	# hints
	var hint := "↑↓ เลือกหน้า · ✕ เข้า · ○/△ ปิด"
	if focus != "pages":
		hint = ["✕ ใช้กับตัวละครที่เลือก · L1/R1 เปลี่ยนตัว · ○ กลับ", "□ △ ○ ตั้งเป็นเวทคอมโบ · L1/R1 เปลี่ยนตัว · ○ กลับ",
			"✕ เปลี่ยนของ · L1/R1 เปลี่ยนตัว · ○ กลับ", "ลูกศร เลือก · ✕ เรียน · L1/R1 เปลี่ยนตัว · ○ กลับ", "←→ ปรับค่า · ✕ ยืนยัน · ○ กลับ"][page]
	ui._text(ui.F_UI, Vector2(1860, 1050), hint, 18, C_INK, HORIZONTAL_ALIGNMENT_RIGHT)


func _row_sel(r: Rect2, sel: bool) -> void:
	if sel:
		ui._hud.draw_colored_polygon(ui._skew_poly(r, 8), C_ACC if focus != "pages" else Color(C_ACC, 0.3))


func _draw_items(b: Rect2) -> void:
	var lst := _item_list()
	ui._text(ui.F_D, b.position + Vector2(30, 50), "ITEMS", 30, C_ACC)
	if lst.is_empty():
		ui._text(ui.F_UI, b.position + Vector2(30, 100), "ยังไม่มีไอเท็ม — ได้จากการชนะด่าน", 20, C_DIM)
		return
	for i in lst.size():
		var k: String = lst[i]
		var it: Dictionary = D.ITEMS[k]
		var r := Rect2(b.position.x + 20, b.position.y + 80 + i * 64, b.size.x - 40, 56)
		var sel := i == cur
		_row_sel(r, sel and focus == "page")
		var fg := C_INKD if sel and focus == "page" else C_INK
		ui._text(ui.F_D, r.position + Vector2(24, 38), it["n"].to_upper(), 30, fg)
		ui._text(ui.F_UI, r.position + Vector2(300, 36), it["th"] + "  ·  " + it["d"], 18, Color(fg, 0.8))
		ui._text(ui.F_D, Vector2(r.end.x - 24, r.position.y + 40), "×%d" % int(ui.save["items"][k]), 30, fg, HORIZONTAL_ALIGNMENT_RIGHT)
		ui._hit(r, "sm_row:%d" % i)


func _draw_magicks(b: Rect2) -> void:
	var hid := _hid()
	var hs := _hs()
	var lv := int(hs["lv"])
	ui._text(ui.F_D, b.position + Vector2(30, 50), "COMBO SET", 30, C_PINK)
	for s in 3:
		var m := D.magick(hid, hs["set"][s])
		var sr := Rect2(b.position.x + 260 + s * 380, b.position.y + 18, 360, 52)
		ui._hud.draw_colored_polygon(ui._skew_poly(sr, 10), Color(0, 0, 0, 0.7))
		ui._outline(ui._skew_poly(sr, 10), C_PINK)
		ui._glyph(sr.position + Vector2(28, 26), SLOT_GLYPH[s], 15)
		ui._text(ui.F_D, sr.position + Vector2(54, 36), m["n"].to_upper() if not m.is_empty() else "—", 26, C_INK)
		ui._hit(sr, "sm_slot:%d" % s)
	var all: Array = D.MAGICKS[hid]
	for i in all.size():
		var m: Dictionary = all[i]
		var locked: bool = m["lv"] > lv
		var r := Rect2(b.position.x + 20, b.position.y + 90 + i * 62, b.size.x - 40, 56)
		var sel := i == cur and focus == "page"
		_row_sel(r, sel)
		var fg := C_INKD if sel else (C_DIM if locked else C_INK)
		var kd := D.kind(m)
		ui._kind_icon(Vector2(r.position.x + 22, r.position.y + 28), kd, fg if sel or locked else ui._el_col(m["el"]))
		ui._text(ui.F_D, r.position + Vector2(44, 38), m["n"].to_upper(), 28, fg)
		ui._text(ui.F_UI, r.position + Vector2(300, 36), m["th"] + "  ·  " + D.KIND_TAG[kd], 16, Color(fg, 0.8))
		ui._hud.draw_string(ui.F_UI, r.position + Vector2(520, 36), m["d"], HORIZONTAL_ALIGNMENT_LEFT, 640, 16, Color(fg, 0.75))
		if locked:
			ui._tag("Lv %d" % m["lv"], Vector2(r.end.x - 80, r.position.y + 14), 18, Color(0, 0, 0, 0.8), C_DIM)
		else:
			ui._text(ui.F_D2, Vector2(r.end.x - 20, r.position.y + 38), "%d MP" % ui._mp_cost(m), 22, C_INKD if sel else C_MP, HORIZONTAL_ALIGNMENT_RIGHT)
			var slot: int = hs["set"].find(m["id"])
			if slot >= 0:
				ui._glyph(Vector2(r.end.x - 120, r.position.y + 28), SLOT_GLYPH[slot], 13)
		ui._hit(r, "sm_row:%d" % i)


func _stat_line(hs: Dictionary) -> String:
	var st := D.final_stats(_hid(), hs)
	return "HP %d   MP %d   STR %d   MAG %d   DEF %d   MDEF %d   SPD %d" % [st["mhp"], st["mmp"], st["str"], st["mag"], st["def"], st["mdef"], st["spd"]]


func _draw_equip(b: Rect2) -> void:
	var hs := _hs()
	ui._text(ui.F_D, b.position + Vector2(30, 50), "EQUIPMENT", 30, C_ACC)
	ui._text(ui.F_D2, b.position + Vector2(30, 88), _stat_line(hs), 22, C_INK)
	for i in 3:
		var sl: String = D.SLOTS[i]
		var eid: String = hs.get("eq", {}).get(sl, "")
		var r := Rect2(b.position.x + 20, b.position.y + 120 + i * 84, 640, 74)
		var sel := i == cur and focus != "pages"
		_row_sel(r, sel)
		var fg := C_INKD if sel else C_INK
		ui._text(ui.F_UI2, r.position + Vector2(24, 28), D.SLOT_TH[sl] + "  " + sl.to_upper(), 16, Color(fg, 0.7))
		if eid != "":
			var e: Dictionary = D.EQUIPS[eid]
			ui._text(ui.F_D, r.position + Vector2(24, 60), e["n"].to_upper(), 30, fg)
			ui._text(ui.F_UI, r.position + Vector2(300, 58), e["d"], 17, Color(fg, 0.8))
		else:
			ui._text(ui.F_D, r.position + Vector2(24, 60), "— EMPTY —", 28, Color(fg, 0.5))
		ui._hit(r, "sm_row:%d" % i)
	# list for the chosen slot
	var lst := _equip_choices()
	var lr := Rect2(b.position.x + 700, b.position.y + 120, 690, 74 * 6)
	ui._text(ui.F_D, lr.position + Vector2(0, -12), "OWNED · " + D.SLOT_TH[D.SLOTS[cur]], 22, C_ACC if focus == "equip_list" else C_DIM)
	for i in lst.size():
		var eid: String = lst[i]
		var r := Rect2(lr.position.x, lr.position.y + i * 66, lr.size.x, 58)
		var sel := focus == "equip_list" and i == eq_list
		_row_sel(r, sel)
		var fg := C_INKD if sel else C_INK
		if eid == "":
			ui._text(ui.F_D, r.position + Vector2(20, 38), "(ถอดออก)", 24, Color(fg, 0.7))
		else:
			var e: Dictionary = D.EQUIPS[eid]
			ui._text(ui.F_D, r.position + Vector2(20, 38), e["n"].to_upper(), 26, fg)
			ui._text(ui.F_UI, r.position + Vector2(250, 36), e["d"], 16, Color(fg, 0.8))
			var ow := _owner_of(eid)
			if ow != "":
				ui._tag(D.hero_def(ow)["short"], Vector2(r.end.x - 90, r.position.y + 14), 16, Color(0, 0, 0, 0.8), C_GOLD)
		ui._hit(r, "sm_eq:%d" % i)


func _draw_tree(b: Rect2) -> void:
	var hs := _hs()
	var learned: Array = hs.get("tree", [])
	var spl := D.sp_total(hs) - D.sp_spent(hs)
	ui._text(ui.F_D, b.position + Vector2(30, 50), "SKILL TREE", 30, C_ACC)
	ui._text(ui.F_D, b.position + Vector2(260, 50), "SP %d" % spl, 30, C_GOLD)
	ui._text(ui.F_UI, b.position + Vector2(380, 48), "ได้ 1 SP ทุกเลเวลอัป + Skill Seed", 16, C_DIM)
	var cw := 440.0
	for br in 3:
		var x := b.position.x + 40 + br * cw
		ui._text(ui.F_D, Vector2(x, b.position.y + 108), D.BRANCH_TH[br], 22, C_INK)
		for t in 3:
			var n := _node_at(br, t)
			var r := Rect2(x, b.position.y + 140 + t * 190, 380, 140)
			var have: bool = n["id"] in learned
			var sel := tree_c == Vector2i(br, t) and focus == "page"
			var can := _tree_why(n) == ""
			if t > 0:
				var pc := Vector2(x + 190, r.position.y - 50)
				ui._hud.draw_line(pc, Vector2(x + 190, r.position.y), C_ACC if have else C_LINE, 4.0)
			var bg := Color(0.08, 0.085, 0.1)
			if have:
				bg = Color(0.18, 0.22, 0.06)
			if sel:
				bg = C_ACC
			ui._hud.draw_colored_polygon(ui._chamfer(r, 16), bg)
			ui._outline(ui._chamfer(r, 16), C_ACC if have else (C_GOLD if can else C_LINE), 2.0)
			var fg := C_INKD if sel else (C_INK if have or can else C_DIM)
			ui._text(ui.F_D, r.position + Vector2(20, 42), n["n"].to_upper(), 30, fg)
			ui._text(ui.F_UI, r.position + Vector2(22, 70), n["th"], 16, Color(fg, 0.8))
			ui._hud.draw_string(ui.F_UI, r.position + Vector2(22, 104), n["d"], HORIZONTAL_ALIGNMENT_LEFT, 340, 17, fg)
			ui._text(ui.F_D, Vector2(r.end.x - 18, r.position.y + 42), "LEARNED" if have else "%d SP" % n["cost"], 22, fg if sel else (C_ACC if have else C_GOLD), HORIZONTAL_ALIGNMENT_RIGHT)
			ui._hit(r, "sm_row:%d" % (t * 3 + br))


func _draw_options(b: Rect2) -> void:
	ui._text(ui.F_D, b.position + Vector2(30, 50), "OPTIONS", 30, C_ACC)
	var rows := _opt_rows()
	for i in rows.size():
		var r := Rect2(b.position.x + 20, b.position.y + 80 + i * 76, 900, 66)
		var sel := i == cur and focus == "page"
		var danger := i == 4
		if sel:
			ui._hud.draw_colored_polygon(ui._skew_poly(r, 8), C_BAD if danger else C_ACC)
		var fg := (Color.WHITE if danger else C_INKD) if sel else (C_BAD if danger else C_INK)
		ui._text(ui.F_D, r.position + Vector2(24, 44), rows[i][0], 30, fg)
		ui._text(ui.F_D if i < 4 else ui.F_UI2, Vector2(r.end.x - 24, r.position.y + 44), rows[i][1], 24, fg, HORIZONTAL_ALIGNMENT_RIGHT)
		ui._hit(r, "sm_row:%d" % i)
