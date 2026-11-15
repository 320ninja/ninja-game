extends VehicleBody3D
## Sajha / micro-bus: a wider, taller version of the city car.
## Uses the same VehicleBody3D physics as car.gd but with a bigger body mesh,
## and the same WASD/SHIFT/SPACE controls so the player can drive it.

@export var body_color := Color(0.15, 0.55, 0.85)  ## Sajha blue

var active := false
var wrecked := false
var boosting := false
var _steer := 0.0

const MAX_SPEED   := 70.0  ## km/h
const ENGINE_FORCE := 1600.0
const BRAKE_FORCE  := 28.0
const STEER_MAX    := 0.42
const STEER_SPEED  := 3.5


func _ready() -> void:
	add_to_group("vehicle")
	mass = 2200.0
	_build_body()
	_add_wheels()
	VehicleHealth.attach(self, Vector3(0.0, 1.6, 2.6), Vector3(-1.22, 1.4, 2.2))


func _physics_process(delta: float) -> void:
	if not active or wrecked:
		engine_force = 0.0
		brake         = 2.0
		return

	var throttle := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		throttle += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		throttle -= 1.0
	throttle = clampf(throttle + TouchControls.move.y, -1.0, 1.0)

	boosting = Input.is_key_pressed(KEY_SHIFT) and throttle > 0.0

	var steer_input := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		steer_input += 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		steer_input -= 1.0
	steer_input = clampf(steer_input - TouchControls.move.x, -1.0, 1.0)

	var speed := get_speed_kmh()
	var steer_taper := clampf(1.0 - speed / MAX_SPEED, 0.3, 1.0)
	_steer = move_toward(_steer, steer_input * STEER_MAX * steer_taper, STEER_SPEED * delta)
	steering = _steer

	if Input.is_key_pressed(KEY_SPACE) or TouchControls.held("jump"):
		engine_force = 0.0
		brake        = BRAKE_FORCE
	else:
		var force := ENGINE_FORCE * (1.6 if boosting else 1.0)
		engine_force = force * throttle * clampf(1.0 - speed / MAX_SPEED, 0.0, 1.0)
		brake = 0.0


func on_destroyed() -> void:
	wrecked = true
	active = false
	brake = BRAKE_FORCE
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = true)


func get_speed_kmh() -> float:
	return linear_velocity.length() * 3.6


func _build_body() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	mat.metallic     = 0.3
	mat.roughness    = 0.5

	# Main box — wider (2.4 m) and taller (2.6 m) than a car.
	var body := MeshInstance3D.new()
	var bm   := BoxMesh.new()
	bm.size  = Vector3(2.4, 2.6, 6.2)
	body.mesh = bm
	body.material_override = mat
	body.position = Vector3(0.0, 1.9, 0.0)
	add_child(body)

	# White window band.
	var win_mat := StandardMaterial3D.new()
	win_mat.albedo_color = Color(0.82, 0.88, 0.92, 0.6)
	win_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	win_mat.roughness    = 0.1
	var win := MeshInstance3D.new()
	var wm  := BoxMesh.new()
	wm.size = Vector3(2.42, 0.85, 4.8)
	win.mesh = wm
	win.material_override = win_mat
	win.position = Vector3(0.0, 2.35, -0.3)
	add_child(win)

	# Chassis collision.
	var col   := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 2.4, 6.0)
	col.shape  = shape
	col.position = Vector3(0.0, 1.8, 0.0)
	add_child(col)


func _add_wheels() -> void:
	var positions := [
		Vector3(-1.1, 0.5,  2.2),  # front-left
		Vector3( 1.1, 0.5,  2.2),  # front-right
		Vector3(-1.1, 0.5, -2.2),  # rear-left
		Vector3( 1.1, 0.5, -2.2),  # rear-right
	]
	for i in 4:
		var w := VehicleWheel3D.new()
		w.position              = positions[i]
		w.use_as_steering       = i < 2
		w.use_as_traction       = i >= 2
		w.wheel_radius          = 0.46
		w.wheel_rest_length     = 0.22
		w.suspension_travel     = 0.18
		w.suspension_stiffness  = 28.0
		w.wheel_friction_slip   = 1.8
		w.damping_compression   = 0.6
		w.damping_relaxation    = 0.6
		add_child(w)
