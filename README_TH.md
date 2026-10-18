# Mancer HD-2D Slice — สัปดาห์ 1 (ค่า Look ที่อนุมัติ 13 ต.ค. 2026)

ฉากทดสอบลุค HD-2D: สไปรต์พิกเซลยืนในโลก 3D จริง มีแดด เงา ไฟเวท และเลนส์ tilt-shift

## เปิดโปรเจกต์ (Windows 11)
1. ดาวน์โหลด Godot 4.7 (Standard) จาก https://godotengine.org/download
2. แตกไฟล์ zip นี้ไว้ในโฟลเดอร์ไหนก็ได้
3. เปิด Godot → Import → เลือกไฟล์ `project.godot` ในโฟลเดอร์นี้ → Import & Edit
4. ครั้งแรก Godot จะ import ภาพสักครู่ จากนั้นกด F5 (หรือปุ่ม ▶ มุมขวาบน) เพื่อรัน

## ปรับลุคเอง (ไม่ต้องแตะโค้ด)
- ในแท็บ Scene ด้านซ้าย คลิกโหนดบนสุดชื่อ **Look**
- ด้านขวา (Inspector) จะมีกลุ่มค่า: Sun, Shadow side, Camera, Tilt-shift lens, Colour and glow
- เลื่อนค่าแล้วฉากในหน้าต่าง 3D จะเปลี่ยนทันที — กด Ctrl+S เพื่อบันทึก
- ปรับที่ Look เท่านั้น ถ้าไปปรับที่โหนด Sun / Camera3D โดยตรง ค่าจาก Look จะทับ

## ย้ายตัวละคร / ของประกอบฉาก
- อยู่ใต้โหนด Actors และ Props คลิกแล้วลากลูกศรในหน้าต่าง 3D ได้เลย
- ตัวละครใช้สคริปต์ pixel_actor: ช่อง Row = ท่า (0 ยืน, 1 โจมตี, 2 ชาร์จ), Fps = ความเร็ว

## แสงตามธาตุ (ทดลอง 13 ต.ค.)
- กด F5 แล้วฮีโร่จะผลัดกันร่ายเวทวนไปเรื่อยๆ (โหนด BattleDemo ปิดได้ที่ช่อง Running)
- **ไฟติดตัว (Aura):** อยู่ใต้ตัวละครแต่ละตัว เลือกธาตุจากเมนู Element เพื่อลองดูได้ทันที
  - ไฟ / ลาวา: เปลวไฟหายใจ · สายฟ้า: แลบเป็นจังหวะ · น้ำแข็ง: เรืองจางๆ · ดิน น้ำ ลม: ไม่มีไฟติดตัว
- **เวท (SpellCaster):** ชาร์จ → แสงก่อตัวที่มือ → ปล่อย → เวทเรืองแสงบินไปส่องพื้น → ระเบิดแสงสีธาตุที่เป้า
  - เปลี่ยน Element ของ SpellCaster เพื่อลองเวทธาตุอื่น (Water, Air, Lightning, Ice, Magma)
- สีและความแรงของทุกธาตุอยู่ใน `scripts/elements.gd` ไฟล์เดียว แก้ที่นั่นแล้วทุกตัวเปลี่ยนตาม

## บรรยากาศ (สัปดาห์ 2)
- คลิกโหนด **Atmosphere** แล้วปรับใน Inspector: Wind, Dust in the sunlight, Light shafts, Cloud shadows
- พุ่มไม้/ต้นไม้ที่ไหวตามลมอยู่ในรายการ Bushes และ Trees ถ้าเพิ่มพุ่มไม้ใหม่ ให้ลากโหนดใส่รายการ
- ลำแสงย้ายได้ใน 3D (Atmosphere/LightShafts) · เงาเมฆอยู่ที่ Atmosphere/CloudShadows

## จอแนวนอน (PC 1920×1080)
- โปรเจกต์ตั้งเป็นแนวนอนแล้ว กล้องล็อกมุมมองแนวตั้ง (Camera FOV = มุมแนวตั้ง 30°) จอกว้างแค่ไหนก็เห็นซ้าย-ขวาเพิ่ม ไม่ตัดหัวตัดเท้า
- ฉากหลัง ฟ้า/ภูเขา/แนวต้นไม้ เป็นพาโนรามาต่อซ้าย-ขวาได้ไร้รอย (วนซ้ำ 3 รอบ) ภาพแนวตั้งเดิมเก็บไว้เป็น `bg_*_portrait.png`

