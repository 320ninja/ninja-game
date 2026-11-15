extends CanvasLayer
## On-screen touch controls. Auto-hides on desktop.
## Left: virtual joystick → injects W/A/S/D key events.
## Right: Jump/Handbrake (Space), Enter car (E), Sprint (Shift), Radio (R), Minimap (Tab).

const STICK_RADIUS := 80.0
const DEAD := 14.0

var _stick_base_pos := Vector2.ZERO
var _stick_knob: ColorRect
var _stick_touch := -1
var _active: Dictionary = {}


func _ready() -> void:
	if not DisplayServer.is_touchscreen_available():
		visible = false
		return
	layer = 10
	_build_ui()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _build_ui() -> void:
	var vp := get_viewport().get_visible_rect().size

	# Joystick base (left)
	_stick_base_pos = Vector2(170, vp.y - 170)
	var base := ColorRect.new()
	base.size = Vector2(STICK_RADIUS * 2, STICK_RADIUS * 2)
	base.position = _stick_base_pos - base.size * 0.5
	base.color = Color(1, 1, 1, 0.14)
	add_child(base)

	_stick_knob = ColorRect.new()
	_stick_knob.size = Vector2(60, 60)
	_stick_knob.position = _stick_base_pos - _stick_knob.size * 0.5
	_stick_knob.color = Color(1, 1, 1, 0.42)
	add_child(_stick_knob)

	# Right buttons
	var rx := vp.x - 90.0
	var ry := vp.y - 90.0
	_btn("▲", Vector2(rx, ry - 120), KEY_SPACE)   # handbrake
	_btn("E",  Vector2(rx - 110, ry), KEY_E)        # enter/exit car
	_btn("⚡", Vector2(rx, ry),         KEY_SHIFT)   # sprint/boost
	_btn("♫",  Vector2(rx - 110, ry - 120), KEY_R)  # radio
	_btn("⊞",  Vector2(90, 90),          KEY_TAB)   # minimap


func _btn(text: String, pos: Vector2, key: int) -> void:
	var b := _TouchBtn.new(text, pos, key, self)
	add_child(b)


func _handle_touch(ev: InputEventScreenTouch) -> void:
	if ev.position.x > get_viewport().get_visible_rect().size.x * 0.46:
		return
	if ev.pressed and _stick_touch < 0:
		_stick_touch = ev.index
		_stick_base_pos = ev.position
		_stick_knob.position = _stick_base_pos - _stick_knob.size * 0.5
	elif not ev.pressed and ev.index == _stick_touch:
		_stick_touch = -1
		_stick_knob.position = _stick_base_pos - _stick_knob.size * 0.5
		_send(KEY_W, false); _send(KEY_S, false)
		_send(KEY_A, false); _send(KEY_D, false)
		_active.clear()


func _handle_drag(ev: InputEventScreenDrag) -> void:
	if ev.index != _stick_touch:
		return
	var d := (ev.position - _stick_base_pos).limit_length(STICK_RADIUS)
	_stick_knob.position = _stick_base_pos + d - _stick_knob.size * 0.5
	_set_key(KEY_W, d.y < -DEAD)
	_set_key(KEY_S, d.y >  DEAD)
	_set_key(KEY_A, d.x < -DEAD)
	_set_key(KEY_D, d.x >  DEAD)


func _set_key(key: int, pressed: bool) -> void:
	if _active.get(key, false) == pressed:
		return
	_active[key] = pressed
	_send(key, pressed)


func _send(key: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.pressed = pressed
	Input.parse_input_event(ev)


func fire(key: int, pressed: bool) -> void:
	_send(key, pressed)


class _TouchBtn extends Control:
	var _key: int
	var _ctrl: Node
	var _bg: ColorRect
	var _touch := -1

	func _init(text: String, pos: Vector2, key: int, ctrl: Node) -> void:
		_key = key; _ctrl = ctrl
		size = Vector2(76, 76)
		position = pos - size * 0.5
		_bg = ColorRect.new()
		_bg.size = size
		_bg.color = Color(1, 1, 1, 0.20)
		add_child(_bg)
		var lbl := Label.new()
		lbl.text = text
		lbl.size = size
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 28)
		add_child(lbl)

	func _input(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch:
			if ev.pressed and _touch < 0 and get_global_rect().has_point(ev.position):
				_touch = ev.index
				_bg.color = Color(1, 1, 1, 0.5)
				_ctrl.fire(_key, true)
			elif not ev.pressed and ev.index == _touch:
				_touch = -1
				_bg.color = Color(1, 1, 1, 0.20)
				_ctrl.fire(_key, false)
