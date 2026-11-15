extends Mission
## Mission 1, "First Job": take a package from the shopkeeper to the tea shop
## in Thamel before the clock runs out.
##
## Scene layout (see world.tscn):
##   Mission01 (this script)
##     Giver     MissionTrigger   where the job is handed out, yellow marker
##     NPC       character model  the person giving the job
##     Delivery  MissionTrigger   drop-off point, hidden until the job starts

@onready var delivery: MissionTrigger = $Delivery


func _ready() -> void:
	super()
	delivery.player_entered.connect(_on_delivery_entered)
	delivery.set_active(false)
	_setup_npc()


func _on_mission_started() -> void:
	delivery.set_active(true)
	# Already standing on the drop-off (unlikely, but possible if a level
	# designer moves things around) - count it.
	if delivery.has_player():
		complete()


func _on_mission_ended(_success: bool) -> void:
	delivery.set_active(false)


func _on_delivery_entered() -> void:
	complete()


## Plays the idle loop and gives the shopkeeper a different look from the player.
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
		shirt.albedo_color = Color(0.72, 0.22, 0.18)  # red shopkeeper's kurta
		shirt.roughness = 0.85
		mesh.set_surface_override_material(0, shirt)
