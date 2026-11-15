extends Node
## In-car radio. R key cycles stations. Station name shown in HUD for 2s.
## Drop AudioStream resources into `stations` from the editor, or leave empty
## for silence-only mode (station names still cycle so the HUD works without
## audio assets committed to the repo).
##
## Autoloaded as "Radio" so the car and the HUD can both reach it.

signal station_changed(name: String)

## Fill these in the editor with AudioStreamOGGVorbis / AudioStreamMP3 assets.
## Parallel arrays: stations[i] plays with names[i] shown on the HUD.
@export var streams: Array[AudioStream] = []
@export var names: Array[String] = ["Radio Kathmandu", "Jhapa FM", "City Beats", "Off"]

var current := 0
var playing := false

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	add_child(_player)


func next_station() -> void:
	current = (current + 1) % maxi(names.size(), 1)
	_apply()
	station_changed.emit(_current_name())


func _apply() -> void:
	_player.stop()
	if streams.size() > current and streams[current] != null:
		_player.stream = streams[current]
		_player.play()
		playing = true
	else:
		playing = false


func _current_name() -> String:
	if current < names.size():
		return names[current]
	return ""
