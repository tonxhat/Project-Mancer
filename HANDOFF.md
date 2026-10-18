# Mancer HD-2D — ไฟล์ส่งต่อสำหรับแชทใหม่ (18 ต.ค. 2026)

> แนบไฟล์ zip นี้ในแชทใหม่ แล้วบอก Claude ว่า "อ่าน HANDOFF.md ก่อน"
> main.tscn และ project.godot ในชุดนี้คือ **ค่าล่าสุดของผู้ใช้ (master)** ห้ามเขียนทับ ให้เพิ่มหรือแก้เฉพาะจุดเท่านั้น

## 1. โปรเจกต์คืออะไร
- ฉากต่อสู้ turn-based แบบ HD-2D (สไปรต์พิกเซลยืนในโลก 3D แบบ Octopath) ของเกม **Mancer** ซึ่งเด่นเรื่องการผสมธาตุ
- Godot **4.7.1** ใช้ Forward+ บนจอ PC แนวนอน 1920×1080 · ผู้ใช้เป็นอาร์ตทิสต์ ใช้ Windows 11 และจอย PS5
- เกมเก่า (เว็บ แนวตั้งมือถือ) ที่เป็นต้นทาง asset และสไตล์ UI: https://claude.ai/artifact/FMGt4LMd7Pod2FodLSq1Ds
- เอกสารบทเรียน/การออกแบบ (Claude Docs มีแท็บรายสัปดาห์ แท็บ UI และแท็บฉาก 6 ด่าน): https://claude.ai/code/artifact/f01de023-9b28-4ce2-b19a-b65c1da5d3a2
- แชท ChatGPT ที่ใช้เจ็นอาร์ตฉาก (มีภาพ style reference S2–S6 + Verdant Field อยู่แล้ว): https://chatgpt.com/c/6acb91f7-5c08-83ec-ba06-d0f4e5e64b4f

## 2. วิธีทำงานที่ผู้ใช้ต้องการ
- ตอบเป็น **ภาษาไทย**
- ทุกครั้งที่ส่งงาน บอก (1) แก้อะไรไปบ้าง (2) ข้อกังวลและผลกระทบ (3) ขนาดไฟล์ zip (4) **ลิงก์เกม + ลิงก์เอกสาร**
- อัปเดตเอกสารทุก ~5 รอบ หรือเมื่อมีระบบใหม่
- ถ้างานจะใช้เวลาเกิน ~30 นาที ให้เตือนก่อน (เรื่องค่า token)
- ไฟล์ main.tscn / project.godot ที่ผู้ใช้อัปโหลดมาคือ master ให้เก็บค่าของเขาไว้ และแก้เฉพาะสิ่งที่ต้องเพิ่ม
- พรอมพ์ภาพสำหรับ ChatGPT ต้องเป็นบล็อกเดียวที่ก๊อปวางได้เลย ระบุตำแหน่งเลเยอร์ชัดเจน
- ChatGPT: ผู้ใช้ล็อกอินเอง ห้ามกรอกรหัสผ่าน ห้ามซื้อเครดิต

## 3. โครงสร้างฉาก main.tscn (โหนดหลัก)
| โหนด | หน้าที่ |
| --- | --- |
| **Look** (root, `scripts/look.gd`) | แผงคุมลุคทั้งหมด: Sun, ambient, Camera, Tilt-shift, DOF, สี/glow/หมอก |
| Ground, DirtPath1, Backdrop (Sky/Mountains/TreeLine), Props | ด่าน 1 Verdant Field (DirtPath2 ถูกซ่อนไว้ ถนนเหลือเลนเดียวกว้าง 3.19 ม.) |
| Actors (`actor_look.gd`) | Terramancer, Pyromancer, Hydromancer, MagmaBeast (`pixel_actor.gd`) + Aura + SpellCaster |
| **StageSet** (`stage_set.gd`) | เลือกด่าน + FieldPreset + ด่าน Coast/Cave/Peak/Marsh/Spire (instance แบบ editable children) |
| BattleDemo | ลูปโชว์ (ปิดอัตโนมัติเมื่อมี BattleUI) |
| VFX (`vfx_settings.gd`) | ค่ารวมของเอฟเฟกต์เวท (Style = Sprite / HD / Pixel) |
| Combos/Lava, Combos/Steam | เวทผสมธาตุ |
| FocusVignette, TiltShift | เลเยอร์จอ |
| BattleUI (`ui/battle_ui.tscn`) | **ตัวเกมทั้งหมด** (แคมป์ → ต่อสู้ปาร์ตี้ 3 คน Timeline/Magicks/Combo → ผลลัพธ์) จอย PS5 + คีย์บอร์ด + เมาส์ |
| Atmosphere (`atmosphere.gd`) | ลม ฝุ่น ลำแสง เงาเมฆ |

