extends Mission
## Mission 4, "Hot Pursuit": rob a shop, then reach the safe house.
## The robbery puts the player on 2 stars; hanging around the shop raises it
## to 3. Getting busted fails the mission; the safe house clears the heat.
##
## Scene layout (see world.tscn):
##   Mission04
##     Giver     MissionTrigger  yellow – take the job
##     RobZone   MissionTrigger  red    – commit the robbery
##     SafeHouse MissionTrigger  green  – escape destination

const ROB_STARS := 2
const LINGER_STARS := 3

## Seconds on the clock once the robbery is committed.
@export var escape_time := 60.0
## Stay within linger_radius of the shop this long after the robbery = 3 stars.
@export var linger_time := 8.0
@export var linger_radius := 30.0

@onready var rob_zone:  MissionTrigger = $RobZone
@onready var safe_house: MissionTrigger = $SafeHouse

var _escape_phase := false
var _linger := 0.0


func _ready() -> void:
	super()
	rob_zone.player_entered.connect(_on_rob_entered)
	safe_house.player_entered.connect(_on_safe_entered)
	WantedSystem.busted.connect(_on_busted)
	rob_zone.set_active(false)
	safe_house.set_active(false)


func _on_mission_started() -> void:
	_escape_phase = false
	_linger = 0.0
	rob_zone.set_active(true)
	safe_house.set_active(false)
	if rob_zone.has_player():
		_on_rob_entered()


func _on_mission_tick(delta: float) -> void:
	if not _escape_phase or WantedSystem.level >= LINGER_STARS:
		return
	if _player_distance_to(rob_zone.global_position) > linger_radius:
		return
	_linger += delta
	if _linger >= linger_time:
		WantedSystem.raise_to(LINGER_STARS)
		_hud_call("show_dialogue", ["Police Radio", "Suspect still at Ason! All units respond!"])


func _on_mission_ended(success: bool) -> void:
	rob_zone.set_active(false)
	safe_house.set_active(false)
	_escape_phase = false
	if success:
		WantedSystem.clear()


func _on_rob_entered() -> void:
	rob_zone.set_active(false)
	safe_house.set_active(true)
	_escape_phase = true
	time_left = escape_time
	_hud_call("set_timer", [time_left])
	WantedSystem.raise_to(ROB_STARS)
	_hud_call("show_banner", ["WANTED  Reach the safe house!", Color(1.0, 0.2, 0.2)])
	_hud_call("show_dialogue", ["Police Radio", "All units — robbery at Ason! Suspect on foot!"])
	if safe_house.has_player():
		_on_safe_entered()


func _on_safe_entered() -> void:
	complete()


func _on_busted(_fine: int) -> void:
	if state == State.ACTIVE:
		fail("Busted")


func _player_distance_to(point: Vector3) -> float:
	var game := get_tree().get_first_node_in_group("game")
	if game == null:
		return INF
	return game.get_active().global_position.distance_to(point)
