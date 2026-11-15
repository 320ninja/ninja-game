extends CanvasLayer
## On-screen touch controls (autoload). Hidden on devices without a touchscreen.
## Left half: floating joystick -> `move`. Right half: drag to look -> take_look().
## Buttons: held("jump"), held("punch"), plus E/G/R/TAB key taps and FIRE.
## On web it also shows a "tap to play" screen, since browsers only hand over
## keyboard focus and pointer lock after the first click.

const STICK_RADIUS := 80.0
const DEAD := 0.15
const LOOK_SENSITIVITY := 0.006

var enabled := false
var move := Vector2.ZERO

var _held := {}
var _look := Vector2.ZERO
var _stick_touch := -1
var _look_touch := -1
var _stick_center := Vector2.ZERO
var _stick_base: Control
var _stick_knob: Control
var _buttons: Array[_TouchBtn] = []
var _start_screen: Control


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = DisplayServer.is_touchscreen_available()
	if enabled:
		_build_ui()
	if OS.has_feature("web"):
		_build_start_screen()


func held(action: String) -> bool:
	return _held.get(action, false)


func take_look() -> Vector2:
	var l := _look
	_look = Vector2.ZERO
	return l


func _input(event: InputEvent) -> void:
	if _start_screen != null:
		if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
			_start_screen.queue_free()
			_start_screen = null
			if not enabled:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return
	if not enabled:
		return
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)


func _on_touch(ev: InputEventScreenTouch) -> void:
	if ev.pressed:
		for b in _buttons:
			if b.hit(ev.position):
				b.press(ev.index)
				return
		if ev.position.x < _screen().x * 0.45:
			if _stick_touch < 0:
				_stick_touch = ev.index
				_stick_center = ev.position
				_place_stick(ev.position, Vector2.ZERO)
		elif _look_touch < 0:
			_look_touch = ev.index
		return
	for b in _buttons:
		b.release(ev.index)
	if ev.index == _stick_touch:
		_stick_touch = -1
		move = Vector2.ZERO
		_place_stick(_default_stick_pos(), Vector2.ZERO)
	elif ev.index == _look_touch:
		_look_touch = -1


func _on_drag(ev: InputEventScreenDrag) -> void:
	if ev.index == _stick_touch:
		var d := (ev.position - _stick_center).limit_length(STICK_RADIUS)
		_place_stick(_stick_center, d)
		var v := d / STICK_RADIUS
		move = Vector2(v.x, -v.y) if v.length() > DEAD else Vector2.ZERO
	elif ev.index == _look_touch:
		_look += ev.relative * LOOK_SENSITIVITY


func _place_stick(center: Vector2, offset: Vector2) -> void:
	_stick_base.position = center - _stick_base.size * 0.5
	_stick_knob.position = center + offset - _stick_knob.size * 0.5


func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size


func _default_stick_pos() -> Vector2:
	return Vector2(170, _screen().y - 170)


func _build_ui() -> void:
	_stick_base = _rect(Vector2.ONE * STICK_RADIUS * 2, Color(1, 1, 1, 0.14))
	_stick_knob = _rect(Vector2(64, 64), Color(1, 1, 1, 0.45))
	_place_stick(_default_stick_pos(), Vector2.ZERO)
	var right := func(x: float, y: float) -> Vector2: return Vector2(_screen().x - x, _screen().y - y)
	_add_btn("JUMP", func(): return right.call(90, 90), "jump")
	_add_btn("HIT", func(): return right.call(200, 90), "punch")
	_add_btn("FIRE", func(): return right.call(90, 200), "fire")
	_add_btn("E", func(): return right.call(200, 200), "", KEY_E)
	_add_btn("G", func(): return right.call(310, 90), "", KEY_G)
	_add_btn("R", func(): return right.call(310, 200), "", KEY_R)
	_add_btn("MAP", func(): return Vector2(_screen().x - 70, 160), "", KEY_TAB)
	get_viewport().size_changed.connect(_relayout)


func _relayout() -> void:
	if _stick_touch < 0:
		_place_stick(_default_stick_pos(), Vector2.ZERO)
	for b in _buttons:
		b.layout()


func _rect(size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _add_btn(text: String, pos_fn: Callable, action: String, key := KEY_NONE) -> void:
	var b := _TouchBtn.new(text, pos_fn, action, key, self)
	add_child(b)
	_buttons.append(b)


func _on_button(action: String, key: int, pressed: bool) -> void:
	if action == "fire":
		if pressed:
			var wm := get_tree().get_first_node_in_group("weapon_manager")
			if wm != null and wm.has_method("fire"):
				wm.fire()
	elif action != "":
		_held[action] = pressed
	if key != KEY_NONE:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.physical_keycode = key
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _build_start_screen() -> void:
	_start_screen = ColorRect.new()
	_start_screen.color = Color(0, 0, 0, 0.6)
	_start_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_start_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = "TAP TO PLAY" if enabled else "CLICK TO PLAY\nWASD move · mouse look · ESC frees mouse"
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 40)
	_start_screen.add_child(lbl)
	add_child(_start_screen)


class _TouchBtn extends ColorRect:
	var _action: String
	var _key: int
	var _pos_fn: Callable
	var _ctrl: Node
	var _touch := -1

	func _init(text: String, pos_fn: Callable, action: String, key: int, ctrl: Node) -> void:
		_action = action; _key = key; _pos_fn = pos_fn; _ctrl = ctrl
		size = Vector2(90, 90)
		color = Color(1, 1, 1, 0.2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lbl := Label.new()
		lbl.text = text
		lbl.size = size
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 24)
		add_child(lbl)

	func _ready() -> void:
		layout()

	func layout() -> void:
		position = _pos_fn.call() - size * 0.5

	func hit(p: Vector2) -> bool:
		return _touch < 0 and get_global_rect().grow(10).has_point(p)

	func press(index: int) -> void:
		_touch = index
		color = Color(1, 1, 1, 0.5)
		_ctrl._on_button(_action, _key, true)

	func release(index: int) -> void:
		if index != _touch:
			return
		_touch = -1
		color = Color(1, 1, 1, 0.2)
		_ctrl._on_button(_action, _key, false)
