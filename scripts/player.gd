extends CharacterBody3D
## On-foot player. Moves relative to wherever the camera is looking, which is
## what every third-person game does and what makes stick/WASD movement feel right.

@export var walk_speed := 2.8
@export var run_speed := 5.5
@export var jump_velocity := 9.0
## How quickly the player reaches target speed. Higher is snappier, less floaty.
@export var acceleration := 14.0
@export var air_control := 3.0
@export var turn_speed := 12.0

var running := false
var dead := false

const MAP_HALF := 390.0

const HOSPITAL := Vector3(-31.2, 0.5, 8.0)
const RESPAWN_DELAY := 3.0
const PUNCH_DAMAGE := 8.0

var _punch_cooldown := 0.0

@onready var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 14.0)
@onready var _anim: AnimationPlayer = _find_anim_player()
@onready var health: Health = $Health
@onready var weapons: WeaponManager = $WeaponManager

## Locomotion clips loop; everything else is one-shot.
const LOOPED_ANIMS := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Pistol_Idle"]
const ONE_SHOTS := ["Punch", "Pistol_Shoot", "Pistol_Reload"]


func _find_anim_player() -> AnimationPlayer:
	var ap := find_child("AnimationPlayer", true, false) as AnimationPlayer
	return ap

func _ready() -> void:
	add_to_group("player")
	if _anim != null:
		for anim_name in LOOPED_ANIMS:
			var anim := _anim.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
		_anim.playback_default_blend_time = 0.2
		if _anim.has_animation("Idle"):
			_anim.play("Idle")
	else:
		push_warning("Player: no AnimationPlayer found — model will be static.")
	_dress()
	health.died.connect(_on_died)
	var fs: Node = load("res://scripts/footsteps.gd").new()
	add_child(fs)


func _dress() -> void:
	# If the old Quaternius mannequin is present, style it.
	var mannequin: MeshInstance3D = $Model.find_child("Mannequin", true, false)
	if mannequin != null:
		var main: StandardMaterial3D = mannequin.mesh.surface_get_material(0).duplicate()
		main.albedo_color = Color(0.08, 0.08, 0.09)
		main.roughness = 0.88
		mannequin.set_surface_override_material(0, main)
		var joints: StandardMaterial3D = mannequin.mesh.surface_get_material(1).duplicate()
		joints.albedo_color = Color(0.52, 0.36, 0.26)
		joints.roughness = 0.78
		mannequin.set_surface_override_material(1, joints)
		return
	# Street Sentinel — clear any overrides so the FBX embedded material shows.
	for child in $Model.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, null)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if is_on_floor() and (Input.is_key_pressed(KEY_SPACE) or TouchControls.held("jump")):
		velocity.y = jump_velocity

	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.y -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1.0
	input = (input + TouchControls.move).limit_length(1.0)

	running = Input.is_key_pressed(KEY_SHIFT) or TouchControls.move.length() > 0.9
	var speed := run_speed if running else walk_speed

	var direction := _camera_relative(input)
	var target := direction * speed
	var rate := acceleration if is_on_floor() else air_control
	velocity.x = move_toward(velocity.x, target.x, rate * delta * speed)
	velocity.z = move_toward(velocity.z, target.z, rate * delta * speed)

	# Face the way we're going.
	if direction.length_squared() > 0.01:
		var wanted := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, wanted, turn_speed * delta)

	_punch_cooldown = maxf(_punch_cooldown - delta, 0.0)
	if (Input.is_key_pressed(KEY_F) or TouchControls.held("punch")) and _punch_cooldown == 0.0:
		_punch_cooldown = 0.6
		_punch()
		if _anim != null and _anim.has_animation("Punch_Jab"):
			_anim.play("Punch_Jab", 0.1)

	move_and_slide()
	global_position.x = clamp(global_position.x, -MAP_HALF, MAP_HALF)
	global_position.z = clamp(global_position.z, -MAP_HALF, MAP_HALF)
	_update_animation()


## Pick the clip that matches what the body is actually doing. Punches are
## one-shots: while one is playing, locomotion keeps its hands off the player.
func _update_animation() -> void:
	if _anim == null:
		return
	if _anim.is_playing() and ONE_SHOTS.any(func(a): return _anim.current_animation.begins_with(a)):
		return
	if weapons.current != null and weapons.current.reloading:
		if _anim.has_animation("Pistol_Reload"):
			_anim.play("Pistol_Reload", 0.1)
		return

	var target: String
	if not is_on_floor():
		target = "Jump"
	else:
		var speed := get_speed_kmh() / 3.6
		if speed < 0.3:
			target = "Pistol_Idle" if weapons.current != null else "Idle"
		elif speed < walk_speed + 0.4:
			target = "Walk"
		elif running:
			target = "Sprint"
		else:
			target = "Jog_Fwd"

	if _anim.current_animation != target and _anim.has_animation(target):
		_anim.play(target, 0.2)


## Knock down any ped close in front. The player model faces +Z.
func _punch() -> void:
	var forward := global_transform.basis.z
	for ped in get_tree().get_nodes_in_group("ped"):
		var to: Vector3 = ped.global_position - global_position
		if to.length() < 2.0 and to.normalized().dot(forward) > 0.2:
			ped.knock(randf_range(1.5, 3.0))
	for officer in get_tree().get_nodes_in_group("police"):
		var to: Vector3 = officer.global_position - global_position
		if to.length() < 2.0 and to.normalized().dot(forward) > 0.2:
			officer.health.take_damage(PUNCH_DAMAGE)
			_hit_officer()


func on_weapon_fired(hit: Object) -> void:
	if _anim != null and _anim.has_animation("Pistol_Shoot"):
		_anim.play("Pistol_Shoot", 0.05)
	if hit is Node and hit.is_in_group("police"):
		_hit_officer()
	elif hit != null and hit.has_method("knock"):
		hit.knock(randf_range(3.0, 5.0))


func _hit_officer() -> void:
	WantedSystem.raise()


func _on_died() -> void:
	dead = true
	_anim.play("Death01", 0.15)
	get_tree().call_group("hud", "show_banner", "YOU DIED", Color(1.0, 0.3, 0.3))
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	respawn_at_hospital()


func respawn_at_hospital() -> void:
	global_position = HOSPITAL
	velocity = Vector3.ZERO
	health.revive()
	WantedSystem.clear()
	dead = false
	_anim.play("Idle", 0.0)
	get_tree().call_group("hud", "show_banner", "Bir Hospital", Color.WHITE)


## Turn WASD into a world-space direction based on the active camera's yaw.
func _camera_relative(input: Vector2) -> Vector3:
	if is_zero_approx(input.length()):
		return Vector3.ZERO

	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3(input.x, 0.0, -input.y)

	# Use the camera's *target* yaw, not its current basis. The camera lags behind
	# the player, so steering off its live orientation feeds back on itself and
	# curves a straight input into an arc.
	var basis := Basis(Vector3.UP, cam.yaw) if "yaw" in cam else cam.global_transform.basis
	var forward := -basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := basis.x
	right.y = 0.0
	right = right.normalized()

	return (forward * input.y + right * input.x).normalized()


func get_speed_kmh() -> float:
	return Vector3(velocity.x, 0.0, velocity.z).length() * 3.6
