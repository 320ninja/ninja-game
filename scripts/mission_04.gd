extends Mission
## Mission 4, "Hot Pursuit": rob a shop then reach the safe house before the
## police close in. Two-stage: commit the crime, then escape.
##
## No police AI yet — the tension comes from the tight 60-second escape window.
## When police are added, hook them into _on_mission_started / _on_mission_ended.
##
## Scene layout (see world.tscn):
##   Mission04
##     Giver    MissionTrigger  yellow – take the job
##     RobZone  MissionTrigger  red    – commit the robbery
##     SafeHouse MissionTrigger green  – escape destination

const ROB_COLOUR  := Color(1.0, 0.2, 0.2)   # red
const SAFE_COLOUR := Color(0.3, 1.0, 0.45)  # green

## Seconds on the clock once the robbery is committed.
## Overrides the base time_limit (which starts from job acceptance).
@export var escape_time := 60.0

@onready var rob_zone:  MissionTrigger = $RobZone
@onready var safe_house: MissionTrigger = $SafeHouse

var _escape_phase := false


func _ready() -> void:
	super()
	rob_zone.player_entered.connect(_on_rob_entered)
	safe_house.player_entered.connect(_on_safe_entered)
	rob_zone.set_active(false)
	safe_house.set_active(false)


func _on_mission_started() -> void:
	_escape_phase = false
	rob_zone.set_active(true)
	safe_house.set_active(false)
	if rob_zone.has_player():
		_on_rob_entered()


func _on_mission_ended(_success: bool) -> void:
	rob_zone.set_active(false)
	safe_house.set_active(false)
	_escape_phase = false


func _on_rob_entered() -> void:
	rob_zone.set_active(false)
	safe_house.set_active(true)
	_escape_phase = true
	# Reset the clock to the tighter escape window.
	time_left = escape_time
	_hud_call("set_timer", [time_left])
	_hud_call("show_banner", ["WANTED  ★  Reach the safe house!", Color(1.0, 0.2, 0.2)])
	_hud_call("show_dialogue", ["Police Radio", "All units — robbery at Ason! Suspect on foot!"])
	if safe_house.has_player():
		_on_safe_entered()


func _on_safe_entered() -> void:
	complete()
