class_name PoliceCar
extends CharacterBody3D
## Police patrol car. Spawns when wanted level >= 3.
## Chases the player vehicle, tries to ram it to bleed off speed.
## Despawns when too far behind.

const CHASE_SPEED := 18.0
const RAM_DISTANCE := 3.5
const RAM_PUSH := 12.0
const TURN_SPEED := 4.5
const ALIGN_SPEED := 8.0

var _game: Node
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 14.0)
var _visual: Node3D
var despawn_distance := 150.0


func _ready() -> void:
	add_to_group("police_car")
	_apply_config()
	_build_visual()
	if _game == null:
		_game = get_tree().get_first_node_in_group("game")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if _game == null:
		_game = get_tree().get_first_node_in_group("game")
		move_and_slide()
		return

	var target: Node3D = _game.get_active()

	if target == null or WantedSystem.level < 3:
		move_and_slide()
		return

	var to := target.global_position - global_position
	to.y = 0.0
	var dist := to.length()

	if dist > despawn_distance:
		queue_free()
		return

	if dist > 0.5:
		var dir := to.normalized()
		velocity.x = dir.x * CHASE_SPEED
		velocity.z = dir.z * CHASE_SPEED
		var target_y := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_y, TURN_SPEED * delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	# Ram: push the player vehicle when close enough
	if dist < RAM_DISTANCE and target is RigidBody3D:
		var push := to.normalized() * RAM_PUSH
		target.apply_central_impulse(push)
		WantedSystem.report_seen()

	move_and_slide()


func get_speed_kmh() -> float:
	return Vector2(velocity.x, velocity.z).length() * 3.6


func _apply_config() -> void:
	var police := WantedSystem.load_police_config()
	despawn_distance = float(police.get("despawn_distance", despawn_distance))


## Greybox police car: dark blue body, white doors, light bar on top.
func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)

	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.1, 0.16, 0.38)
	blue.roughness = 0.6
	var white_mat := StandardMaterial3D.new()
	white_mat.albedo_color = Color(0.9, 0.9, 0.92)
	white_mat.roughness = 0.6
	var light_mat := StandardMaterial3D.new()
	light_mat.albedo_color = Color(0.3, 0.6, 1.0)
	light_mat.emission_enabled = true
	light_mat.emission = Color(0.3, 0.6, 1.0)
	light_mat.emission_energy_multiplier = 2.0

	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 0.65, 4.4)
	body.mesh = box
	body.material_override = blue
	body.position = Vector3(0.0, 0.52, 0.0)
	_visual.add_child(body)

	var doors := MeshInstance3D.new()
	var dbox := BoxMesh.new()
	dbox.size = Vector3(2.02, 0.44, 2.6)
	doors.mesh = dbox
	doors.material_override = white_mat
	doors.position = Vector3(0.0, 0.52, 0.0)
	_visual.add_child(doors)

	var lightbar := MeshInstance3D.new()
	var lbox := BoxMesh.new()
	lbox.size = Vector3(0.6, 0.18, 1.0)
	lightbar.mesh = lbox
	lightbar.material_override = light_mat
	lightbar.position = Vector3(0.0, 0.88, 0.1)
	_visual.add_child(lightbar)

	var col := CollisionShape3D.new()
	var cshape := BoxShape3D.new()
	cshape.size = Vector3(2.0, 1.1, 4.4)
	col.shape = cshape
	col.position = Vector3(0.0, 0.55, 0.0)
	add_child(col)