## 4. ระบบด่าน (สำคัญ อ่านก่อนแก้)
- 6 ด่าน: Field, Coast, Cave, Peak, Marsh, Spire · ในเกมเลือกด่านที่หน้าแคมป์ (L1/R1 ตอนนี้ = เปลี่ยนเป้า)
- **ค่าแสงสีแยกต่อด่านแบบอัตโนมัติ:** ใน editor `StageSet._process` จะเช็คค่า Look + Atmosphere ทุก 0.3 วินาที ถ้าเปลี่ยน จะบันทึกลง preset ของด่านที่แสดงอยู่
  - preset ของ Field คือ `StageSet/FieldPreset` ส่วนด่านอื่นคือ root ของ instance ด่านนั้น (สคริปต์ `stage_preset.gd`)
  - เก็บทุกค่ายกเว้น `camera_*` (กล้องใช้ร่วมกัน) · ค่าพื้นฐานอยู่ใน export และค่าที่เหลืออยู่ใน `extra` (dict แบบ `look:x` / `atmo:x` / `bg`)
  - ค่าที่ด่านไหนยังไม่มี จะใช้ค่าของ FieldPreset
  - `apply_to()` จะ kill tween หรี่แดดของ VFX และล้าง meta `base_energy` ทุกครั้ง (ถ้าไม่ทำ ด่านแรกจะมืดลง)
  - ห้ามทำการ capture อัตโนมัติตอน `_ready` สำหรับค่าที่ preset มีอยู่แล้ว (เป็นต้นเหตุบั๊ก "ด่านแรกมืดลง")
- **ไฟล์ด่าน** `stages/<id>.tscn` สร้างจาก `tools/build_stage.gd` + `tools/stages.json`
  - ผู้ใช้จัดวางของเพิ่มเองใน main.tscn เป็น override (จับคู่ตามชื่อโหนด) และเพิ่มโหนดใหม่ เช่น PalmA2, DeadShrubA2, LavaGlowBack2–4
  - ถ้าจะสร้างไฟล์ด่านใหม่ ห้ามเปลี่ยนชื่อโหนดเดิม ไม่อย่างนั้นงานจัดวางของผู้ใช้จะหลุด
- สเกลพิกเซล: **32 พิกเซลเท็กซ์เจอร์ = 1 เมตร** ทุกอย่าง (พื้น, ถนน, prop ใช้ `pixel_size` = 1/32 ม. หรือปรับตามจริง)
- ภาพด่าน `art/stages/<id>/`
  - sky, far, hor = พาโนรามา 1086×362 วางที่ (0,16.1,-70) / (0,3.12,-42) / (0,1.92,-20) uv ซ้ำ 3 รอบ
  - ground, rock = ต่อกันไร้รอย
  - path_wide = ถนนกว้าง
  - prop1–4 = ของประกอบ

## 5. Pipeline อาร์ตฉาก (ChatGPT → เกม) อยู่ใน `tools/pipeline/`
1. ส่งพรอมพ์ในแชท ChatGPT ข้างบน 1 พรอมพ์ต่อด่าน ได้ 7 ภาพ:
   1. sky 3:1 ทึบ
   2. far 3:1 พื้น #00FF00
   3. horizon 3:1 (ล่าง 20% ทึบ)
   4. ground top-down tile
   5. path strip 3:1
   6. rock tile
   7. prop 4 ชิ้นบนแผ่น 2:1 (ชิ้นละควอเตอร์)
   - ตัวอย่างพรอมพ์อยู่ใน `prompts.json` (cave/peak/marsh/spire)
   - ถ้าฉากมีสีเขียว (บึง) หรือไฟวิญญาณ ให้ระบุว่า "ห้ามใกล้ #00FF00"
2. ดึงภาพผ่าน backend ของ ChatGPT ด้วย `chatgpt_fetch.js` (หน้าแชทจะลบภาพที่เลื่อนผ่านไปออกจาก DOM) แล้วรวมไฟล์ด้วย `assemble2.py`
3. `python3 proc.py RAWDIR art/stages/<id>`
   - ลดเป็นพิกเซลจริง (block median) ตัดพื้นเขียวและลบขอบเขียว
   - หาจุดตัดพาโนรามาที่ต่อกันเนียนที่สุดแล้ว dither ผสมแคบๆ
   - ทำ tile ไร้รอย และแยก prop ด้วย connected components
   - **ระวัง:** คำสั่งนี้เขียนทับภาพเดิมในโฟลเดอร์ปลายทาง
