extends Node3D
## Kathmandu miniature map — main chowks connected by real roads.
## Scale: 1 unit ≈ 10 real metres.  Map centre: Ratna Park (~27.708°N 85.317°E).
## Chowk positions are geographically correct relative to each other.

const BUILDING_SHADER := preload("res://shaders/building.gdshader")
const GROUND_SHADER   := preload("res://shaders/ground.gdshader")

## Half-side of the playable square.
## Other systems (peds, props, police) spawn inside ±160 m which stays well inside EXTENT.
const EXTENT := 390.0

const SIDEWALK_H := 0.16

## Newari colour palette — rich brick, terracotta, ochre; NO cool whites/greys.
const FACADE_TONES: Array[Color] = [
	Color(0.60, 0.26, 0.14),  # deep Newari red brick
	Color(0.68, 0.32, 0.18),  # classic red brick
	Color(0.72, 0.38, 0.22),  # mid brick
	Color(0.52, 0.22, 0.12),  # dark terracotta
	Color(0.76, 0.48, 0.28),  # warm ochre-brick
	Color(0.64, 0.44, 0.24),  # ochre-brown plaster
]
const TIMBER := Color(0.20, 0.13, 0.09)
const GOLD   := Color(0.76, 0.62, 0.18)
const WHITE  := Color(0.92, 0.90, 0.86)
const STONE  := Color(0.58, 0.52, 0.42)

var _rng := RandomNumberGenerator.new()

# ─────────────────────────────────────────────────────────────────────────────
# Named chowk positions  (x, z)   — used for building clusters & landmarks
# ─────────────────────────────────────────────────────────────────────────────
const CHOWKS: Dictionary = {
	"Thamel":        Vector2(-160,  -88),
	"Ason":          Vector2(-140,    8),
	"Indrachowk":    Vector2(-160,   28),
	"Basantapur":    Vector2(-195,   52),
	"NewRoad":       Vector2(-140,   52),
	"RatnaPark":     Vector2( -88,   16),
	"Dharahara":     Vector2( -80,   52),
	"Swayambhu":     Vector2(-338,  -40),
	"Gongabu":       Vector2( -88, -278),
	"Pashupatinath": Vector2( 220,    0),
	"Boudhanath":    Vector2( 362, -122),
	"Baneshwor":     Vector2( 110,  195),
	"Koteshwor":     Vector2( 236,  298),
}

