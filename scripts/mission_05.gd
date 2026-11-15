extends Mission
## Mission 5, "Bank Heist": cut the power at Nepal Bank, grab the cash from
## the vault, then escape to the Lazimpat safe house before time runs out.

const HEIST_STARS := 4
const ROADBLOCK_POINTS: Array[Vector3] = [
	Vector3(31.5, 0.2, 68.0),
	Vector3(70.5, 0.2, 76.5),
	Vector3(61.5, 0.2, 116.0),
]

@export var cut_time := 5.0
@export var escape_time := 210.0

@onready var power_box: MissionTrigger = $PowerBox
@onready var vault: MissionTrigger = $Vault
@onready var safe_house: MissionTrigger = $SafeHouse
@onready var cash_bag: Node3D = $CashBag

var _cut := 0.0
var _escaping := false
var _roadblock: Array[Node] = []


func _ready() -> void:
	super()
	vault.player_entered.connect(_on_vault_entered)
	safe_house.player_entered.connect(complete)
	WantedSystem.busted.connect(_on_busted)
	_reset()
	_setup_npc()


func _on_mission_started() -> void:
	_reset()
	power_box.set_active(true)
	_spawn_roadblock()


func _on_mission_tick(delta: float) -> void:
	if _escaping:
		time_left = maxf(time_left - delta, 0.0)
		_hud_call("set_timer", [time_left])
		if time_left <= 0.0:
			fail("Out of time")
		return
	if not power_box.visible:
		return
	if power_box.has_player():
		_cut += delta
		_hud_call("show_progress", ["CUT POWER", _cut / cut_time])
		if _cut >= cut_time:
			_on_power_cut()
	elif _cut > 0.0:
		_cut = 0.0
		_hud_call("hide_progress")


func _on_mission_ended(success: bool) -> void:
	_hud_call("hide_progress")
	_reset()
	for officer in _roadblock:
		if is_instance_valid(officer):
			officer.queue_free()
	_roadblock.clear()
	if success:
		WantedSystem.clear()


func _on_power_cut() -> void:
	power_box.set_active(false)
	_hud_call("hide_progress")
	vault.set_active(true)
	cash_bag.visible = true
	_hud_call("show_dialogue", ["Shyam", "Lights out! Get in the vault and grab the bag."])
	if vault.has_player():
		_on_vault_entered()


func _on_vault_entered() -> void:
	if state != State.ACTIVE or not vault.visible:
		return
	vault.set_active(false)
	cash_bag.visible = false
	safe_house.set_active(true)
	_escaping = true
	time_left = escape_time
	_hud_call("set_timer", [time_left])
	WantedSystem.raise_to(HEIST_STARS)
	_hud_call("show_banner", ["Got the cash!  Get to Lazimpat!", Color(1.0, 0.2, 0.2)])
	_hud_call("show_dialogue", ["Police Radio", "Robbery at Nepal Bank, New Road! All units!"])


func _on_busted(_fine: int) -> void:
	if state == State.ACTIVE:
		fail("Busted")


func _reset() -> void:
	_cut = 0.0
	_escaping = false
	power_box.set_active(false)
	vault.set_active(false)
	safe_house.set_active(false)
	cash_bag.visible = false


func _spawn_roadblock() -> void:
	for point in ROADBLOCK_POINTS:
		var officer := PoliceOfficer.new()
		officer.home = point
		officer.walk_speed = 0.0
		officer.position = point
		add_child(officer)
		_roadblock.append(officer)


func _setup_npc() -> void:
	var npc := get_node_or_null("NPC")
	if npc == null:
		return
	var anim: AnimationPlayer = npc.find_child("AnimationPlayer", true, false)
	if anim != null and anim.has_animation("Idle"):
		anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		anim.play("Idle")
	var mesh: MeshInstance3D = npc.find_child("Mannequin", true, false)
	if mesh != null:
		var shirt := StandardMaterial3D.new()
		shirt.albedo_color = Color(0.15, 0.15, 0.18)
		mesh.set_surface_override_material(0, shirt)
