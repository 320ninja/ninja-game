extends Node3D
## Manages the first delivery mission: pick up a package near the bazaar and
## deliver it to the river bridge within 90 seconds. Awards Rs 500 on success.
##
## Zones are plain Area3D spheres that glow green (pickup) or red (dropoff).
## The HUD reads _objective, _time_left, and _money via public properties.

signal mission_started
signal mission_completed(reward: int)
signal mission_failed

const PICKUP_POS  := Vector3(10.0,  0.5,  10.0)
const DROPOFF_POS := Vector3(-85.0, 0.5, -85.0)
const ZONE_RADIUS := 4.0
const TIME_LIMIT  := 90.0
const REWARD      := 500

enum State { IDLE, ACTIVE, DONE }

var state: State = State.IDLE
var time_left: float = TIME_LIMIT
var money: int = 0

## Text shown in the HUD mission line.
var objective: String = "Go to the green marker to start a delivery job."

var _pickup_zone:  Area3D
var _dropoff_zone: Area3D
var _player: Node3D


func _ready() -> void:
	add_to_group("missions")
	_player = get_tree().get_first_node_in_group("player")
	_pickup_zone  = _make_zone("PickupZone",  PICKUP_POS,  Color(0.2, 1.0, 0.3))
	_dropoff_zone = _make_zone("DropoffZone", DROPOFF_POS, Color(1.0, 0.25, 0.2))
	_dropoff_zone.visible = false


func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			if _player_in_zone(_pickup_zone):
				_start_mission()
		State.ACTIVE:
			time_left -= delta
			objective = "Deliver to the red marker!   %ds" % ceili(time_left)
			if time_left <= 0.0:
				_fail_mission()
			elif _player_in_zone(_dropoff_zone):
				_complete_mission()
		State.DONE:
			pass


func _start_mission() -> void:
	state = State.ACTIVE
	time_left = TIME_LIMIT
	_pickup_zone.visible  = false
	_dropoff_zone.visible = true
	objective = "Deliver to the red marker!   %ds" % ceili(TIME_LIMIT)
	emit_signal("mission_started")


func _complete_mission() -> void:
	state = State.DONE
	money += REWARD
	_dropoff_zone.visible = false
	objective = "Delivery done!  +Rs %d" % REWARD
	emit_signal("mission_completed", REWARD)


func _fail_mission() -> void:
	state = State.DONE
	_dropoff_zone.visible = false
	objective = "Time's up!  Mission failed."
	emit_signal("mission_failed")


## Returns true when the player is inside the zone sphere.
func _player_in_zone(zone: Area3D) -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return false
	return _player.global_position.distance_to(zone.global_position) < ZONE_RADIUS


## Builds a glowing sphere marker.  No collision layer needed; we do our own
## distance check so it works whether or not the player is in a vehicle.
func _make_zone(zone_name: String, pos: Vector3, colour: Color) -> Area3D:
	var zone := Area3D.new()
	zone.name = zone_name
	zone.global_position = pos

	# Visual: glowing sphere.
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = ZONE_RADIUS * 0.5
	sphere.height = ZONE_RADIUS
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.emission_enabled = true
	mat.emission = colour * 0.8
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.4
	mesh.material_override = mat
	zone.add_child(mesh)

	# A collision shape is required for Area3D to be valid, even though we
	# don't use body_entered (our manual distance check is simpler).
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = ZONE_RADIUS
	col.shape = shape
	zone.add_child(col)

	add_child(zone)
	return zone
