class_name VehicleHealth
extends Node
## Crash damage for any car body. Damage = velocity change on impact, so walls
## and other cars both count. Rigid cars also hurt kinematic ones they ram.

signal health_changed(current: float, max_hp: float)
signal destroyed

const MIN_IMPACT := 3.0
const SMOKE_AT := 0.6
const FIRE_AT := 0.3

@export var max_hp := 100.0
@export var damage_per_mps := 3.0
@export var engine_offset := Vector3(0.0, 0.8, -1.6)
@export var door_hinge := Vector3(-0.97, 0.45, -0.6)

var current_hp := 0.0
var is_destroyed := false

var _body: PhysicsBody3D
var _prev_vel := Vector3.ZERO
var _hits: Array[Node] = []
var _smoke: CPUParticles3D
var _fire: CPUParticles3D


static func attach(body: PhysicsBody3D, engine: Vector3, hinge: Vector3) -> VehicleHealth:
	var vh := VehicleHealth.new()
	vh.name = "VehicleHealth"
	vh.engine_offset = engine
	vh.door_hinge = hinge
	body.add_child(vh)
	return vh


static func of(node: Object) -> VehicleHealth:
	if node is Node:
		return node.get_node_or_null("VehicleHealth") as VehicleHealth
	return null


func _ready() -> void:
	current_hp = max_hp
	_body = get_parent() as PhysicsBody3D
	if _body is RigidBody3D:
		_body.contact_monitor = true
		_body.max_contacts_reported = maxi(_body.max_contacts_reported, 4)
		_body.body_entered.connect(func(other: Node) -> void: _hits.append(other))
	_smoke = _make_particles(Color(0.35, 0.35, 0.35, 0.7), 24, 1.8, 1.0, 0.0)
	_fire = _make_particles(Color(1.0, 0.45, 0.1, 0.9), 32, 0.6, 0.5, 2.5)


func _physics_process(_delta: float) -> void:
	if _body == null:
		return
	var vel := _velocity_of(_body)
	if not _hits.is_empty():
		var dv := (_prev_vel - vel).length()
		if dv >= MIN_IMPACT:
			take_damage(dv * damage_per_mps)
		for other in _hits:
			_hurt_kinematic(other)
		_hits.clear()
	_prev_vel = vel


func take_damage(amount: float) -> void:
	if is_destroyed or amount <= 0.0:
		return
	current_hp = maxf(current_hp - amount, 0.0)
	health_changed.emit(current_hp, max_hp)
	var ratio := current_hp / max_hp
	_smoke.emitting = ratio <= SMOKE_AT
	_fire.emitting = ratio < FIRE_AT
	if current_hp <= 0.0:
		_destroy()


func _hurt_kinematic(other: Node) -> void:
	if not is_instance_valid(other) or other is RigidBody3D:
		return
	var vh := of(other)
	if vh == null:
		return
	var closing := (_prev_vel - _velocity_of(other)).length()
	if closing >= MIN_IMPACT:
		vh.take_damage(closing * damage_per_mps)


static func _velocity_of(node: Node) -> Vector3:
	if node is RigidBody3D:
		return node.linear_velocity
	if node is CharacterBody3D:
		return node.velocity
	return Vector3.ZERO


func _destroy() -> void:
	is_destroyed = true
	_body.remove_from_group("vehicle")
	_open_door()
	destroyed.emit()
	if _body.has_method("on_destroyed"):
		_body.on_destroyed()


func _open_door() -> void:
	var rear := 1.0 if engine_offset.z < 0.0 else -1.0
	var hinge := Node3D.new()
	hinge.position = door_hinge
	hinge.rotation.y = -1.2 * rear
	var door := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.55, 1.1)
	door.mesh = mesh
	door.position = Vector3(0.0, 0.0, 0.55 * rear)
	var paint := _body.get_node_or_null("Body") as MeshInstance3D
	if paint and paint.material_override:
		door.material_override = paint.material_override
	hinge.add_child(door)
	_body.add_child(hinge)


func _make_particles(colour: Color, amount: int, life: float, size: float, glow: float) -> CPUParticles3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = colour
		mat.emission_energy_multiplier = glow
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat

	var ramp := Gradient.new()
	ramp.set_color(0, colour)
	ramp.set_color(1, Color(colour, 0.0))

	var p := CPUParticles3D.new()
	p.mesh = quad
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.position = engine_offset
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.direction = Vector3.UP
	p.spread = 20.0
	p.gravity = Vector3(0.0, 1.5, 0.0)
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.8
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color_ramp = ramp
	_body.add_child.call_deferred(p)
	return p
