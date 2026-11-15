extends Node3D
## Kathmandu valley rim — dark forested ridgelines close in, distant white
## Himalayan peaks far to the north.  Low-poly slabs, not spiky cones.

const RIDGES := [
	# [cx, cz, width, depth, height, colour_index]
	# colour_index: 0 = dark forest green-brown, 1 = mid-grey rock, 2 = snow white

	# ── Northern ridge (Shivapuri / Nagarjun) — dark wooded hills ──────────
	[   0.0, -530.0, 320.0, 80.0, 180.0, 0],
	[ 220.0, -560.0, 200.0, 70.0, 160.0, 0],
	[-240.0, -510.0, 220.0, 70.0, 165.0, 0],
	[ 400.0, -490.0, 160.0, 60.0, 140.0, 0],
	[-420.0, -470.0, 170.0, 60.0, 148.0, 0],

	# ── Far-north Himalayan peaks (very distant white range) ────────────────
	[   0.0, -820.0, 500.0, 90.0, 380.0, 2],
	[ 350.0, -780.0, 320.0, 80.0, 310.0, 2],
	[-380.0, -760.0, 340.0, 85.0, 295.0, 2],
	[ 650.0, -740.0, 280.0, 70.0, 260.0, 1],
	[-650.0, -720.0, 290.0, 72.0, 250.0, 1],

	# ── NE ridge (Nagarkot / Phulchowki direction) ──────────────────────────
	[ 500.0, -380.0, 150.0, 55.0, 130.0, 0],
	[ 560.0,  -60.0, 140.0, 50.0, 120.0, 0],
	[ 540.0,  180.0, 130.0, 48.0, 110.0, 0],

	# ── NW ridge (Nagarjun / Fulbari) ───────────────────────────────────────
	[-500.0, -400.0, 160.0, 58.0, 138.0, 0],
	[-540.0, -120.0, 150.0, 52.0, 118.0, 0],

	# ── South ridge (Chandragiri / Champadevi) — lower ──────────────────────
	[   0.0,  520.0, 280.0, 65.0, 120.0, 0],
	[ 220.0,  510.0, 200.0, 60.0, 100.0, 0],
	[-240.0,  500.0, 210.0, 60.0, 108.0, 0],
]

## Ridge colour palette.
const COLOURS: Array[Color] = [
	Color(0.24, 0.28, 0.18),  # 0 dark forested ridge
	Color(0.46, 0.44, 0.42),  # 1 bare rock / mid-grey
	Color(0.92, 0.94, 0.97),  # 2 Himalayan snow
]

func _ready() -> void:
	for r: Array in RIDGES:
		_add_ridge(r[0], r[1], r[2], r[3], r[4], int(r[5]))


func _add_ridge(cx: float, cz: float, w: float, d: float, h: float, ci: int) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOURS[ci]
	mat.roughness    = 0.95

	# Main slab (flat-topped or slightly peaked).
	var body := MeshInstance3D.new()
	var box  := BoxMesh.new()
	box.size = Vector3(w, h, d)
	body.mesh = box
	body.material_override = mat
	body.position = Vector3(cx, h * 0.5, cz)
	add_child(body)

	# For snow ridges: dark rock band just below snow line.
	if ci == 2:
		var rock_mat := StandardMaterial3D.new()
		rock_mat.albedo_color = COLOURS[1]
		rock_mat.roughness    = 0.95
		var rock := MeshInstance3D.new()
		var rb   := BoxMesh.new()
		rb.size = Vector3(w * 1.04, h * 0.22, d * 1.04)
		rock.mesh = rb
		rock.material_override = rock_mat
		rock.position = Vector3(cx, h * 0.11, cz)
		add_child(rock)
