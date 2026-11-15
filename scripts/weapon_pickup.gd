class_name WeaponPickup
extends Node3D
## A weapon lying in the world. WeaponManager picks it up with G.

@export var weapon_script: Script

var weapon: Weapon
var _time := randf() * TAU


func _ready() -> void:
	add_to_group("weapon_pickup")
	if weapon == null and weapon_script != null:
		weapon = weapon_script.new()
	if weapon != null and weapon.get_parent() == null:
		add_child(weapon)
	_build_ring()


func _process(delta: float) -> void:
	_time += delta
	if weapon != null:
		weapon.transform = Transform3D(Basis(Vector3.UP, _time * 1.5).scaled(Vector3.ONE * 2.0), Vector3(0.0, 0.6 + sin(_time * 2.0) * 0.1, 0.0))


func take() -> Weapon:
	var w := weapon
	weapon = null
	remove_child(w)
	w.transform = Transform3D.IDENTITY
	queue_free()
	return w


func _build_ring() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.55
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.2)
	mat.emission_energy_multiplier = 1.5
	ring.material_override = mat
	ring.position.y = 0.05
	add_child(ring)
