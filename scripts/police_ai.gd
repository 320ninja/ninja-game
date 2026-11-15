class_name PoliceOfficer
extends CharacterBody3D
## One police officer on foot. Deliberately simple:
##   PATROL  wander around the spot it was placed
##   CHASE   player is wanted and in sight: run straight at them
##   SEARCH  lost sight: go to where they were last seen, look around, give up
##
## Sight is a radius plus one raycast, checked a few times a second rather than
## every frame (cheap enough for a phone). Steering is direct, no navmesh: the
## city is a grid, so officers mostly run down streets anyway, and getting
## stuck on a corner is a fair way for the player to escape.
##
## Catch the player on foot (or stopped in a car) for a moment = busted.
## Hit an officer with a car = one more star.
## From 2 stars, officers shoot at a player on foot within 20 m.

enum State { PATROL, CHASE, SEARCH }

const EYE_HEIGHT := 1.5
const SIGHT_INTERVAL := 0.2
const PATROL_RADIUS := 18.0
const SEARCH_GIVE_UP := 6.0
## Star level from which a chasing officer radios for backup.
const BACKUP_LEVEL := 3
const BACKUP_INTERVAL := 15.0
const SHOOT_LEVEL := 2
const SHOOT_RANGE := 20.0
const CORPSE_TIME := 8.0

var walk_speed := 1.8
var run_speed := 7.5
var sight_radius := 35.0
## Seconds the player has to be in reach to be arrested.
var arrest_time := 1.2
var arrest_distance := 1.8

## Where this officer patrols around. Set by the spawner before add_child.
var home := Vector3.ZERO
var state := State.PATROL

var _patrol_target := Vector3.ZERO
var _pause := 0.0
var _last_seen := Vector3.ZERO
var _search_left := 0.0
var _sight_timer := 0.0
var _can_see := false
var _arrest_progress := 0.0
var _backup_cooldown := 0.0
var _down := 0.0
var _visual: Node3D
var _game: Node
var _shoot_delay := 0.0
var _gun: Weapon
var health: Health
var dead := false

@onready var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 14.0)


func _ready() -> void:
	add_to_group("police")
	_apply_config()
	_build_visual()
	_arm()
	_pick_patrol_target()
	# Stagger sight checks so a squad doesn't raycast on the same frame.
	_sight_timer = randf() * SIGHT_INTERVAL


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if dead:
		_stop()
		move_and_slide()
		return
	_backup_cooldown = maxf(_backup_cooldown - delta, 0.0)
	_shoot_delay = maxf(_shoot_delay - delta, 0.0)

	if _game == null:
		_game = get_tree().get_first_node_in_group("game")
	var target: Node3D = _game.get_active() if _game != null else null

	if _down > 0.0:
		_tick_knocked_down(delta)
		return
	_check_hit_by_car()

	_sight_timer -= delta
	if _sight_timer <= 0.0:
		_sight_timer = SIGHT_INTERVAL
		_can_see = target != null and _sees(target)

	_update_state(target)

	match state:
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_chase(target, delta)
			_try_shoot(target)
		State.SEARCH:
			_search(delta)

	move_and_slide()


## True if the target is near enough and nothing solid is in between.
func can_see_player() -> bool:
	return _can_see


func _update_state(target: Node3D) -> void:
	var wanted := WantedSystem.level > 0
	if not wanted:
		if state != State.PATROL:
			state = State.PATROL
			_arrest_progress = 0.0
			_pick_patrol_target()
		return

	if _can_see:
		WantedSystem.report_seen()
		_last_seen = target.global_position
		if state != State.CHASE:
			state = State.CHASE
			_radio_backup()
		elif _backup_cooldown <= 0.0:
			_radio_backup()
	elif state == State.CHASE:
		state = State.SEARCH
		_search_left = SEARCH_GIVE_UP
		_arrest_progress = 0.0


