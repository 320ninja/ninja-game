extends Control
## HUD minimap. Bottom-left corner. Toggle with Tab.
## Shows player (white), police (red), mission triggers (yellow).
## Rotates so player heading is always "up".

const SIZE := 150.0
const RANGE := 120.0
const DOT_PLAYER := 5.0
const DOT_NPC := 4.0
const BG := Color(0.05, 0.07, 0.1, 0.78)
const BORDER := Color(0.3, 0.3, 0.35, 0.9)
const COL_PLAYER := Color(1.0, 1.0, 1.0)
const COL_POLICE := Color(1.0, 0.22, 0.22)
const COL_MISSION := Color(1.0, 0.85, 0.2)

var _game: Node


func _ready() -> void:
	add_to_group("minimap")
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	offset_top = -SIZE - 28.0
	offset_bottom = -28.0
	offset_right = SIZE
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = MOUSE_FILTER_IGNORE
	_game = get_tree().get_first_node_in_group("game")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_TAB:
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	if _game == null:
		_game = get_tree().get_first_node_in_group("game")
	queue_redraw()


func _draw() -> void:
	var half := SIZE * 0.5
	var centre := Vector2(half, half)

	# Background disc
	draw_circle(centre, half, BG)
	# Border ring
	draw_arc(centre, half - 1.0, 0.0, TAU, 48, BORDER, 2.0, true)

	var origin: Node3D = _game.get_active() if _game != null else null
	if origin == null:
		return

	var player_pos := origin.global_position
	var heading := origin.rotation.y if not (origin is RigidBody3D) \
		else atan2(origin.global_transform.basis.z.x, origin.global_transform.basis.z.z)

	# Mission triggers
	for trigger in get_tree().get_nodes_in_group("mission_trigger"):
		_draw_dot(centre, player_pos, heading, trigger.global_position, DOT_NPC, COL_MISSION)

	# Police
	for officer in get_tree().get_nodes_in_group("police"):
		_draw_dot(centre, player_pos, heading, officer.global_position, DOT_NPC, COL_POLICE)
	for car in get_tree().get_nodes_in_group("police_car"):
		_draw_dot(centre, player_pos, heading, car.global_position, DOT_NPC, COL_POLICE)

	# Player dot last (on top)
	draw_circle(centre, DOT_PLAYER, COL_PLAYER)


func _draw_dot(centre: Vector2, origin: Vector3, heading: float,
		world_pos: Vector3, radius: float, colour: Color) -> void:
	var delta := world_pos - origin
	var local := Vector2(delta.x, delta.z)
	# Rotate so player heading is up
	var c := cos(-heading)
	var s := sin(-heading)
	local = Vector2(c * local.x - s * local.y, s * local.x + c * local.y)
	var half := SIZE * 0.5
	var scale := half / RANGE
	var screen := centre + local * scale
	if screen.distance_to(centre) > half - radius:
		return
	draw_circle(screen, radius, colour)
