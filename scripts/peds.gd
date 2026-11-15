extends Node3D
## Spawns pedestrians walking loops around the sidewalk of a random block.
##
## Grid constants mirror city.gd - if the city layout changes, change these too.

const Ped := preload("res://scripts/ped.gd")

const BLOCK_SIZE := 46.0
const ROAD_WIDTH := 14.0
const GRID := 7
const SIDEWALK_HEIGHT := 0.16
const PED_COUNT := 60

## Nepali dress colours: kurta suruwal, saris, daura suruwal, school uniforms.
const SHIRTS: Array[Color] = [
	Color(0.80, 0.12, 0.12),  # bright red sari
	Color(0.90, 0.60, 0.05),  # marigold/saffron kurta
	Color(0.15, 0.50, 0.25),  # forest green kurta
	Color(0.70, 0.18, 0.55),  # magenta sari
	Color(0.18, 0.28, 0.65),  # indigo / school uniform blue
	Color(0.88, 0.85, 0.80),  # white daura suruwal
	Color(0.48, 0.14, 0.14),  # maroon
	Color(0.95, 0.80, 0.30),  # golden yellow
]

const SKINS: Array[Color] = [
	Color(0.80, 0.63, 0.50),  # wheatish
	Color(0.70, 0.54, 0.42),  # medium brown
	Color(0.60, 0.46, 0.35),  # olive-brown (Hilly)
	Color(0.52, 0.38, 0.28),  # darker (Terai)
]

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 4242
	var extent := GRID * BLOCK_SIZE
	var inner := BLOCK_SIZE - ROAD_WIDTH
	var walk := inner * 0.5 - 0.9

	for n in PED_COUNT:
		var gx := _rng.randi_range(0, GRID - 1)
		var gz := _rng.randi_range(0, GRID - 1)
		var centre := Vector3(
			-extent * 0.5 + gx * BLOCK_SIZE + BLOCK_SIZE * 0.5,
			0.0,
			-extent * 0.5 + gz * BLOCK_SIZE + BLOCK_SIZE * 0.5)

		var corners := PackedVector3Array([
			centre + Vector3(-walk, SIDEWALK_HEIGHT, -walk),
			centre + Vector3(walk, SIDEWALK_HEIGHT, -walk),
			centre + Vector3(walk, SIDEWALK_HEIGHT, walk),
			centre + Vector3(-walk, SIDEWALK_HEIGHT, walk),
		])

		var ped: CharacterBody3D = Ped.new()
		var seg := _rng.randi_range(0, 3)
		ped.corners = corners
		ped.corner_idx = (seg + 1) % 4
		ped.walk_speed = _rng.randf_range(1.1, 2.2)
		ped.shirt      = SHIRTS[_rng.randi() % SHIRTS.size()]
		ped.skin       = SKINS[_rng.randi() % SKINS.size()]
		ped.wear_topi  = _rng.randf() < 0.35  # ~35 % of NPCs wear a topi
		add_child(ped)
		# Somewhere along the chosen segment, already heading for its end.
		ped.global_position = corners[seg].lerp(corners[(seg + 1) % 4], _rng.randf()) \
			+ Vector3(0.0, 0.1, 0.0)
