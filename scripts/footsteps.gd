extends Node
## Attach as a child of the player CharacterBody3D.
## Plays footstep sounds at walk/run cadence. Detects surface under the player
## with a short raycast: concrete/road = hard clip, grass/ground = soft thud.
## Drop AudioStreamOGGVorbis / AudioStreamWAV resources into the exports,
## or leave empty — the node is silent but functional without them.

@export var road_steps: Array[AudioStream] = []
@export var grass_steps: Array[AudioStream] = []

## Seconds between steps at walk speed; run halves it.
const WALK_INTERVAL := 0.44
const RUN_INTERVAL := 0.24

var _player: CharacterBody3D
var _audio: AudioStreamPlayer3D
var _timer := 0.0
var _on_grass := false


func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	_audio = AudioStreamPlayer3D.new()
	_audio.bus = "SFX"
	_audio.max_distance = 14.0
	_audio.unit_size = 3.0
	_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	add_child(_audio)


func _physics_process(delta: float) -> void:
	if _player == null or not _player.is_on_floor():
		_timer = 0.0
		return

	var flat := Vector2(_player.velocity.x, _player.velocity.z).length()
	if flat < 0.5:
		_timer = 0.0
		return

	var running := flat > 6.0
	var interval := RUN_INTERVAL if running else WALK_INTERVAL
	_timer -= delta
	if _timer > 0.0:
		return

	_timer = interval
	_detect_surface()
	_play_step()


func _detect_surface() -> void:
	var from := _player.global_position + Vector3.UP * 0.1
	var to := from + Vector3.DOWN * 0.6
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [_player.get_rid()]
	var result := _player.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var col: Object = result.get("collider")
	# Simple heuristic: objects in "ground" or "grass" group = soft surface.
	_on_grass = col != null and (col.is_in_group("grass") or col.is_in_group("ground"))


func _play_step() -> void:
	var pool := grass_steps if _on_grass else road_steps
	if pool.is_empty():
		return
	_audio.stream = pool[randi() % pool.size()]
	_audio.pitch_scale = randf_range(0.9, 1.1)
	_audio.volume_db = randf_range(-3.0, 0.0)
	_audio.play()
