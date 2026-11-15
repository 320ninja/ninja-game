class_name Atm
extends Area3D
## ATM kiosk. Press E nearby (on foot) to pay off your wanted level.

const FINE_PER_STAR := 200

@export var radius := 2.5

var _near := false
var _prompt: Label3D
var _layer: CanvasLayer
var _text: Label
var _yes: Button
var _no: Button
var _restore_capture := false


func _ready() -> void:
	monitoring = true
	body_entered.connect(func(b: Node3D) -> void: if b.is_in_group("player"): _set_near(true))
	body_exited.connect(func(b: Node3D) -> void: if b.is_in_group("player"): _set_near(false))
	_build_trigger()
	_build_kiosk()
	_build_dialog()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = event.keycode
	if _layer.visible:
		if (key == KEY_Y or key == KEY_ENTER) and _yes.visible:
			_on_yes()
		elif key == KEY_ENTER:
			_close()
		elif key == KEY_N or key == KEY_ESCAPE or key == KEY_E:
			_close()
		else:
			return
		get_viewport().set_input_as_handled()
	elif key == KEY_E and _near and not _driving():
		_open()
		get_viewport().set_input_as_handled()


func fine() -> int:
	return WantedSystem.level * FINE_PER_STAR


func _open() -> void:
	if WantedSystem.level == 0:
		_show("No fines to pay.", false)
	else:
		_show("Pay fine %s?" % Wallet.format(fine()), true)
	_restore_capture = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_layer.visible = true


func _on_yes() -> void:
	if not Wallet.spend(fine()):
		_show("Not enough money", false)
		return
	WantedSystem.clear()
	_close()


func _close() -> void:
	_layer.visible = false
	if _restore_capture:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show(text: String, ask: bool) -> void:
	_text.text = text
	_yes.visible = ask
	_no.text = "No" if ask else "Close"


func _set_near(value: bool) -> void:
	_near = value
	_prompt.visible = value
	if not value and _layer.visible:
		_close()


func _driving() -> bool:
	var game := get_tree().get_first_node_in_group("game")
	return game != null and game.driving != null


func _build_trigger() -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 1.0
	add_child(col)


func _build_kiosk() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 1.9, 0.6)
	var col := CollisionShape3D.new()
	col.shape = box
	col.position.y = 0.95
	body.add_child(col)

	var shell := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	shell.mesh = mesh
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.15, 0.32, 0.55)
	metal.metallic = 0.5
	metal.roughness = 0.4
	shell.material_override = metal
	shell.position.y = 0.95
	body.add_child(shell)

	var screen := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.4)
	screen.mesh = quad
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.3, 1.0, 0.6)
	glow.emission_enabled = true
	glow.emission = Color(0.3, 1.0, 0.6)
	glow.emission_energy_multiplier = 2.0
	screen.material_override = glow
	screen.position = Vector3(0.0, 1.35, 0.301)
	body.add_child(screen)

	var sign := Label3D.new()
	sign.text = "ATM"
	sign.font_size = 72
	sign.pixel_size = 0.006
	sign.outline_size = 10
	sign.position = Vector3(0.0, 2.15, 0.0)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)

	_prompt = Label3D.new()
	_prompt.text = "E   Pay fine"
	_prompt.font_size = 48
	_prompt.pixel_size = 0.006
	_prompt.outline_size = 10
	_prompt.modulate = Color(1.0, 0.85, 0.3)
	_prompt.no_depth_test = true
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.position = Vector3(0.0, 2.6, 0.0)
	_prompt.visible = false
	add_child(_prompt)


func _build_dialog() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	_layer.visible = false
	add_child(_layer)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.9)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -220.0
	panel.offset_right = 220.0
	panel.offset_top = -80.0
	panel.offset_bottom = 80.0
	_layer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	_text = Label.new()
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.add_theme_font_size_override("font_size", 28)
	box.add_child(_text)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)

	_yes = Button.new()
	_yes.text = "Yes"
	_yes.custom_minimum_size = Vector2(120, 48)
	_yes.pressed.connect(_on_yes)
	row.add_child(_yes)

	_no = Button.new()
	_no.text = "No"
	_no.custom_minimum_size = Vector2(120, 48)
	_no.pressed.connect(_close)
	row.add_child(_no)