# ─────────────────────────────────────────────────────────────────────────────
# Road segments  [x1, z1, x2, z2, width, type]
# type 0 primary(12), 1 secondary(10), 2 tertiary(8), 3 local(7), 4 lane(5)
# ─────────────────────────────────────────────────────────────────────────────
const ROADS: Array = [
	# ═══ PRIMARY ARTERIES ════════════════════════════════════════════════════
	# Kantipath  (main N–S spine)
	[ -80, -390,  -80, -180,  12, 0],
	[ -80, -180,  -80,  -60,  12, 0],
	[ -80,  -60,  -80,   60,  12, 0],
	[ -80,   60,  -80,  200,  12, 0],
	# Prithvi Marg / Tribhuvan Highway  (E–W from Swayambhu)
	[-390,  -88, -240,  -88,  12, 0],
	[-240,  -88, -160,  -88,  12, 0],
	[-160,  -88,  -80,  -88,  12, 0],
	[ -80,  -88,  110,  -88,  12, 0],
	# Ring Road East  (connects Baneshwor–Koteshwor)
	[ 110,  195,  236,  298,  12, 0],
	[ -80,  200,  110,  200,  12, 0],
	# Arniko Highway  (Ratna Park → Pashupatinath → Boudhanath)
	[ -80,   16,  220,    0,  12, 0],
	[ 220,    0,  362, -122,  12, 0],

	# ═══ SECONDARY ═══════════════════════════════════════════════════════════
	# Lazimpath  (N–S, west of Kantipath)
	[-160, -390, -160,  -88,  10, 1],
	# Tripureshwor  (E–W south of Basantapur)
	[-390,  100, -195,  100,  10, 1],
	[-195,  100,  -80,  100,  10, 1],
	[ -80,  100,  110,  100,  10, 1],
	# Durbar Marg  (N–S east of Kantipath)
	[ 110,  -88,  110,  200,  10, 1],
	# Bag Bazaar Road  (N–S connecting Ason → Ratna Park)
	[ -88,  -88,  -88,  200,  10, 1],
	# Boudhanath Road  (from Arniko side)
	[ 220,    0,  220, -122,  10, 1],
	# New Road  (E–W through Basantapur)
	[-390,   52, -195,   52,  10, 1],
	[-195,   52,  -80,   52,  10, 1],
	# Swayambhu access road
	[-338,  -40, -240,  -88,  10, 1],
	[-338,  -40, -338,    0,   8, 2],  # hilltop loop
	# Gongabu road south  (bus park access)
	[ -88, -390,  -88, -278,  10, 1],
	[ -88, -278,  -88, -180,  10, 1],
	[ -88, -180,  -88,  -88,  10, 1],
	# Koteshwor loop
	[ 236,  298,  390,  298,  10, 1],
	[ 236,  298,  236,  390,  10, 1],

	# ═══ TERTIARY — connecting chowks ════════════════════════════════════════
	# Thamel internal N–S
	[-160,  -88, -160,   28,   8, 2],
	[-195,  -88, -195,   52,   8, 2],
	# Asan → Indrachowk → Basantapur alley
	[-160,   28, -195,   52,   8, 2],
	[-140,    8, -140,   52,   8, 2],
	# Jamal road  (E–W mid)
	[-160,  -44,  -88,  -44,   8, 2],
	[ -88,  -44,  110,  -44,   8, 2],
	# Pashupatinath access
	[ 220,    0,  220,   80,   8, 2],
	[ 110,   80,  220,   80,   8, 2],
	# Baneshwor internal
	[ 110,  195,  110,  110,   8, 2],
	[ 110,  110,  220,  110,   8, 2],

	# ═══ THAMEL LANES — deliberately tight alleys (3–4 m) ══════════════════
	# dense grid in the Thamel quadrant  (x: -220 → -80, z: -120 → -44)
	[-220, -120, -220,  -44,   3, 4],
	[-200, -120, -200,  -44,   3, 4],
	[-180, -120, -180,  -44,   4, 4],
	[-160, -120, -160,  -88,   4, 3],
	[-140, -120, -140,  -44,   3, 4],
	[-120, -120, -120,  -44,   3, 4],
	[-100, -120, -100,  -44,   4, 4],

	[-220, -120, -100, -120,   3, 4],
	[-220, -106, -100, -106,   3, 4],
	[-220,  -92, -100,  -92,   4, 4],
	[-220,  -78, -100,  -78,   3, 4],
	[-220,  -64, -100,  -64,   3, 4],
	[-220,  -44, -100,  -44,   4, 4],
]

# ─────────────────────────────────────────────────────────────────────────────
# Landmarks  [name, x, z, type, ...params]
# ─────────────────────────────────────────────────────────────────────────────
const LMARKS: Array = [
	# Swayambhunath — hilltop stupa (NW)
	["Swayambhu",   -338.0, -55.0, "swayambhu", 28.0, 7.5, 9.0],
	# Pashupatinath — tiered pagoda beside Bagmati (E)
	["Pashupati",    225.0,  12.0, "pagoda", 22.0, 4, 24.0],
	# Boudhanath — massive stupa dome (NE, map edge)
	["Boudhanath",   362.0, -122.0, "boudha", 36.0, 16.0, 14.0],
	# Gongabu Bus Park — open area with covered terminal (N)
	["Gongabu",      -88.0, -278.0, "buspark", 60.0, 50.0],
	# Basantapur Tower (Durbar Square)
	["Basantapur",  -195.0,   52.0, "pagoda", 18.0, 3, 22.0],
	# Dharahara tower
	["Dharahara",    -80.0,   52.0, "tower",   4.0, 32.0],
	# Thahiti Chorten (central Thamel)
	["Thahiti",     -155.0,  -55.0, "stupa",   7.0,  4.0,  5.5],
	# New Road Gate
	["NewRoadGate", -120.0,   52.0, "gate",   14.0,  7.0,  4.0],
	# Ason Tole shrine
	["Ason",        -140.0,    8.0, "square",  16.0],
	# Koteshwor intersection marker
	["Koteshwor",    236.0,  298.0, "pagoda",  12.0, 2, 14.0],
	# Baneshwor intersection
	["Baneshwor",    110.0,  195.0, "square",  18.0],
]

