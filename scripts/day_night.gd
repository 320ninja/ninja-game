extends Node
## Autoload "DayNight". One game-day = 24 real minutes (1 real min = 1 game hour).

signal hour_changed(hour: int)

const DAY_SECONDS := 24.0 * 60.0
const NIGHT_SIGHT := 20.0
const CURFEW_START := 23.0
const CURFEW_END := 5.0
const CURFEW_STAR_SECONDS := 120.0

# hour, sky top, horizon, light colour, light energy, ambient energy
const KEYS := [
	[0.0, Color(0.02, 0.03, 0.08), Color(0.06, 0.08, 0.16), Color(0.55, 0.65, 1.0), 0.25, 0.25],
	[5.0, Color(0.02, 0.03, 0.08), Color(0.06, 0.08, 0.16), Color(0.55, 0.65, 1.0), 0.25, 0.25],
	[6.5, Color(0.35, 0.40, 0.60), Color(0.98, 0.62, 0.35), Color(1.0, 0.68, 0.42), 0.8, 0.55],
	[8.5, Color(0.32, 0.48, 0.72), Color(0.68, 0.74, 0.80), Color(1.0, 0.97, 0.90), 1.35, 0.9],
	[17.0, Color(0.32, 0.48, 0.72), Color(0.68, 0.74, 0.80), Color(1.0, 0.97, 0.90), 1.35, 0.9],
	[18.5, Color(0.34, 0.22, 0.48), Color(0.95, 0.50, 0.40), Color(1.0, 0.55, 0.45), 0.6, 0.5],
	[20.0, Color(0.02, 0.03, 0.08), Color(0.06, 0.08, 0.16), Color(0.55, 0.65, 1.0), 0.25, 0.25],
	[24.0, Color(0.02, 0.03, 0.08), Color(0.06, 0.08, 0.16), Color(0.55, 0.65, 1.0), 0.25, 0.25],
]

@export var start_hour := 8.0

var hour := 8.0
var _sun: DirectionalLight3D
var _env: Environment
var _curfew_timer := 0.0
var _last_hour := -1


func _ready() -> void:
	hour = start_hour


func _process(delta: float) -> void:
	hour = fmod(hour + delta * 24.0 / DAY_SECONDS, 24.0)
	if int(hour) != _last_hour:
		_last_hour = int(hour)
		hour_changed.emit(_last_hour)
	_tick_curfew(delta)
	if not is_instance_valid(_sun) or _env == null:
		_find_scene_nodes()
	if is_instance_valid(_sun):
		_apply()


func is_night() -> bool:
	return hour >= 20.0 or hour < 5.0


func is_curfew() -> bool:
	return hour >= CURFEW_START or hour < CURFEW_END


func police_sight(base: float) -> float:
	return minf(base, NIGHT_SIGHT) if is_night() else base


func clock_text() -> String:
	return "%02d:%02d" % [int(hour), int(fmod(hour, 1.0) * 60.0)]


func _tick_curfew(delta: float) -> void:
	if not is_curfew():
		_curfew_timer = 0.0
		return
	_curfew_timer += delta
	if _curfew_timer >= CURFEW_STAR_SECONDS:
		_curfew_timer = 0.0
		WantedSystem.raise()


func _apply() -> void:
	var angle := (hour - 6.0) / 24.0 * TAU
	if hour < 6.0 or hour >= 18.0:
		angle -= PI
	_sun.rotation = Vector3(-angle, deg_to_rad(-40.0), 0.0)

	var i := 0
	while KEYS[i + 1][0] <= hour:
		i += 1
	var a: Array = KEYS[i]
	var b: Array = KEYS[i + 1]
	var t: float = (hour - a[0]) / (b[0] - a[0])
	_sun.light_color = (a[3] as Color).lerp(b[3], t)
	_sun.light_energy = lerpf(a[4], b[4], t)
	_env.ambient_light_energy = lerpf(a[5], b[5], t)
	var horizon: Color = (a[2] as Color).lerp(b[2], t)
	_env.fog_light_color = horizon
	var sky: ProceduralSkyMaterial = _env.sky.sky_material as ProceduralSkyMaterial if _env.sky != null else null
	if sky != null:
		sky.sky_top_color = (a[1] as Color).lerp(b[1], t)
		sky.sky_horizon_color = horizon
		sky.ground_horizon_color = horizon


func _find_scene_nodes() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var lights := scene.find_children("*", "DirectionalLight3D", true, false)
	_sun = lights[0] if not lights.is_empty() else null
	var envs := scene.find_children("*", "WorldEnvironment", true, false)
	_env = (envs[0] as WorldEnvironment).environment if not envs.is_empty() else null
