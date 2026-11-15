class_name MissionTrigger
extends Area3D
## A trigger zone for missions: a glowing cylinder on the ground, an optional
## floating marker and name above it, and a signal when the player walks
## (or drives) in. Drop one in a scene, set the exports, done. It builds its
## own collision and visuals so nothing else has to be set up by hand.

signal player_entered

@export var radius := 2.5
@export var colour := Color(1.0, 0.82, 0.1)  # mission yellow
## Text floating above the zone. Empty hides it.
@export var label := ""
## Diamond marker bobbing overhead, so it can be seen down the street.
@export var show_marker := true
@export var marker_height := 3.2

var _visuals: Node3D
var _marker: MeshInstance3D
var _time := 0.0


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_collision()
	_build_visuals()


func _process(delta: float) -> void:
	if _marker == null or not _visuals.visible:
		return
	_time += delta
	_marker.position.y = marker_height + sin(_time * 2.5) * 0.2
	_marker.rotation.y = _time * 1.5


## Turn the zone on or off. Off = invisible and ignores the player.
func set_active(active: bool) -> void:
	visible = active
	_visuals.visible = active
	set_deferred("monitoring", active)


## True if the player is standing in the zone right now (on foot or in a car).
func has_player() -> bool:
	if not monitoring:
		return false
	for body in get_overlapping_bodies():
		if _is_player(body):
			return true
	return false


func _on_body_entered(body: Node3D) -> void:
	if _is_player(body):
		player_entered.emit()


## The player on foot, or whatever vehicle the player is driving.
func _is_player(body: Node) -> bool:
	if body.is_in_group("player"):
		return true
	return body.is_in_group("vehicle") and body.get("active") == true


func _build_collision() -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 4.0
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 2.0
	add_child(col)


func _build_visuals() -> void:
	_visuals = Node3D.new()
	add_child(_visuals)

	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.albedo_color = Color(colour, 0.35)

	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 1.2
	cyl.cap_top = false
	cyl.cap_bottom = false
	ring.mesh = cyl
	ring.material_override = glow
	ring.position.y = 0.6
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuals.add_child(ring)

	if show_marker:
		var solid := StandardMaterial3D.new()
		solid.albedo_color = colour
		solid.emission_enabled = true
		solid.emission = colour
		solid.emission_energy_multiplier = 1.5
		_marker = MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.6, 0.7, 0.6)
		_marker.mesh = prism
		_marker.material_override = solid
		_marker.rotation_degrees.z = 180.0  # point down at the spot
		_marker.position.y = marker_height
		_visuals.add_child(_marker)

	if label != "":
		var text := Label3D.new()
		text.text = label
		text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		text.font_size = 64
		text.pixel_size = 0.01
		text.outline_size = 12
		text.modulate = colour
		text.no_depth_test = true
		text.position.y = marker_height + 0.9
		_visuals.add_child(text)
