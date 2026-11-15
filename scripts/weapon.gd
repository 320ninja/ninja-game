class_name Weapon
extends Node3D

signal fired(hit: Object)

@export var weapon_name := "Weapon"
@export var damage := 10.0
@export var mag_size := 10
@export var fire_rate := 0.5
@export var reload_time := 1.5
@export var max_range := 60.0
## Random aim error in radians. Player guns are exact, officers miss sometimes.
@export var spread := 0.0
@export var reserve := 36
@export var infinite_reserve := false

var ammo := -1
var reloading := false

var _cooldown := 0.0
var _reload_left := 0.0
var _ray: RayCast3D
var _flash: OmniLight3D


func _ready() -> void:
	if ammo < 0:
		ammo = mag_size
	_ray = RayCast3D.new()
	_ray.top_level = true
	_ray.enabled = false
	add_child(_ray)
	_build_visual()


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _flash.visible and _cooldown < fire_rate - 0.05:
		_flash.visible = false
	if reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()


func can_fire() -> bool:
	return not reloading and _cooldown == 0.0 and ammo > 0


## Shoots from `from` along `dir`, damages any Health it hits, returns the collider.
func fire(from: Vector3, dir: Vector3, shooter: CollisionObject3D = null) -> Object:
	if not can_fire():
		if ammo == 0:
			reload()
		return null
	ammo -= 1
	_cooldown = fire_rate
	_flash.visible = true
	if spread > 0.0:
		dir = dir.normalized() + Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))
	_ray.clear_exceptions()
	if shooter != null:
		_ray.add_exception(shooter)
	_ray.global_transform = Transform3D(Basis(), from)
	_ray.target_position = dir.normalized() * max_range
	_ray.force_raycast_update()
	var hit := _ray.get_collider()
	var health := Health.of(hit)
	if health != null:
		health.take_damage(damage)
	fired.emit(hit)
	if ammo == 0:
		reload()
	return hit


func reload() -> void:
	if reloading or ammo >= mag_size or (reserve <= 0 and not infinite_reserve):
		return
	reloading = true
	_reload_left = reload_time


func add_ammo(amount: int) -> void:
	reserve += amount


func _finish_reload() -> void:
	reloading = false
	var take := mag_size - ammo
	if not infinite_reserve:
		take = mini(take, reserve)
		reserve -= take
	ammo += take


func _build_visual() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.13)
	mat.metallic = 0.6
	mat.roughness = 0.4
	var slide := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.07, 0.22)
	slide.mesh = box
	slide.material_override = mat
	slide.position = Vector3(0.0, 0.03, 0.06)
	add_child(slide)
	var grip := MeshInstance3D.new()
	var grip_box := BoxMesh.new()
	grip_box.size = Vector3(0.045, 0.13, 0.06)
	grip.mesh = grip_box
	grip.material_override = mat
	grip.position = Vector3(0.0, -0.05, -0.02)
	grip.rotation.x = -0.25
	add_child(grip)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.8, 0.4)
	_flash.light_energy = 3.0
	_flash.omni_range = 3.0
	_flash.position = Vector3(0.0, 0.03, 0.22)
	_flash.visible = false
	add_child(_flash)