## อาร์ตฉากจริง (สัปดาห์ 2, สร้างจาก ChatGPT ในแชท Verdant Field เดิม เพื่อให้สไตล์ตรงกับของเก่า)
- พื้นหญ้า `art/grass.png` (206 px ต่อกันไร้รอย) · ทางดิน `art/dirt.png` · ผิวหิน `art/rock.png`
- ต้นไม้ `art/tree_a.png` สน · `tree_b.png` ใบกว้างสีทอง · `tree_c.png` ต้นอ่อน
- พืช `art/grass_a.png` กอหญ้า · `grass_b.png` พุ่มใบ · `plant_fern.png` เฟิร์น · `plant_reeds.png` ต้นกก
- ภาพต้นฉบับจาก ChatGPT อยู่ใน `art/source_chatgpt/oldstyle/` (Godot ไม่ import โฟลเดอร์นี้)
- ภาพชั่วคราวเดิมเก็บไว้เป็นไฟล์ `*_placeholder.png`

## เงาเมฆ (แก้ 13 ต.ค.)
- ปรับความเข้มที่โหนด **Atmosphere → Cloud shadows → Cloud Darkness** และสีที่ **Cloud Color**
- อย่าปรับที่โหนด A / B โดยตรง เพราะแผง Atmosphere จะเขียนทับทุกครั้งที่เปิดฉาก (ค่าที่คุณปรับไว้ 0.86 ตั้งเป็นค่าเริ่มต้นให้แล้ว)

## โฟกัสวิกเนตต์ (ฉากมืดลง ยกเว้นรอบตัวละคร)
- โหนด **FocusVignette** ปรับ: Strength (ความมืดรอบนอก), Edge Strength (มุมจอ), Shade Color, Focus Size, Softness, Focus Width
- หาตัวละครเอง: ทุก Sprite3D ใต้โหนด Actors + ใส่เป้าเพิ่มใน Extra Targets
- ใช้ในฉากอื่น: ลากไฟล์ `focus_vignette.tscn` ใส่ฉาก (ฉากนั้นต้องมีโหนดชื่อ Actors หรือแก้ช่อง Actors Root)
- เห็นผลตอนกด F5 เท่านั้น (หน้าต่าง 3D ในเอดิเตอร์ไม่แสดงเลเยอร์จอ)

## ตัวละคร (สัปดาห์ 3) — คลิกโหนด **Actors**
- Rim light: ขอบแสงฝั่งที่หันหาพระอาทิตย์ ตามโหนด Sun อัตโนมัติ (สี ความแรง ขอบบน ความหนา)
- Contact shadow: เงานุ่มใต้เท้า ความเข้ม/ขนาด
- Pixel rules: ล็อก Pixel Size ให้ทุกตัวเท่ากัน + มีป้ายเตือนสีเหลืองถ้า Scale x ≠ y (พิกเซลยืด)
- ตัวละครหรือมอนใหม่ที่วางใต้ Actors จะได้ค่าทั้งหมดนี้อัตโนมัติ

## เวทและ VFX (สัปดาห์ 4)
- กด F5: Terramancer (ดิน) → Pyromancer (ไฟ) → Hydromancer (น้ำ) → คอมโบลาวา (ดิน+ไฟ) → คอมโบไอน้ำ (น้ำ+ไฟ) วนไปเรื่อยๆ
- **โหนด VFX** ปรับทุกเวทพร้อมกัน: Light Strength, Impact Shadows (เงาจากแสงระเบิด), Scene Dim (ฉากมืดลงตอนเวทลง), Dim Recover, Ground Glow, Motes Amount/Time (อนุภาคลอยค้าง), Shake
- **โหนด Combos/Lava และ Combos/Steam** เลือกฮีโร่ 2 คน (Caster A/B) และชนิดคอมโบ
- ค่าต่อธาตุอยู่ใน `scripts/elements.gd`: SPELL (แสง, dim), MOTES (สี การเคลื่อนที่ จำนวน), COMBO (ลาวา ไอน้ำ)
- ความแรงแฟลชตอนโดนตีปรับได้ต่อตัวที่ Flash Strength ของแต่ละตัวละคร
- Hydromancer เพิ่มเข้ามาที่ x -3.9, z -0.7 ย้ายหรือลบได้ (ถ้าลบ ให้เอาออกจากรายการ BattleDemo และ Combos/Steam ด้วย)