const _ROAD_COL: Array[Color] = [
	Color(0.18, 0.18, 0.20),  # primary
	Color(0.24, 0.24, 0.26),  # secondary
	Color(0.28, 0.28, 0.30),  # tertiary
	Color(0.32, 0.32, 0.34),  # local
	Color(0.36, 0.33, 0.29),  # lane (warm)
]


func _ready() -> void:
	_rng.seed = 20260810
	_build_ground()
	_build_boundary()
	_build_roads()
	_build_districts()
	_build_landmarks()


# ── Ground ───────────────────────────────────────────────────────────────────
func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter("block_size", 46.0)
	mat.set_shader_parameter("world_extent", EXTENT * 2.0)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(EXTENT * 2.0, EXTENT * 2.0)
	plane.subdivide_width = 10
	plane.subdivide_depth = 10
	mesh.mesh = plane
	mesh.material_override = mat
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(EXTENT * 2.0, 1.0, EXTENT * 2.0)
	col.shape = shape
	col.position = Vector3(0.0, -0.5, 0.0)
	body.add_child(col)
	add_child(body)


# ── Boundary ─────────────────────────────────────────────────────────────────
func _build_boundary() -> void:
	var wall_h := 4.0
	var thick  := 2.0
	var mat    := _plain(Color(0.30, 0.30, 0.32), 0.9)
	for i in 4:
		var s := 1.0 if i % 2 == 0 else -1.0
		var pos: Vector3
		var sz: Vector3
		if i < 2:
			pos = Vector3(0.0, wall_h * 0.5, s * EXTENT)
			sz  = Vector3(EXTENT * 2.0 + thick * 2.0, wall_h, thick)
		else:
			pos = Vector3(s * EXTENT, wall_h * 0.5, 0.0)
			sz  = Vector3(thick, wall_h, EXTENT * 2.0 + thick * 2.0)
		_box(pos, sz, mat)


# ── Roads ────────────────────────────────────────────────────────────────────
func _build_roads() -> void:
	var kerb_mat := _plain(Color(0.52, 0.47, 0.40), 0.9)
	for seg in ROADS:
		var x1 := float(seg[0]); var z1 := float(seg[1])
		var x2 := float(seg[2]); var z2 := float(seg[3])
		var hw  := float(seg[4])
		var ti  := int(seg[5])
		var dx  := x2 - x1; var dz := z2 - z1
		var ln  := sqrt(dx * dx + dz * dz)
		if ln < 0.5:
			continue
		var cx  := (x1 + x2) * 0.5
		var cz  := (z1 + z2) * 0.5
		var ang := atan2(dx, dz)

		# Road surface
		var body := StaticBody3D.new()
		body.position = Vector3(cx, 0.01, cz)
		body.rotation.y = ang
		var mesh := MeshInstance3D.new()
		var box  := BoxMesh.new()
		box.size = Vector3(hw, 0.04, ln)
		mesh.mesh = box
		mesh.material_override = _plain(_ROAD_COL[ti], 0.95)
		body.add_child(mesh)
		var cs    := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(hw, 0.5, ln)
		cs.shape  = shape
		body.add_child(cs)
		add_child(body)

		# Kerb strips
		if ti <= 2:
			var perp_x := cos(ang + PI * 0.5)
			var perp_z := sin(ang + PI * 0.5)
			for s in [-1.0, 1.0]:
				var kb := StaticBody3D.new()
				kb.position = Vector3(cx + s * (hw * 0.5 + 0.5) * perp_x,
					SIDEWALK_H * 0.5,
					cz + s * (hw * 0.5 + 0.5) * perp_z)
				kb.rotation.y = ang
				var km := MeshInstance3D.new()
				var kbox := BoxMesh.new()
				kbox.size = Vector3(1.0, SIDEWALK_H, ln)
				km.mesh = kbox
				km.material_override = kerb_mat
				kb.add_child(km)
				add_child(kb)


