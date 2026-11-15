class_name Mission
extends Node3D
## Base for every mission. Handles the parts all missions share:
##   waiting at the giver -> intro dialogue -> optional countdown -> pass / fail
##   -> reward into the Wallet -> retry on fail.
##
## A new mission extends this, fills in the exports, and overrides the hooks
## (_on_mission_started / _on_mission_tick / _on_mission_ended) for its own
## goal. Call complete() or fail() when the goal is met or lost.
##
## The giver is a child MissionTrigger called "Giver". Only one mission can be
## running at a time.

signal started
signal completed(reward: int)
signal failed(reason: String)

enum State { WAITING, ACTIVE, COMPLETED, FAILED }

@export var mission_id := "mission"
@export var title := "Mission"
@export var giver_name := ""
@export_multiline var intro_text := ""
## Seconds on the clock. 0 means no time limit.
@export var time_limit := 0.0
@export var reward := 0
## Seconds after failing before the giver comes back for a retry.
@export var retry_delay := 4.0

var state := State.WAITING
var time_left := 0.0

@onready var giver: MissionTrigger = $Giver


func _ready() -> void:
	add_to_group("mission")
	giver.player_entered.connect(_on_giver_entered)
	giver.set_active(true)


func _process(delta: float) -> void:
	if state != State.ACTIVE:
		return
	if time_limit > 0.0:
		time_left = maxf(time_left - delta, 0.0)
		_hud_call("set_timer", [time_left])
		if time_left <= 0.0:
			fail("Out of time")
			return
	_on_mission_tick(delta)


func start() -> void:
	if state == State.ACTIVE or state == State.COMPLETED or _other_mission_running():
		return
	state = State.ACTIVE
	time_left = time_limit
	giver.set_active(false)
	_hud_call("show_dialogue", [giver_name, intro_text])
	if time_limit > 0.0:
		_hud_call("set_timer", [time_left])
	_on_mission_started()
	started.emit()


func complete() -> void:
	if state != State.ACTIVE:
		return
	state = State.COMPLETED
	Wallet.add(reward)
	_hud_call("hide_timer")
	var text := "Mission Complete!"
	if reward > 0:
		text += "  +" + Wallet.format(reward)
	_hud_call("show_banner", [text, Color(0.45, 1.0, 0.5)])
	_on_mission_ended(true)
	completed.emit(reward)


func fail(reason := "") -> void:
	if state != State.ACTIVE:
		return
	state = State.FAILED
	_hud_call("hide_timer")
	var text := "Mission Failed"
	if reason != "":
		text += "\n" + reason
	_hud_call("show_banner", [text, Color(1.0, 0.4, 0.35)])
	_on_mission_ended(false)
	failed.emit(reason)
	await get_tree().create_timer(retry_delay).timeout
	# Don't restart under the player's feet: wait until they step off the giver.
	while _player_near_giver():
		await get_tree().create_timer(0.5).timeout
	if state == State.FAILED:
		state = State.WAITING
		giver.set_active(true)


# --- Hooks for subclasses -------------------------------------------------

## The mission just began: turn on its goal (zones, enemies, items...).
func _on_mission_started() -> void:
	pass


## Every frame while running, for goals that are checked rather than triggered.
func _on_mission_tick(_delta: float) -> void:
	pass


## Passed or failed: clean up anything _on_mission_started turned on.
func _on_mission_ended(_success: bool) -> void:
	pass


# --- Internals ------------------------------------------------------------

func _on_giver_entered() -> void:
	start()


func _other_mission_running() -> bool:
	for mission in get_tree().get_nodes_in_group("mission"):
		if mission != self and mission.state == State.ACTIVE:
			return true
	return false


func _player_near_giver() -> bool:
	var game := get_tree().get_first_node_in_group("game")
	if game == null:
		return false
	var where: Vector3 = game.get_active().global_position
	return where.distance_to(giver.global_position) < giver.radius + 1.0


## The HUD is optional so missions still work in a test scene without one.
func _hud_call(method: String, args: Array = []) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method(method):
		hud.callv(method, args)