func _patrol(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		_stop()
		return
	if _flat_distance(_patrol_target) < 0.8:
		_pause = randf_range(1.0, 4.0)
		_pick_patrol_target()
		_stop()
		return
	_steer_to(_patrol_target, walk_speed, delta)


func _chase(target: Node3D, delta: float) -> void:
	if target == null or target.get("dead") == true:
		_stop()
		return
	var distance := _flat_distance(target.global_position)
	if distance > arrest_distance:
		_steer_to(target.global_position, run_speed, delta)
		_arrest_progress = maxf(_arrest_progress - delta, 0.0)
		return
	_stop()
	_face(target.global_position, delta)
	if _can_arrest(target):
		_arrest_progress += delta
		if _arrest_progress >= arrest_time:
			_arrest_progress = 0.0
			WantedSystem.bust()


func _try_shoot(target: Node3D) -> void:
	if WantedSystem.level < SHOOT_LEVEL or not _can_see or _shoot_delay > 0.0:
		return
	if target == null or not target.is_in_group("player") or target.dead:
		return
	var eye := global_position + Vector3.UP * 1.3
	var aim := target.global_position + Vector3.UP * 1.1
	if eye.distance_to(aim) > SHOOT_RANGE:
		return
	rotation.y = atan2(aim.x - eye.x, aim.z - eye.z)
	_gun.fire(eye, aim - eye, self)
	_shoot_delay = randf_range(0.6, 1.4)


func _arm() -> void:
	health = Health.new()
	health.name = "Health"
	health.max_hp = 60.0
	add_child(health)
	health.died.connect(_on_died)
	_gun = WeaponPistol.new()
	_gun.damage = 10.0
	_gun.spread = 0.05
	_gun.infinite_reserve = true
	_gun.position = Vector3(0.3, 1.1, 0.3)
	add_child(_gun)


func _on_died() -> void:
	dead = true
	remove_from_group("police")
	_visual.rotation.x = -PI * 0.5
	_gun.visible = false
	$Collision.set_deferred("disabled", true)
	get_tree().create_timer(CORPSE_TIME).timeout.connect(queue_free)


func _search(delta: float) -> void:
	if _flat_distance(_last_seen) > 1.0:
		_steer_to(_last_seen, run_speed * 0.8, delta)
		return
	_stop()
	rotation.y += 1.5 * delta  # look around
	_search_left -= delta
	if _search_left <= 0.0:
		state = State.PATROL
		home = global_position
		_pick_patrol_target()


## On foot, or sitting in a car that has stopped: either way, cuffs on.
func _can_arrest(target: Node3D) -> bool:
	if target.has_method("get_speed_kmh"):
		return target.get_speed_kmh() < 5.0
	return true


func _sees(target: Node3D) -> bool:
	var eye := global_position + Vector3.UP * EYE_HEIGHT
	var aim := target.global_position + Vector3.UP * 1.0
	if eye.distance_to(aim) > DayNight.police_sight(sight_radius):
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, aim)
	var exclude: Array[RID] = [get_rid()]
	if target is CollisionObject3D:
		exclude.append(target.get_rid())
	query.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _radio_backup() -> void:
	_backup_cooldown = BACKUP_INTERVAL
	if WantedSystem.level < BACKUP_LEVEL:
		return
	var spawner := get_tree().get_first_node_in_group("police_spawner")
	if spawner != null:
		spawner.request_backup(global_position)


func _check_hit_by_car() -> void:
	if _game == null:
		return
	var car: RigidBody3D = _game.driving
	if car == null or car.get_speed_kmh() < 20.0:
		return
	if global_position.distance_to(car.global_position) < 2.6:
		_down = randf_range(3.0, 4.5)
		_visual.rotation.x = -PI * 0.5
		WantedSystem.raise()


func _tick_knocked_down(delta: float) -> void:
	_down -= delta
	_stop()
	move_and_slide()
	if _down <= 0.0:
		_visual.rotation.x = 0.0


func _steer_to(point: Vector3, speed: float, delta: float) -> void:
	var to := point - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		_stop()
		return
	var dir := to.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face(point, delta)


func _face(point: Vector3, delta: float) -> void:
	var to := point - global_position
	if absf(to.x) + absf(to.z) < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 10.0 * delta)


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _flat_distance(point: Vector3) -> float:
	return Vector2(global_position.x - point.x, global_position.z - point.z).length()


func _pick_patrol_target() -> void:
	var angle := randf() * TAU
	var dist := randf_range(4.0, PATROL_RADIUS)
	_patrol_target = home + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)


func _apply_config() -> void:
	var police: Dictionary = WantedSystem.load_police_config()
	sight_radius = float(police.get("sight_radius", sight_radius))
	run_speed = float(police.get("run_speed", run_speed))


## Greybox officer: dark-blue uniform, peaked cap, white belt. Built in code
## like the pedestrians, swap for a real model later.
func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)

	var uniform := StandardMaterial3D.new()
	uniform.albedo_color = Color(0.12, 0.18, 0.36)
	uniform.roughness = 0.85
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.72, 0.56, 0.44)
	skin.roughness = 0.75
	var belt := StandardMaterial3D.new()
	belt.albedo_color = Color(0.92, 0.92, 0.9)
	belt.roughness = 0.6

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.28
	capsule.height = 1.35
	body.mesh = capsule
	body.material_override = uniform
	body.position = Vector3(0.0, 0.74, 0.0)
	_visual.add_child(body)

	var belt_mesh := MeshInstance3D.new()
	var belt_cyl := CylinderMesh.new()
	belt_cyl.top_radius = 0.29
	belt_cyl.bottom_radius = 0.29
	belt_cyl.height = 0.07
	belt_cyl.radial_segments = 12
	belt_mesh.mesh = belt_cyl
	belt_mesh.material_override = belt
	belt_mesh.position = Vector3(0.0, 0.78, 0.0)
	_visual.add_child(belt_mesh)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	sphere.radial_segments = 12
	sphere.rings = 6
	head.mesh = sphere
	head.material_override = skin
	head.position = Vector3(0.0, 1.58, 0.0)
	_visual.add_child(head)

	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.19
	cap_mesh.bottom_radius = 0.16
	cap_mesh.height = 0.09
	cap_mesh.radial_segments = 12
	cap.mesh = cap_mesh
	cap.material_override = uniform
	cap.position = Vector3(0.0, 1.73, 0.0)
	_visual.add_child(cap)

	var col := CollisionShape3D.new()
	col.name = "Collision"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.45
	col.shape = shape
	col.position = Vector3(0.0, 0.72, 0.0)
	add_child(col)