# ── District buildings ────────────────────────────────────────────────────────
# Each chowk gets a cluster of buildings that fills its block.
func _build_districts() -> void:
	for chowk_name in CHOWKS:
		var centre: Vector2 = CHOWKS[chowk_name]
		var density := 0
		var radius  := 0.0
		match chowk_name:
			"Thamel":        density = 28; radius = 55.0
			"Ason":          density = 18; radius = 35.0
			"Indrachowk":    density = 14; radius = 28.0
			"Basantapur":    density =  6; radius = 22.0  # more open — Durbar Square
			"NewRoad":       density = 20; radius = 40.0
			"RatnaPark":     density =  2; radius = 50.0  # mostly open park
			"Dharahara":     density =  8; radius = 25.0
			"Swayambhu":     density =  4; radius = 20.0  # hilltop, sparse
			"Gongabu":       density =  4; radius = 30.0  # mostly open terminal
			"Pashupatinath": density =  8; radius = 30.0
			"Boudhanath":    density =  6; radius = 28.0
			"Baneshwor":     density = 20; radius = 45.0
			"Koteshwor":     density = 20; radius = 40.0
		for _i in density:
			var angle := _rng.randf() * TAU
			var dist  := _rng.randf_range(8.0, radius)
			var bx    := centre.x + cos(angle) * dist
			var bz    := centre.y + sin(angle) * dist
			# Skip if outside map
			if abs(bx) > EXTENT - 5.0 or abs(bz) > EXTENT - 5.0:
				continue
			# Skip if on a road
			if _near_road(bx, bz, 7.0):
				continue
			_place_building(bx, bz, chowk_name)


func _near_road(px: float, pz: float, threshold: float) -> bool:
	for seg in ROADS:
		var x1   := float(seg[0]); var z1 := float(seg[1])
		var x2   := float(seg[2]); var z2 := float(seg[3])
		var hw   := float(seg[4]) * 0.5 + threshold
		var dx   := x2 - x1; var dz := z2 - z1
		var len2 := dx * dx + dz * dz
		if len2 < 0.001:
			continue
		var t  := clampf(((px - x1) * dx + (pz - z1) * dz) / len2, 0.0, 1.0)
		var nx := x1 + t * dx - px
		var nz := z1 + t * dz - pz
		if nx * nx + nz * nz < hw * hw:
			return true
	return false


func _place_building(cx: float, cz: float, district: String) -> void:
	var w := _rng.randf_range(6.0, 14.0)
	var d := _rng.randf_range(6.0, 14.0)
	var h: float
	match district:
		"Thamel", "NewRoad", "Ason", "Indrachowk":
			h = _rng.randf_range(8.0, 18.0)
		"Baneshwor", "Koteshwor":
			h = _rng.randf_range(14.0, 28.0)
		"Gongabu":
			h = _rng.randf_range(4.0, 9.0)
		_:
			h = _rng.randf_range(6.0, 15.0)

	_box(Vector3(cx, SIDEWALK_H + h * 0.5, cz), Vector3(w, h, d), _facade(h))

	var is_old_city := district in ["Thamel","Ason","Indrachowk","Basantapur",
		"Pashupatinath","Boudhanath","NewRoad","RatnaPark"]

	if is_old_city:
		# Top eave — ALWAYS on old-city buildings
		var ew := w * _rng.randf_range(1.10, 1.26)
		var ed := d * _rng.randf_range(1.10, 1.26)
		var eh := _rng.randf_range(0.5, 1.1)
		_box(Vector3(cx, SIDEWALK_H + h + eh * 0.5, cz),
			Vector3(ew, eh, ed), _plain(TIMBER, 0.88))

		# Mid-floor eave (pagoda feel) — 60 % of taller buildings
		if h > 9.0 and _rng.randf() < 0.60:
			_box(Vector3(cx, SIDEWALK_H + h * 0.56, cz),
				Vector3(w * 1.14, 0.45, d * 1.14), _plain(TIMBER, 0.88))

		# Second mid-eave — 25 % of very tall buildings (3-tier pagoda)
		if h > 14.0 and _rng.randf() < 0.25:
			_box(Vector3(cx, SIDEWALK_H + h * 0.80, cz),
				Vector3(w * 1.07, 0.38, d * 1.07), _plain(TIMBER, 0.88))


