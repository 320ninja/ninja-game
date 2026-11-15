extends Node3D
## Distant Himalayan mountain range backdrop.
## Uses low-poly cone/cylinder meshes placed in a rough arc to the north and
## east of the city, matching Kathmandu's real geography (Shivapuri, Nagarjun,
## Chandragiri ridges visible from the valley).
##
## All mountains are static non-collidable visuals only - they're 400+ m away
## and 100-350 m tall, so the player can never reach them.

## Snow-line altitude in metres above the valley floor.
const SNOWLINE := 220.0

const PEAKS := [
	# [x, z, radius_base, height, radial_segs]  (all in metres; y comes from height)
	# Northern ridge (Shivapuri direction)
	[   0.0, -520.0, 120.0, 310.0, 6],
	[ 110.0, -560.0,  90.0, 260.0, 5],
	[-130.0, -500.0, 100.0, 280.0, 6],
	[ 240.0, -540.0,  80.0, 230.0, 5],
	[-260.0, -510.0,  85.0, 245.0, 5],
	# North-east (Nagarkot direction)
	[ 400.0, -420.0,  70.0, 190.0, 5],
	[ 480.0, -360.0,  60.0, 160.0, 4],
	# North-west (Nagarjun direction)
	[-400.0, -440.0,  75.0, 200.0, 5],
	[-500.0, -350.0,  65.0, 170.0, 4],
	# East range (Phulchowki direction)
	[ 520.0,  -80.0,  60.0, 150.0, 4],
	[ 560.0,   40.0,  50.0, 130.0, 4],
	# South ridge (Chandragiri direction) - lower
	[ -80.0,  480.0,  80.0, 160.0, 5],
	[  60.0,  500.0,  70.0, 145.0, 5],
	[-220.0,  460.0,  75.0, 155.0, 5],
]


func _ready() -> void:
	for peak: Array in PEAKS:
		_add_peak(peak[0], peak[1], peak[2], peak[3], peak[4])


func _add_peak(px: float, pz: float, base_r: float, h: float, segs: int) -> void:
	# Main rock cone.
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.52, 0.50, 0.50)  # grey-brown rock
	rock_mat.roughness = 0.95

	var rock := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = base_r
	cone.height = h
	cone.radial_segments = segs
	rock.mesh = cone
	rock.material_override = rock_mat
	rock.position = Vector3(px, h * 0.5, pz)
	add_child(rock)

	# Snow cap above the snowline.
	var snow_h := maxf(h - SNOWLINE, 0.0)
	if snow_h < 5.0:
		return

	var snow_mat := StandardMaterial3D.new()
	snow_mat.albedo_color = Color(0.95, 0.96, 0.98)  # white snow
	snow_mat.roughness = 0.7

	# Snow radius proportional to how far above the snowline we are.
	var snow_r := base_r * (snow_h / h)
	var snow := MeshInstance3D.new()
	var snow_cone := CylinderMesh.new()
	snow_cone.top_radius = 0.0
	snow_cone.bottom_radius = snow_r
	snow_cone.height = snow_h
	snow_cone.radial_segments = segs
	snow.mesh = snow_cone
	snow.material_override = snow_mat
	snow.position = Vector3(px, SNOWLINE + snow_h * 0.5, pz)
	add_child(snow)