## ฉาก/ด่าน (StageSet)
- โหนด **StageSet** → เลือก Stage: Field, Coast, Cave, Peak, Marsh, Spire (เห็นผลในเอดิเตอร์ทันที) · ในเกมเลือกด่านที่หน้าแคมป์
- **แสงสีแยกกันทุกด่าน (อัตโนมัติ)**: เลือกด่านที่ StageSet แล้วปรับที่ Look / Atmosphere ได้เลย ค่าจะถูกจำไว้ให้ด่านนั้นด่านเดียว ไม่ไปเปลี่ยนด่านอื่น แล้วกด Ctrl+S
  - ค่าที่แยกต่อด่าน: แดด เงา สี glow หมอก tilt-shift, DOF, ลม ฝุ่น ลำแสง เงาเมฆ และสีพื้นหลัง
  - ค่าที่ใช้ร่วมกันทุกด่าน: กล้อง (camera_pitch, distance, fov, target)
  - ด่านไหนยังไม่เคยปรับค่า tilt-shift, DOF หรือลม จะใช้ค่าเดียวกับ Verdant Field
- **ย้ายของในฉาก**: ด่าน Coast, Cave, Peak, Marsh, Spire เป็นโหนดลูกของ StageSet แล้ว เลือกด่านนั้นก่อน (ด่านที่ซ่อนอยู่จะกดไม่ได้) แล้วคลิกของในหน้า 3D หรือกางลูกศรใน Scene tree เพื่อย้าย หมุน ย่อขยาย ลบ หรือ Ctrl+D ทำซ้ำได้ ทุกอย่างบันทึกใน main.tscn
- Verdant Field ใช้ของเดิมใน main.tscn (Ground, DirtPath1, Backdrop, Props)
- ถนนเหลือเลนเดียว กว้างเท่าสองเลนเดิมรวมกัน (DirtPath2 ถูกซ่อนไว้ ไม่ได้ลบ) · ภาพถนนกว้าง `art/dirt_wide.png` และ `art/stages/<ด่าน>/path_wide.png`
- ภาพฉากอยู่ `art/stages/<ด่าน>/` (sky, far, hor = ฉากหลังพาโนรามา, ground, path, rock = เท็กซ์เจอร์, prop1–4 = ของประกอบ)
- `tools/build_stage.gd` + `tools/stages.json` สร้างไฟล์ `stages/<ด่าน>.tscn` ใหม่ การย้ายของที่ทำใน main.tscn ยังอยู่ (จับคู่ตามชื่อโหนด) แต่ถ้าเปลี่ยนชื่อโหนด งานที่จัดไว้จะหลุด
- ด่านทั้ง 6: Verdant Field (เย็นแดดอุ่น) · Tidepool Coast (ชายหาดกลางวัน) · Cinder Cave (ถ้ำลาวา ไฟกะพริบ) · Storm Peak (หิมะ พายุ) · Miasma Marsh (หมอกพิษ เห็ดเรืองแสงชมพู) · Spire of Morte (ดาดฟ้าหอคอยกลางคืน ออโรร่า ไฟวิญญาณ)

