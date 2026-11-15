extends CanvasLayer
## Readout for whatever the player is currently controlling, the context
## prompt for getting in and out of cars, and the mission UI (money, timer,
## dialogue box, pass/fail banner). Missions talk to the HUD through the
## "hud" group, so they only need: show_dialogue, set_timer, hide_timer,
## show_banner. Wanted stars follow WantedSystem on their own.

const DIALOGUE_SECONDS := 5.0
const BANNER_SECONDS := 3.5

@onready var _speed:   Label = $Speed
@onready var _prompt:  Label = $Prompt

var _game:    Node

var _money: Label
var _timer: Label
var _dialogue: PanelContainer
var _dialogue_text: RichTextLabel
var _banner: Label
var _dialogue_left := 0.0
var _banner_left := 0.0
var _stars: WantedStars
var _minimap: Node


func _ready() -> void:
	add_to_group("hud")
	_game = get_tree().get_first_node_in_group("game")
	_build_mission_ui()
	_minimap = load("res://scripts/minimap.gd").new()
	add_child(_minimap)
	Wallet.money_changed.connect(_on_money_changed)
	_on_money_changed(Wallet.money)
	WantedSystem.wanted_changed.connect(_stars.set_level)
	_stars.set_level(WantedSystem.level)
	WantedSystem.busted.connect(_on_busted)


func _process(delta: float) -> void:
	_tick_popups(delta)

	if _game == null:
		_game = get_tree().get_first_node_in_group("game")
		return

	# --- speed / vehicle prompt ---
	var active: Node = _game.get_active()
	if active == null:
		return

	if _game.driving != null:
		_speed.text = "%d km/h" % roundi(active.get_speed_kmh())
		if active.boosting:
			_speed.text += "   BOOST"
			_speed.modulate = Color(1.0, 0.72, 0.3)
		else:
			_speed.modulate = Color.WHITE
		_prompt.text = "E   get out"
	else:
		_speed.text = "on foot"
		_speed.modulate = Color.WHITE
		_prompt.text = "E   get in" if _game.nearest_vehicle() != null else ""


# --- Mission UI -----------------------------------------------------------

## Dialogue box at the bottom. Hides itself after a few seconds.
func show_dialogue(speaker: String, text: String) -> void:
	var line := text
	if speaker != "":
		line = "[color=#ffd23f][b]%s[/b][/color]\n%s" % [speaker, text]
	_dialogue_text.text = line
	_dialogue.visible = true
	_dialogue_left = DIALOGUE_SECONDS


## Countdown at the top. Turns red in the last 30 seconds.
func set_timer(seconds_left: float) -> void:
	var total := ceili(seconds_left)
	_timer.text = "%d:%02d" % [total / 60, total % 60]
	_timer.modulate = Color(1.0, 0.35, 0.3) if seconds_left <= 30.0 else Color.WHITE
	_timer.visible = true


func hide_timer() -> void:
	_timer.visible = false


## Big centred message, e.g. "Mission Complete!".
func show_banner(text: String, colour: Color = Color.WHITE) -> void:
	_banner.text = text
	_banner.modulate = colour
	_banner.visible = true
	_banner_left = BANNER_SECONDS
	_dialogue.visible = false


func _tick_popups(delta: float) -> void:
	if _dialogue.visible:
		_dialogue_left -= delta
		if _dialogue_left <= 0.0:
			_dialogue.visible = false
	if _banner.visible:
		_banner_left -= delta
		if _banner_left <= 0.0:
			_banner.visible = false


func _on_busted(fine: int) -> void:
	var text := "BUSTED"
	if fine > 0:
		text += "\n-" + Wallet.format(fine)
	show_banner(text, Color(0.45, 0.65, 1.0))


func _on_money_changed(amount: int) -> void:
	_money.text = Wallet.format(amount)


## Built in code rather than in world.tscn so any scene with this HUD gets it.
func _build_mission_ui() -> void:
	_money = _make_label(32, HORIZONTAL_ALIGNMENT_RIGHT)
	_money.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_money.offset_left = -360.0
	_money.offset_right = -28.0
	_money.offset_top = 20.0
	_money.offset_bottom = 64.0
	_money.modulate = Color(0.55, 1.0, 0.6)

	_timer = _make_label(48, HORIZONTAL_ALIGNMENT_CENTER)
	_timer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_timer.offset_left = -120.0
	_timer.offset_right = 120.0
	_timer.offset_top = 16.0
	_timer.offset_bottom = 76.0
	_timer.visible = false

	_banner = _make_label(56, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.offset_left = -500.0
	_banner.offset_right = 500.0
	_banner.offset_top = -140.0
	_banner.offset_bottom = 20.0
	_banner.visible = false

	_stars = WantedStars.new()
	_stars.position = Vector2(28.0, 152.0)
	add_child(_stars)

	_dialogue = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.82)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	_dialogue.add_theme_stylebox_override("panel", style)
	_dialogue.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_dialogue.offset_left = -420.0
	_dialogue.offset_right = 420.0
	_dialogue.offset_top = -170.0
	_dialogue.offset_bottom = -40.0
	_dialogue.visible = false
	add_child(_dialogue)

	_dialogue_text = RichTextLabel.new()
	_dialogue_text.bbcode_enabled = true
	_dialogue_text.fit_content = true
	_dialogue_text.scroll_active = false
	_dialogue_text.add_theme_font_size_override("normal_font_size", 24)
	_dialogue_text.add_theme_font_size_override("bold_font_size", 24)
	_dialogue.add_child(_dialogue_text)


func _make_label(size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	return label


## Five drawn stars (polygons, so no font glyph needed). Filled = wanted level.
## Blinks while the police have lost sight and the level is cooling off.
class WantedStars extends Control:
	const COUNT := 5
	const SIZE := 34.0
	const GAP := 6.0
	const FILL := Color(1.0, 0.82, 0.2)
	const EMPTY := Color(0.1, 0.1, 0.12, 0.55)
	const OUTLINE := Color(0, 0, 0, 0.8)

	var level := 0
	var _blink := 0.0

	func _init() -> void:
		size = Vector2(COUNT * (SIZE + GAP), SIZE)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func set_level(value: int) -> void:
		level = value
		visible = level > 0
		queue_redraw()

	func _process(delta: float) -> void:
		if level == 0:
			return
		_blink += delta
		var dim := not WantedSystem.is_seen() and fmod(_blink, 0.8) > 0.4
		modulate.a = 0.45 if dim else 1.0

	func _draw() -> void:
		for i in COUNT:
			var centre := Vector2(i * (SIZE + GAP) + SIZE * 0.5, SIZE * 0.5)
			var points := _star(centre, SIZE * 0.5, SIZE * 0.22)
			draw_colored_polygon(points, FILL if i < level else EMPTY)
			points.append(points[0])
			draw_polyline(points, OUTLINE, 2.0, true)

	func _star(centre: Vector2, outer: float, inner: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		for k in 10:
			var r := outer if k % 2 == 0 else inner
			var a := -PI * 0.5 + k * PI / 5.0
			points.append(centre + Vector2(cos(a), sin(a)) * r)
		return points
