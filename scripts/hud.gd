extends CanvasLayer
## Readout for whatever the player is currently controlling, the context
## prompt for getting in and out of cars, and the mission UI (money, timer,
## dialogue box, pass/fail banner). Missions talk to the HUD through the
## "hud" group, so they only need: show_dialogue, set_timer, hide_timer,
## show_banner, show_progress, hide_progress. Wanted stars follow WantedSystem on their own.

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
var _health_bar: ProgressBar
var _car_bar: ProgressBar
var _ammo: Label
var _progress: ProgressBar
var _progress_label: Label
var _player_health: Health
var _weapons: WeaponManager
var _radio_label: Label
var _radio_left := 0.0
const RADIO_SHOW := 2.5


func _ready() -> void:
	add_to_group("hud")
	_game = get_tree().get_first_node_in_group("game")
	_build_mission_ui()
	_minimap = load("res://scripts/minimap.gd").new()
	add_child(_minimap)
	Wallet.money_changed.connect(_on_money_changed)
	if has_node("/root/Radio"):
		get_node("/root/Radio").station_changed.connect(_on_station_changed)
	_on_money_changed(Wallet.money)
	WantedSystem.wanted_changed.connect(_stars.set_level)
	_stars.set_level(WantedSystem.level)
	WantedSystem.busted.connect(_on_busted)


func _process(delta: float) -> void:
	_tick_popups(delta)
	_update_combat()

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


func _update_combat() -> void:
	if _player_health == null:
		_player_health = Health.of(get_tree().get_first_node_in_group("player"))
		_weapons = get_tree().get_first_node_in_group("weapon_manager")
	if _player_health != null:
		_health_bar.value = _player_health.current_hp / _player_health.max_hp * 100.0
	var car_health: VehicleHealth = VehicleHealth.of(_game.driving) if _game != null else null
	_car_bar.visible = car_health != null
	if car_health != null:
		_car_bar.value = car_health.current_hp / car_health.max_hp * 100.0
	var weapon: Weapon = _weapons.current if _weapons != null else null
	_ammo.visible = weapon != null
	if weapon != null:
		_ammo.text = "RELOADING" if weapon.reloading else "%d / %d" % [weapon.ammo, weapon.reserve]


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


## Action bar in the middle of the screen, ratio 0..1.
func show_progress(text: String, ratio: float) -> void:
	_progress_label.text = text
	_progress.value = clampf(ratio, 0.0, 1.0) * 100.0
	_progress.visible = true
	_progress_label.visible = true


func hide_progress() -> void:
	_progress.visible = false
	_progress_label.visible = false


## Big centred message, e.g. "Mission Complete!".
func show_banner(text: String, colour: Color = Color.WHITE) -> void:
	_banner.text = text
	_banner.modulate = colour
	_banner.visible = true
	_banner_left = BANNER_SECONDS
	_dialogue.visible = false


func _on_station_changed(name: String) -> void:
	if _radio_label == null:
		_radio_label = _make_label(22, HORIZONTAL_ALIGNMENT_LEFT)
		_radio_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		_radio_label.offset_left = 180.0
		_radio_label.offset_right = 480.0
		_radio_label.offset_top = -32.0
		_radio_label.offset_bottom = -4.0
		_radio_label.modulate = Color(0.6, 0.85, 1.0)
	_radio_label.text = "♫  " + name
	_radio_label.visible = true
	_radio_left = RADIO_SHOW


func _tick_popups(delta: float) -> void:
	if _dialogue.visible:
		_dialogue_left -= delta
		if _dialogue_left <= 0.0:
			_dialogue.visible = false
	if _banner.visible:
		_banner_left -= delta
		if _banner_left <= 0.0:
			_banner.visible = false
	if _radio_label != null and _radio_label.visible:
		_radio_left -= delta
		if _radio_left <= 0.0:
			_radio_label.visible = false


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

	_health_bar = _make_bar(Color(0.85, 0.12, 0.12), -206.0, 16.0)
	_car_bar = _make_bar(Color(0.95, 0.6, 0.15), -222.0, 10.0)
	_car_bar.visible = false

	_ammo = _make_label(32, HORIZONTAL_ALIGNMENT_RIGHT)
	_ammo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo.offset_left = -320.0
	_ammo.offset_right = -28.0
	_ammo.offset_top = -76.0
	_ammo.offset_bottom = -28.0
	_ammo.visible = false

	_progress_label = _make_label(30, HORIZONTAL_ALIGNMENT_CENTER)
	_progress_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_progress_label.offset_left = -200.0
	_progress_label.offset_right = 200.0
	_progress_label.offset_top = 40.0
	_progress_label.offset_bottom = 80.0
	_progress_label.modulate = Color(1.0, 0.85, 0.3)
	_progress_label.visible = false

	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_progress.offset_left = -180.0
	_progress.offset_right = 180.0
	_progress.offset_top = 84.0
	_progress.offset_bottom = 102.0
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(1.0, 0.8, 0.2)
	bar_fill.set_corner_radius_all(4)
	_progress.add_theme_stylebox_override("fill", bar_fill)
	_progress.add_theme_stylebox_override("background", _health_bar.get_theme_stylebox("background"))
	_progress.visible = false
	add_child(_progress)

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


func _make_bar(colour: Color, top: float, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bar.offset_left = 0.0
	bar.offset_right = 150.0
	bar.offset_top = top
	bar.offset_bottom = top + height
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	fill.set_corner_radius_all(4)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.05, 0.07, 0.75)
	back.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	bar.value = 100.0
	add_child(bar)
	return bar


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
