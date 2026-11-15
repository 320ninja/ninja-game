class_name WeaponManager
extends Node3D
## On the Player. G picks up, R reloads, left click fires (touch FIRE button calls fire()).

signal weapon_changed(weapon: Weapon)

const PICKUP_RANGE := 2.5
const CHEST := Vector3(0.0, 1.3, 0.0)

var current: Weapon

var _game: Node
@onready var _player: CharacterBody3D = get_parent()


func _ready() -> void:
	add_to_group("weapon_manager")
	position = Vector3(0.28, 1.15, 0.35)


func _unhandled_input(event: InputEvent) -> void:
	if not _can_act():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			pick_up_nearest()
		elif event.keycode == KEY_R:
			reload()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		fire()


func fire() -> void:
	if current == null or not current.can_fire():
		if current != null and current.ammo == 0:
			current.reload()
		return
	var from := _player.global_position + CHEST
	var dir := _aim_direction(from)
	_player.rotation.y = atan2(dir.x, dir.z)
	var hit := current.fire(from, dir, _player)
	_player.on_weapon_fired(hit)


func reload() -> void:
	if current != null:
		current.reload()


func pick_up_nearest() -> void:
	var best: WeaponPickup = null
	var best_distance := PICKUP_RANGE
	for pickup: WeaponPickup in get_tree().get_nodes_in_group("weapon_pickup"):
		var d := pickup.global_position.distance_to(_player.global_position)
		if d < best_distance and pickup.weapon != null:
			best_distance = d
			best = pickup
	if best != null:
		equip(best.take())


func equip(weapon: Weapon) -> void:
	if current != null and current.get_script() == weapon.get_script():
		current.add_ammo(weapon.ammo + weapon.reserve)
		weapon.queue_free()
		return
	drop()
	current = weapon
	add_child(weapon)
	weapon.transform = Transform3D.IDENTITY
	weapon_changed.emit(current)


func drop() -> void:
	if current == null:
		return
	var pickup := WeaponPickup.new()
	remove_child(current)
	pickup.weapon = current
	pickup.add_child(current)
	current = null
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = _player.global_position + _player.global_transform.basis.z + Vector3.UP * 0.1
	weapon_changed.emit(null)


func _can_act() -> bool:
	if _game == null:
		_game = get_tree().get_first_node_in_group("game")
	return not _player.dead and (_game == null or _game.driving == null)


## Aim at whatever is under the screen centre, but shoot from the chest.
func _aim_direction(from: Vector3) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return _player.global_transform.basis.z
	var origin := cam.global_position
	var target := origin - cam.global_transform.basis.z * current.max_range
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [_player.get_rid()]
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		target = hit.position
	var dir := target - from
	return dir.normalized() if dir.length_squared() > 0.01 else _player.global_transform.basis.z
