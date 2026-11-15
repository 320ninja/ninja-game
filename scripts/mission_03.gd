extends Mission
## Mission 3, "Taxi Job": pick up a passenger and drop them at New Road
## before the timer runs out. Two-stage mission: Pickup then Dropoff.
##
## Scene layout (see world.tscn):
##   Mission03
##     Giver    MissionTrigger  yellow – walk in to accept the job
##     Pickup   MissionTrigger  orange – where the passenger is waiting
##     Dropoff  MissionTrigger  green  – New Road drop-off point

const PICKUP_COLOUR  := Color(1.0, 0.55, 0.1)   # orange
const DROPOFF_COLOUR := Color(0.3, 1.0, 0.45)   # green

@onready var pickup:  MissionTrigger = $Pickup
@onready var dropoff: MissionTrigger = $Dropoff


func _ready() -> void:
	super()
	pickup.player_entered.connect(_on_pickup_entered)
	dropoff.player_entered.connect(_on_dropoff_entered)
	pickup.set_active(false)
	dropoff.set_active(false)


func _on_mission_started() -> void:
	pickup.set_active(true)
	dropoff.set_active(false)
	if pickup.has_player():
		_on_pickup_entered()


func _on_mission_ended(_success: bool) -> void:
	pickup.set_active(false)
	dropoff.set_active(false)


func _on_pickup_entered() -> void:
	pickup.set_active(false)
	dropoff.set_active(true)
	_hud_call("show_dialogue", ["Passenger", "New Road, please — and hurry!"])
	if dropoff.has_player():
		_on_dropoff_entered()


func _on_dropoff_entered() -> void:
	complete()