# ── Landmarks ────────────────────────────────────────────────────────────────
func _build_landmarks() -> void:
	for lm in LMARKS:
		var lx: float = float(lm[1]); var lz: float = float(lm[2])
		if abs(lx) > EXTENT or abs(lz) > EXTENT:
			continue
		match String(lm[3]):
			"tower":     _lm_tower(lx, lz, float(lm[4]), float(lm[5]))
			"gate":      _lm_gate(lx, lz, float(lm[4]), float(lm[5]), float(lm[6]))
			"pagoda":    _lm_pagoda(lx, lz, float(lm[4]), int(lm[5]), float(lm[6]))
			"stupa":     _lm_stupa(lx, lz, float(lm[4]), float(lm[5]), float(lm[6]))
			"boudha":    _lm_boudha(lx, lz, float(lm[4]), float(lm[5]), float(lm[6]))
			"swayambhu": _lm_swayambhu(lx, lz, float(lm[4]), float(lm[5]), float(lm[6]))
			"buspark":   _lm_buspark(lx, lz, float(lm[4]), float(lm[5]))
			"square":    _lm_square(lx, lz, float(lm[4]))


## Dharahara — white octagonal tower with observation rings and gold spire.
func _lm_tower(x: float, z: float, base_r: float, h: float) -> void:
	_box(Vector3(x, h * 0.5, z), Vector3(base_r * 2.0, h, base_r * 2.0),
		_plain(Color(0.90, 0.87, 0.80), 0.65))
	var y := 8.0
	while y < h:
		_box(Vector3(x, y, z), Vector3(base_r * 2.4, 0.55, base_r * 2.4),
			_plain(Color(0.78, 0.74, 0.65), 0.60))
		y += 8.0
	_box(Vector3(x, h + 2.5, z), Vector3(1.4, 5.0, 1.4), _plain(GOLD, 0.30))


## New Road Gate — two pillars + horizontal lintel.
func _lm_gate(x: float, z: float, w: float, h: float, d: float) -> void:
	var gc := _plain(Color(0.80, 0.68, 0.22), 0.40)
	_box(Vector3(x - w * 0.38, h * 0.5, z), Vector3(d, h, d), gc)
	_box(Vector3(x + w * 0.38, h * 0.5, z), Vector3(d, h, d), gc)
	_box(Vector3(x, h - d * 0.4, z), Vector3(w, d, d * 1.1), gc)
	_box(Vector3(x, h + d * 0.6, z), Vector3(w * 0.5, d * 0.6, d * 0.8), gc)


## Generic tiered pagoda (Basantapur tower, Pashupatinath, Koteshwor temple).
func _lm_pagoda(x: float, z: float, base: float, tiers: int, h: float) -> void:
	var brick   := Color(0.62, 0.30, 0.22)
	var tier_h  := h / float(tiers)
	for i in tiers:
		var sc := 1.0 - float(i) * 0.25
		var tw := base * sc
		var bot := float(i) * tier_h
		_box(Vector3(x, bot + tier_h * 0.5, z), Vector3(tw, tier_h, tw),
			_plain(brick, 0.80))
		_box(Vector3(x, bot + tier_h + 0.4, z), Vector3(tw * 1.30, 0.70, tw * 1.30),
			_plain(TIMBER, 0.90))
	_box(Vector3(x, h + 2.0, z), Vector3(1.0, 4.5, 1.0), _plain(GOLD, 0.30))