## เกม: Party Battle (18 ต.ค. 2026) — ระบบต่อสู้ใหม่ ปาร์ตี้ 3 คน
กด F5 → หน้า **CAMP** (เลือกด่าน + ตั้งเวทคอมโบ) → **BATTLE** (3 wave ต่อด่าน wave สุดท้ายเป็นบอส) → **RESULT** (EXP / เลเวลอัป / เวทใหม่) → กลับแคมป์
- **TIMELINE** ด้านบน (ไม่มี ATB แล้ว): ลำดับเทิร์นตามค่า SPD · ช่อง NOW = ใครกำลังเล่น · ช่องที่มีป้าย NEXT = ตำแหน่งที่ตัวละครจะได้เทิร์นถัดไปถ้าทำคำสั่งที่เลือกอยู่ (เวทหนักดันถอยหลังไกลกว่า, DEFEND เร็วกว่า)
- ไม่มีการโจมตีนอกเทิร์นแล้ว ทุกคนต้องรอเทิร์นตัวเอง
- คำสั่ง: **ATTACK** (กายภาพ เติมเกจคอมโบ 1 ช่อง + MP 6% + ทำ Break แรง) · **MAGICKS** (เวททั้งหมดที่ปลดล็อกแล้ว) · **COMBO** · **DEFEND** (ดาเมจครึ่ง, MP +10%, เทิร์นมาเร็ว)
- **เวทตามเลเวล**: ตัวละครละ 10 เวท ได้ 3 เวทตั้งแต่ Lv1 แล้วปลดเพิ่มที่ Lv 3, 5, 7, 9, 12, 15, 18
- **เกจคอมโบ 3 ช่อง** (ใต้ MP ของแต่ละคน): เติมจาก Attack +1, Magicks +½, ตีโดนจุดอ่อน +½, ดาเมจที่ทำ (สูงสุด +½ ต่อครั้ง) และดาเมจที่โดน · สีขาว = ยังไม่พอ · **เหลือง READY** = ≥2 ช่อง ใช้ได้ · **ชมพู-ทองกระพริบ MAX** = 3 ช่อง คุ้มสุด (FULL COMBO ทุกเวท +25%)
- **โหมดคอมโบ**: ปุ่ม □ (ซ้าย) △ (บน) ○ (ขวา) = เวท 3 อย่างที่ตั้งไว้ในแคมป์ · ✕ (ล่าง) = ยกเลิก (ถ้ายังไม่ร่าย ไม่เสียอะไร) / จบคอมโบ
  - D-pad ซ้าย/บน/ขวา = ดูรายละเอียดเวท + MP ที่จะเสียกระพริบบนหลอด MP · กด □ △ ○ = ร่ายทันที
  - ร่าย 1 ครั้งใช้ 1 ช่อง แต่ละครั้งแรงขึ้น ×1.0 → ×1.35 → ×1.8
