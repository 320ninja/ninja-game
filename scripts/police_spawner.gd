extends Node3D
## Keeps the right number of police officers around the player.
##
## Wanted level sets the target head count (spawn_per_star per star, capped at
## max_officers). Officers appear on a sidewalk a street or two away, out of
## the player's face, and are removed again once they are far behind.
## A couple of ambient patrols stay around even at 0 stars so a crime can be
## witnessed. Officers at 3+ stars can call request_backup().
##
## Grid constants mirror city.gd - if the city layout changes, change these too.

const BLOCK_SIZE := 46.0
const GRID := 7
const ROAD_WIDTH := 14.0
const CHECK_INTERVAL := 1.0
const SPAWN_MIN := 40.0
const SPAWN_MAX := 70.0

var spawn_per_star := 2
var max_officers := 10
var ambient_patrols := 2
var despawn_distance := 150.0
var backup_size := 2
var max_police_cars := 2
var car_min_level := 3

## Interior road centrelines (same as traffic.gd).
var _lines: Array[float] = []
var _check_left := 0.0
var _car_check_left := 0.0
var _game: Node


func _ready() -> void:
	add_to_group("police_spawner")
	_apply_config()
	var extent := GRID * BLOCK_SIZE
	for k in range(1, GRID):
		_lines.append(-extent * 0.5 + k * BLOCK_SIZE)
	WantedSystem.wanted_changed.connect(_on_wanted_changed)


func _process(delta: float) -> void:
	_check_left -= delta
	_car_check_left -= delta
	var centre: Variant = _player_position()
	if centre == null:
		return
	if _check_left <= 0.0:
		_check_left = CHECK_INTERVAL
		_despawn_far(centre)
		if officer_count() < _target_count():
			_spawn_near(centre, SPAWN_MIN, SPAWN_MAX)
	if _car_check_left <= 0.0:
		_car_check_left = CHECK_INTERVAL * 2.0
		_tick_police_cars(centre)


func officer_count() -> int:
	return get_child_count()


## An officer called it in. Send a couple more from around them, over the cap
## of the current star level but never past max_officers.
func request_backup(near: Vector3) -> void:
	var game_hud := get_tree().get_first_node_in_group("hud")
	if game_hud != null:
		game_hud.show_dialogue("Police Radio", "Requesting backup, suspect spotted!")
	for n in backup_size:
		if officer_count() >= max_officers:
			return
		_spawn_near(near, 15.0, 30.0)


func _on_wanted_changed(_level: int) -> void:
	_check_left = 0.0  # react right away instead of on the next tick


func _target_count() -> int:
	return clampi(WantedSystem.level * spawn_per_star, ambient_patrols, max_officers)


func _despawn_far(centre: Vector3) -> void:
	var excess := officer_count() - _target_count()
	for officer: PoliceOfficer in get_children():
		var far := officer.global_position.distance_to(centre) > despawn_distance
		# Out of range always goes; while over the head count, also drop
		# whoever isn't actively chasing and is well out of sight.
		var spare := excess > 0 and officer.state != PoliceOfficer.State.CHASE \
				and officer.global_position.distance_to(centre) > SPAWN_MIN
		if far or spare:
			officer.queue_free()
			excess -= 1


func _spawn_near(centre: Vector3, min_dist: float, max_dist: float) -> void:
	var officer := PoliceOfficer.new()
	var spot := _sidewalk_point(centre, min_dist, max_dist)
	officer.home = spot
	officer.position = spot + Vector3.UP * 0.5
	officer.rotation.y = randf() * TAU
	add_child(officer)


## A random point on a sidewalk roughly min..max metres from centre: pick a
## spot in that ring, snap it onto the nearest street, then step to the kerb.
func _sidewalk_point(centre: Vector3, min_dist: float, max_dist: float) -> Vector3:
	var angle := randf() * TAU
	var dist := randf_range(min_dist, max_dist)
	var p := centre + Vector3(cos(angle), 0.0, sin(angle)) * dist
	var limit := _lines[-1]
	p.x = clampf(p.x, -limit, limit)
	p.z = clampf(p.z, -limit, limit)
	var kerb := (ROAD_WIDTH * 0.5 + 1.2) * (1.0 if randf() < 0.5 else -1.0)
	if randf() < 0.5:
		p.x = _nearest_line(p.x) + kerb
	else:
		p.z = _nearest_line(p.z) + kerb
	p.y = 0.0
	return p


func _nearest_line(value: float) -> float:
	var best := _lines[0]
	for line in _lines:
		if absf(line - value) < absf(best - value):
			best = line
	return best


func _player_position() -> Variant:
	if _game == null:
		_game = get_tree().get_first_node_in_group("game")
		if _game == null:
			return null
	return _game.get_active().global_position


func _tick_police_cars(centre: Vector3) -> void:
	var cars := get_tree().get_nodes_in_group("police_car")
	# Despawn far cars
	for car in cars:
		if car.global_position.distance_to(centre) > despawn_distance:
			car.queue_free()
	# Spawn if needed
	var alive := get_tree().get_nodes_in_group("police_car").size()
	var target := max_police_cars if WantedSystem.level >= car_min_level else 0
	if alive < target:
		_spawn_police_car(centre)


func _spawn_police_car(centre: Vector3) -> void:
	var car := PoliceCar.new()
	var angle := randf() * TAU
	var dist := randf_range(SPAWN_MIN, SPAWN_MAX)
	car.position = centre + Vector3(cos(angle), 0.5, sin(angle)) * dist
	car.rotation.y = randf() * TAU
	get_parent().add_child(car)


func _apply_config() -> void:
	var police: Dictionary = WantedSystem.load_police_config()
	spawn_per_star = int(police.get("spawn_per_star", spawn_per_star))
	max_officers = int(police.get("max_officers", max_officers))
	ambient_patrols = int(police.get("ambient_patrols", ambient_patrols))
	despawn_distance = float(police.get("despawn_distance", despawn_distance))
	backup_size = int(police.get("backup_size", backup_size))
	max_police_cars = int(police.get("max_police_cars", max_police_cars))
	car_min_level = int(police.get("car_min_level", car_min_level))