4. `python3 widen.py path.png path_wide.png <สูงเดิม+48>` ทำถนนกว้างเลนเดียว (แทรกแถวกลางที่เลื่อนแนวนอน + dither)
5. ตั้งค่าใน `tools/stages.json` แล้วรัน `godot --headless --path . --script tools/build_stage.gd -- <id>`
6. ภาพดิบจาก ChatGPT ทุกด่านอยู่ใน `art/source_chatgpt/stages/<id>/img0–6.png` (มี .gdignore ทำให้ Godot ไม่ import)

## 6. เรนเดอร์ทดสอบแบบ headless (Linux)
- `render.sh FRAMES debug.gd` ใช้ Godot Movie Maker + xvfb + lavapipe ต้องแก้ path ของ Godot/โฟลเดอร์ในสคริปต์ก่อน
- `dbg_stage.gd` เป็น autoload ทดสอบ: ใช้ env `STAGE=Peak` เลือกด่าน, `DOF=1` เปิด DOF และเปิด auto battle
- lavapipe เรนเดอร์ DOF เบลอมาก ตอนทดสอบให้ปิด DOF (ในเครื่องผู้ใช้ปกติ)

## 7. ประวัติสั้น (ทำอะไรไปแล้ว)
- สัปดาห์ 1: ลุค HD-2D (แดด เงา tilt-shift glow) ล็อกค่า 13 ต.ค.
- สัปดาห์ 2: บรรยากาศ (ลม ฝุ่น ลำแสง เงาเมฆ) และอาร์ตฉาก Verdant Field จาก ChatGPT
- สัปดาห์ 3: ตัวละคร (rim light, contact shadow, pixel rules)
- สัปดาห์ 4 / 4.5: เวทตามธาตุ คอมโบลาวา/ไอน้ำ VFX แบบพิกเซลสไปรต์ (ค่าเริ่มต้น) + แบบ HD
- UI การต่อสู้สไตล์ Project Mancer แนวนอน (ฟอนต์ Barlow Condensed + Kanit) จอย PS5
- ฉากครบ 6 ด่าน, ค่าแสงสีแยกต่อด่าน, ถนนเลนเดียว, ของในด่านแก้ไขได้ใน editor
- ผู้ใช้จูนค่า VFX เอง: sprite_glow 3.35, spell_glow 2.2, hd_size 2.4, light_strength 2.6, scene_dim 1.45, dim_recover 1.0

## 7.5 ระบบเกม Party Battle (18 ต.ค. 2026)
- ไฟล์: `scripts/battle_ui.gd` (ลูปเกม + วาด UI ด้วย _draw ทั้งหมด), `scripts/mancer_data.gd` (ข้อมูล/ตัวเลขทั้งหมด), `scripts/mancer_save.gd` (เซฟ JSON)
- ตัด ATB, เปลี่ยนอาชีพ, Element Grid ออก · Timeline แบบ CTB (`TURN / SPD × น้ำหนักแอ็กชัน`)
- เกจคอมโบ 0–3 ต่อคน, เข้าโหมดคอมโบที่ ≥2 (`COMBO_MIN`), เวทคอมโบ 3 ช่อง □△○ ตั้งในแคมป์
- มอนสร้างตอนรันโดย duplicate โหนด `Actors/MagmaBeast` (ซ่อนไว้) แล้วเปลี่ยนเท็กซ์เจอร์เป็น `art/mon/mon_<ธาตุ>.png`
- ทดสอบ: headless auto-battle ทั้ง 6 ด่าน (สคริปต์ autoload ทดสอบใช้ `battle_finished` signal) + เรนเดอร์ภาพหน้าจอผ่าน xvfb/lavapipe
- เสียงและ BGM จากเกมเว็บใส่แล้วใน `audio/` (เป็นม็อคอัพ ผู้ใช้จะจ้างทำซาวด์จริงภายหลัง) · มี OPTIONS (ยอมแพ้/กลับหน้าแรก), ขอบแสงเทิร์น (shader outline), โหนด TurnGlow (ขอบแสง) และ ComboCinematic (แสงฉากตอนคอมโบ) ใน main.tscn

## 8. เรื่องค้าง / ข้อควรรู้
- Marsh และ Spire ยังไม่ได้จูนค่า tilt-shift, DOF หรือลมแยก (ใช้ของ Field อยู่)
- ภาพถนนกว้างมีรอย dither ตรงกลาง (Spire ดูถี่ที่สุด) ถ้าต้องการให้เนียน ควรเจ็นถนนกว้างใหม่จาก ChatGPT
- เวลาเซฟ editor จะบันทึก ShaderMaterial ลมของ sprite ในด่านลง main.tscn เป็น override ด้วย ไม่เป็นปัญหา
- ไม่ควรรัน `tools/build_scene.gd` (สร้าง main.tscn ใหม่ทั้งไฟล์) เพราะจะทับงานผู้ใช้