- **ผสมธาตุ (Fusion)**: เวทจะทิ้ง "รอยธาตุ" (เพชรสีบนป้ายชื่อศัตรู) ถ้าเพื่อนใช้เวทธาตุอื่นซ้ำ จะระเบิดเป็นธาตุผสม: ดิน+ไฟ = ลาวา · น้ำ+ไฟ = ไอน้ำ · ดิน+น้ำ = ชีวภาพ
- **Break**: แถบฟ้าใต้ HP ศัตรู ลดเร็วจาก Attack และเวทคอมโบ หมดแล้วศัตรูเสียเทิร์นถัดไป + รับดาเมจ ×1.5
- ศัตรูจุดอ่อนจะโชว์ป้าย WEAK หลังลองตีด้วยธาตุนั้นแล้วเท่านั้น
- **จอย PS5**: D-pad/สติ๊ก = เลื่อน · ✕ = ยืนยัน · ○ = ย้อนกลับ · □△○ = เวทคอมโบ · L1/R1 = เปลี่ยนเป้า (ในแคมป์ = สลับตัวละคร) · OPTIONS = Auto · CREATE = ความเร็ว ×2
- **คีย์บอร์ด**: ลูกศร/WASD · Enter/Space/K = ✕ · Esc = ย้อน · J I L = □ △ ○ · Q/E = L1/R1 · Tab = Auto · F = ×2 · เมาส์คลิกได้ทุกปุ่ม (ชี้ = ดู, คลิก = ใช้)
- **แคมป์**: ←→ สลับช่องด่าน/ปาร์ตี้ · ในช่องปาร์ตี้ เลือกเวทแล้วกด □/△/○ เพื่อใส่ช่องคอมโบนั้น · ด่านถัดไปปลดเมื่อผ่านด่านก่อนหน้า
- โหนด **BattleUI** ใน Inspector: Auto Battle, UI Scale, Battle Speed, **Debug Level** (ให้ทุกคนเริ่มที่เลเวลนั้น ไว้ทดลองเวท), **Reset Save**
- ตัวเลขทั้งหมด (เวท, มอน, ด่าน, ดาเมจ, เกจ) อยู่ใน `scripts/mancer_data.gd` · เซฟอยู่ `user://mancer_save.json` (`%APPDATA%\Godot\app_userdata\Mancer HD-2D Slice\`)
- มอนสเตอร์ 11 แบบจากเกมเว็บเดิม อยู่ใน `art/mon/` (แผ่น 5×2: แถวบน = ยืน, แถวล่าง = โจมตี) · MagmaBeast ใน main.tscn เป็นต้นแบบที่ถูกซ่อนไว้ เกมจะก๊อปไปสร้างมอนทุกตัว
- ฟอนต์ Barlow Condensed + Kanit (OFL) อยู่ใน `fonts/` · BattleDemo ถูกปิดอัตโนมัติเมื่อมี BattleUI
- **(รอบ 2)** เพลง/เสียงจากเกมเว็บ (ม็อคอัพ) อยู่ `audio/bgm` (battle, boss) และ `audio/sfx` · ปรับดังเบาที่ BattleUI → Music Db / Sfx Db
- **OPTIONS** (ปุ่มมุมขวาบน / จอย OPTIONS / Tab) หยุดเกม: เล่นต่อ, Auto, ความเร็ว, **ยอมแพ้**, **กลับหน้าแรก**
- **(รอบ 3)** โหนด **TurnGlow**: ขอบแสงตัวที่ถึงเทิร์น — Width (ความหนา 1–4 พิกเซล), Roundness (มุม), Ally/Enemy Color, Brightness, Pulse, Pulse Speed, Glow Enemies
- โหนด **ComboCinematic**: ตอนคอมโบ แดด/แสงรอบข้างลดลง + ไฟโฟกัสกลางระหว่างฮีโร่กับเป้า + วิกเนตต์เข้มขึ้น — Sun Level, Ambient Level, Focus Color/Energy/Range/Height/Bias/Shadows, Vignette Boost, Fade In/Out
- คำสั่งต่อสู้กดปุ่มตรงได้เลย: □ ATTACK · △ MAGICKS · ○ COMBO · ✕ DEFEND (คีย์บอร์ด J I L K, Enter = คำสั่งที่ไฮไลต์อยู่) · มีเสียงตอนเริ่มเทิร์น และเสียงเลื่อน/เลือกทุกหน้า (รวมเมาส์ชี้)

## VFX พิกเซลอาร์ต (ค่าเริ่มต้น)
- โหนด **VFX → Style = Sprite**: ใช้เอฟเฟกต์โดนตีพิกเซลจาก Project Mancer เดิม 16 ธาตุ (12 เฟรม) เรืองแสงทุกธาตุ
- ปรับที่ VFX → Sprite hits: Sprite Glow (ความเรือง), Sprite Time (ความช้า วินาทีต่อ 1 รอบ), Sprite Size, Spell Glow (เวทที่บิน/ประกายที่มือ)
- ความเรืองรายธาตุปรับที่ SHEET_GLOW ใน `scripts/vfx_kit.gd` (ไอน้ำ ลม น้ำแข็ง ลดลงเพราะเป็นสีขาว)
- ประกายหลังโดนตีเป็นจุดกลมเล็กๆ อยู่สั้น ปรับ Motes Amount / Motes Time
- เงาบนตัวละครอ่อนกว่าบนพื้น ปรับที่ Actors → Shadow On Actors (1 = เข้มเท่าพื้น, 0 = ไม่มีเงา)

## VFX แบบ HD (สำรอง, ตั้ง Style = HD)
- โหนด **VFX → Style**: HD (เอฟเฟกต์ความละเอียดสูงแบบเกม AAA) หรือ Pixel (แบบสัปดาห์ 4) · HD Size = ขนาดเอฟเฟกต์โดนตี
- โดนตีแบบ HD: แสงวาบ → ดาวแตก → ประกายยืดตามความเร็ว → หนามมืดตัดแสง → คลื่นกระแทกบนพื้น → ควันกร่อนหาย → ภาพบิดจากความร้อน → รอยไหม้
- ชิเดอร์หลัก `shaders/vfx_core.gdshaderinc` (noise ไหล + กร่อนสลาย + gradient map + soft particles) ใช้ทำเอฟเฟกต์ใหม่ได้ทุกแบบ
- สีของแต่ละธาตุอยู่ใน RAMPS ใน `scripts/vfx_hd.gd`
- ภาพเอฟเฟกต์จาก Kenney Particle Pack (CC0) ดู `art/vfx_hd/CREDITS.txt`

## โครงสร้างไฟล์
- `main.tscn` ฉากหลัก · `scripts/look.gd` แผงคุมลุค · `scripts/pixel_actor.gd` ตัวละครพิกเซล
- `scripts/elements.gd` ตารางแสงทุกธาตุ · `scripts/element_light.gd` ไฟติดตัว · `scripts/spell_caster.gd` ลำดับร่ายเวท · `scripts/battle_demo.gd` ลูปโชว์ · `shaders/tilt_shift.gdshader` เลนส์เบลอบน-ล่าง
- `art/` ภาพทั้งหมด (ตัวละคร มอน และฉากหลังจากเกมเดิม; หิน หญ้า ทางดิน เป็นภาพชั่วคราว)
- `scripts/atmosphere.gd` แผงบรรยากาศ · `shaders/wind_sway.gdshader` ลม · `shaders/light_shaft.gdshader` ลำแสง
- `scripts/actor_look.gd` แผงคุมตัวละคร · `shaders/actor_pixel.gdshader` rim light + แสงวาบโดนตี · `scripts/focus_vignette.gd` + `shaders/focus_vignette.gdshader` + `focus_vignette.tscn` วิกเนตต์
- `scripts/vfx_kit.gd` ชิ้นส่วน VFX ทั้งหมด · `scripts/vfx_settings.gd` แผง VFX · `scripts/combo_caster.gd` เวทผสม · `art/vfx/` ภาพพิกเซลของเอฟเฟกต์
- `scripts/vfx_hd.gd` เอฟเฟกต์ HD (โดนตี, เวทบิน) · `shaders/vfx_add/vfx_blend/heat_haze` ชิเดอร์ VFX · `shaders/vfx_sprite.gdshader` + `art/vfx_sprite/` เอฟเฟกต์โดนตีแบบพิกเซล 16 ธาตุ
- `scripts/battle_ui.gd` + `ui/battle_ui.tscn` UI การต่อสู้และลูปเทิร์น · `fonts/` ฟอนต์
- `tools/` สคริปต์ช่วยสร้างฉาก ไม่ต้องรัน (build_scene.gd เลิกใช้แล้ว เพราะ main.tscn ของคุณคือต้นฉบับ)

## หมายเหตุ
- ตอนนี้ใช้ renderer Forward+ สำหรับทดสอบบนพีซี ตอนจะทดสอบมือถือค่อยเปลี่ยนเป็น Mobile (ตัวเลือกมุมขวาบนของ editor)
- ฟีเจอร์ที่ใช้ทั้งหมดรองรับใน Mobile รวม Depth of field (เปิดอยู่) ส่วนเวอร์ชันเว็บจะไม่มี DoF เหลือแค่ tilt-shift

## รอบ 4 (19 ต.ค. 2026)
- **SYSTEM MENU** (หน้าแคมป์เท่านั้น กด △ หรือปุ่มใต้ START): ITEMS · MAGICKS (ตั้งเวทคอมโบ □△○) · EQUIPMENT · SKILL TREE · OPTIONS — ↑↓ เลือกหน้า, ✕ เข้า, ○ กลับ, L1/R1 เปลี่ยนตัวละคร
  - ITEMS: EXP Tome, Grand Tome, Skill Seed, Forget Orb (รีเซ็ตสกิลทรี) · ได้จากชนะด่าน (สุ่ม + Seed จากบอส)
  - EQUIPMENT: อาวุธ / ชุดเกราะ / เครื่องประดับ 12 ชิ้น ได้เพิ่มตอนเคลียร์ด่านครั้งแรก
  - SKILL TREE: 3 สาย (BODY / MIND / COMBO) สายละ 3 ขั้น · SP ได้ 1 ต่อเลเวล + Skill Seed
  - OPTIONS: Auto, ความเร็ว, เสียงเพลง, เสียงเอฟเฟกต์, ลบเซฟ (กด ✕ สองครั้ง)
- **FINISHER**: คอมโบครบ 3 เวท (ต้องเปิดคอมโบด้วยเกจ 3 ช่อง) ตามลำดับปุ่มจะเกิดท่าพิเศษ เช่น □○△ Elemental Storm, □○○ Grace, □○□ Hex Strike, △△△ Overdrive, □□□ Breaker, ○○○ Aegis, △□○ Mana Bloom, ○△□ Time Slip — แผงซ้ายตอนคอมโบโชว์ปุ่มที่กดแล้วและสูตรที่ยังเป็นไปได้, ปุ่มเวทจะมีป้าย FINISHER ถ้ากดแล้วครบสูตร · แก้สูตรใน `FINISHERS` ของ `mancer_data.gd`
- **ComboCinematic** เพิ่มกลุ่มค่า: Hero (ตำแหน่งยืนหน้ามอน), Camera (zoom, fov, aim), Depth of field, Screen blur (เบลอตัวอื่น), Light, Timing
- Timeline เป็นไอคอนหน้าตัวละคร ฝ่ายเราบนเส้น (กรอบฟ้า) ศัตรูใต้เส้น (กรอบแดง) · ป้ายมอนอยู่ชิดหัวมอน