## Small stupa / chorten (Thahiti).
func _lm_stupa(x: float, z: float, base: float, dome_r: float, spire_h: float) -> void:
	_box(Vector3(x, 0.5, z),  Vector3(base, 1.0, base), _plain(STONE, 0.85))
	_box(Vector3(x, 1.4, z),  Vector3(base * 0.78, 0.9, base * 0.78), _plain(WHITE, 0.55))
	for i in 6:
		var t  := float(i) / 5.0
		var r  := dome_r * sin(t * PI)
		var dy := 2.3 + float(i) * dome_r * 0.38
		_box(Vector3(x, dy, z), Vector3(r * 2.0, dome_r * 0.44, r * 2.0), _plain(WHITE, 0.50))
	_box(Vector3(x, 2.3 + dome_r * 2.4, z),
		Vector3(dome_r * 0.55, dome_r * 0.38, dome_r * 0.55), _plain(GOLD, 0.28))
	_box(Vector3(x, 2.3 + dome_r * 2.9 + spire_h * 0.5, z),
		Vector3(0.70, spire_h, 0.70), _plain(GOLD, 0.28))
	# Eyes band (orange)
	_box(Vector3(x, 2.3 + dome_r * 2.4 - 0.1, z),
		Vector3(dome_r * 0.60, 0.55, dome_r * 0.60),
		_plain(Color(0.92, 0.55, 0.12), 0.40))


## Boudhanath — the giant stupa, recognisable from anywhere.
func _lm_boudha(x: float, z: float, base: float, dome_r: float, spire_h: float) -> void:
	# Tiered circular base (mandala)
	for i in 4:
		var sc  := 1.0 - float(i) * 0.14
		var bay := base * sc
		_box(Vector3(x, float(i) * 1.4 + 0.7, z), Vector3(bay, 1.4, bay),
			_plain(Color(0.68, 0.63, 0.52), 0.85))
	var base_top := 4.0 * 1.4
	# Dome (stack of discs, big)
	for i in 8:
		var t  := float(i) / 7.0
		var r  := dome_r * sin(t * PI)
		var dy := base_top + float(i) * dome_r * 0.30
		_box(Vector3(x, dy, z), Vector3(r * 2.0, dome_r * 0.34, r * 2.0), _plain(WHITE, 0.50))
	var dome_top := base_top + dome_r * 2.4
	# Harmika cube (cube with eyes)
	var hk := dome_r * 0.50
	_box(Vector3(x, dome_top + hk * 0.5, z), Vector3(hk * 2.0, hk, hk * 2.0), _plain(GOLD, 0.28))
	# Eyes stripe (each face — just a coloured band for now)
	_box(Vector3(x, dome_top + hk * 0.3, z), Vector3(hk * 2.1, hk * 0.5, hk * 2.1),
		_plain(Color(0.92, 0.55, 0.12), 0.35))
	# Spire (13 chattras as tapered discs)
	for i in 6:
		var dr := 0.9 - float(i) * 0.12
		_box(Vector3(x, dome_top + hk + float(i) * spire_h / 6.0, z),
			Vector3(dr * 2.0, spire_h / 7.0, dr * 2.0), _plain(GOLD, 0.25))
	_box(Vector3(x, dome_top + hk + spire_h + 1.0, z), Vector3(1.0, 2.0, 1.0), _plain(GOLD, 0.25))


## Swayambhunath — hilltop stupa with stepped hill below.
func _lm_swayambhu(x: float, z: float, hill_r: float, dome_r: float, spire_h: float) -> void:
	# Hill (stepped pyramid)
	for i in 5:
		var sc := 1.0 - float(i) * 0.18
		var hr := hill_r * sc
		var hy := float(i) * 4.0 + 2.0
		_box(Vector3(x, hy, z), Vector3(hr, 4.0, hr),
			_plain(Color(0.42, 0.52, 0.32), 0.90))  # green hill
	var hill_top := 5.0 * 4.0
	# Stupa on hilltop
	_box(Vector3(x, hill_top + 0.6, z), Vector3(dome_r * 2.0, 1.2, dome_r * 2.0),
		_plain(STONE, 0.85))
	for i in 6:
		var t  := float(i) / 5.0
		var r  := dome_r * sin(t * PI)
		var dy := hill_top + 1.8 + float(i) * dome_r * 0.36
		_box(Vector3(x, dy, z), Vector3(r * 2.0, dome_r * 0.40, r * 2.0), _plain(WHITE, 0.50))
	var stupa_top := hill_top + 1.8 + dome_r * 2.2
	_box(Vector3(x, stupa_top + 0.3, z), Vector3(dome_r * 0.5, dome_r * 0.4, dome_r * 0.5),
		_plain(GOLD, 0.28))
	_box(Vector3(x, stupa_top + spire_h * 0.5 + dome_r * 0.4, z),
		Vector3(0.70, spire_h, 0.70), _plain(GOLD, 0.28))


