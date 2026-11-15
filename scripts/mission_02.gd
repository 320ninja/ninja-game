extends Mission
## Mission 2, "Street Race": race through three checkpoints across Kathmandu
## before the clock runs out. Must be done in a vehicle.
##
## Scene layout (see world.tscn):
##   Mission02
##     Giver       MissionTrigger  where the race starts
##     Check1      MissionTrigger  first checkpoint (blue)
##     Check2      MissionTrigger  second checkpoint (blue)
##     Finish      MissionTrigger  finish line (green)

const CHECKPOINT_COLOUR := Color(0.3, 0.6, 1.0)   # blue
const FINISH_COLOUR     := Color(0.3, 1.0, 0.45)  # green

var _checkpoints: Array[MissionTrigger] = []
var _current := 0


func _ready() -> void:
	super()
	_checkpoints = [
		$Check1 as MissionTrigger,
		$Check2 as MissionTrigger,
		$Finish as MissionTrigger,
	]
	for cp in _checkpoints:
		cp.player_entered.connect(_on_checkpoint_entered.bind(cp))
		cp.set_active(false)


func _on_mission_started() -> void:
	_current = 0
	_activate_next()


func _on_mission_ended(_success: bool) -> void:
	for cp in _checkpoints:
		cp.set_active(false)
	_current = 0


func _on_checkpoint_entered(cp: MissionTrigger) -> void:
	if cp != _checkpoints[_current]:
		return  # hit out of order, ignore
	cp.set_active(false)
	_current += 1
	if _current >= _checkpoints.size():
		complete()
	else:
		_activate_next()
		_hud_call("show_banner",
			["Checkpoint %d / %d" % [_current, _checkpoints.size() - 1],
			CHECKPOINT_COLOUR])


func _activate_next() -> void:
	var cp := _checkpoints[_current]
	cp.set_active(true)
	# If the player is already standing in it (e.g. level placed on top of player), count it.
	if cp.has_player():
		_on_checkpoint_entered(cp)