## Gongabu Bus Park — large shed + open forecourt + a few buses approximated as boxes.
func _lm_buspark(x: float, z: float, wide: float, deep: float) -> void:
	# Main terminal shed (corrugated roof feel)
	var roof_col := _plain(Color(0.55, 0.52, 0.48), 0.85)
	var wall_col := _plain(Color(0.72, 0.68, 0.60), 0.75)
	_box(Vector3(x, 4.5, z - deep * 0.3), Vector3(wide, 9.0, deep * 0.4), wall_col)
	_box(Vector3(x, 9.4, z - deep * 0.3), Vector3(wide * 1.05, 1.0, deep * 0.45), roof_col)
	# Open forecourt (paved)
	_box(Vector3(x, 0.08, z + deep * 0.2), Vector3(wide, 0.16, deep * 0.6),
		_plain(Color(0.50, 0.46, 0.40), 0.90))
	# Parked bus silhouettes
	var bus_col := _plain(Color(0.20, 0.45, 0.22), 0.70)
	for i in 5:
		var bx := x - wide * 0.4 + float(i) * wide * 0.2
		_box(Vector3(bx, 2.3, z + deep * 0.1), Vector3(5.0, 4.6, 12.0), bus_col)


## Ason Tole / Baneshwor — open paved chowk with central shrine.
func _lm_square(x: float, z: float, radius: float) -> void:
	_box(Vector3(x, 0.08, z), Vector3(radius * 2.0, 0.16, radius * 2.0),
		_plain(Color(0.58, 0.52, 0.42), 0.90))
	_box(Vector3(x, 1.1, z), Vector3(3.2, 2.2, 3.2), _plain(Color(0.72, 0.56, 0.38), 0.65))
	_box(Vector3(x, 2.5, z), Vector3(3.8, 0.70, 3.8), _plain(TIMBER, 0.90))
	_box(Vector3(x, 3.1, z), Vector3(2.8, 0.55, 2.8), _plain(TIMBER, 0.90))
	_box(Vector3(x + radius * 0.6, 3.0, z), Vector3(0.25, 6.0, 0.25),
		_plain(Color(0.80, 0.80, 0.78), 0.70))


# ── Helpers ───────────────────────────────────────────────────────────────────
func _box(pos: Vector3, size: Vector3, material: Material) -> void:
	var body  := StaticBody3D.new()
	body.position = pos
	var mesh  := MeshInstance3D.new()
	var bx    := BoxMesh.new()
	bx.size   = size
	mesh.mesh = bx
	mesh.material_override = material
	body.add_child(mesh)
	var cs    := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape  = shape
	body.add_child(cs)
	add_child(body)


func _plain(colour: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness    = roughness
	return mat


func _facade(height: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = BUILDING_SHADER
	mat.set_shader_parameter("wall_colour",     FACADE_TONES[_rng.randi() % FACADE_TONES.size()])
	mat.set_shader_parameter("building_height", height)
	mat.set_shader_parameter("floor_height",    _rng.randf_range(3.1, 3.9))
	mat.set_shader_parameter("window_span",     _rng.randf_range(2.2, 3.2))
	mat.set_shader_parameter("lit_ratio",       _rng.randf_range(0.06, 0.30))
	mat.set_shader_parameter("seed",            _rng.randf() * 200.0)
	return mat
