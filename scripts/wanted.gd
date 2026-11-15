extends Node
## Autoload "WantedSystem". How hard the police are looking for the player.
##
## Level 0 is clean, 1-5 are stars. Officers call report_seen() every time they
## have eyes on the player; while nobody is looking, a cooldown runs and each
## time it reaches zero one star drops. Getting spotted again resets it.
##
## Tuning lives under "police" in ktmmap.json so it can change without code.

signal wanted_changed(level: int)
## The player was caught. Level is already back to 0 when this fires.
signal busted(fine: int)

const CONFIG_PATH := "res://ktmmap.json"
const MAX_LEVEL := 5
## How long a sighting counts as "currently seen" (officers check a few times
## a second, not every frame).
const SEEN_GRACE := 0.5

var level := 0
## Seconds left before one star drops. Only counts down while unseen.
var cooldown_left := 0.0

## Seconds unseen to lose a star = cooldown_base + cooldown_per_star * level.
var cooldown_base := 10.0
var cooldown_per_star := 4.0
var bust_fine := 500

var _since_seen := INF


func _ready() -> void:
	_load_config()


func _process(delta: float) -> void:
	if level == 0:
		return
	_since_seen += delta
	if is_seen():
		cooldown_left = _cooldown_for(level)
		return
	cooldown_left -= delta
	if cooldown_left <= 0.0:
		set_level(level - 1)


## True while some officer has had eyes on the player in the last moment.
func is_seen() -> bool:
	return _since_seen < SEEN_GRACE


## 0..1, how far the current star has cooled off. For the HUD.
func cooldown_ratio() -> float:
	if level == 0:
		return 0.0
	return clampf(cooldown_left / _cooldown_for(level), 0.0, 1.0)


func set_level(new_level: int) -> void:
	new_level = clampi(new_level, 0, MAX_LEVEL)
	if new_level == level:
		return
	level = new_level
	cooldown_left = _cooldown_for(level)
	wanted_changed.emit(level)


## Raise by `amount` stars. Never lowers.
func raise(amount := 1) -> void:
	set_level(level + amount)


## Raise to at least `minimum` stars. Never lowers.
func raise_to(minimum: int) -> void:
	if minimum > level:
		set_level(minimum)


func clear() -> void:
	set_level(0)


## Called by officers while they can see the player.
func report_seen() -> void:
	_since_seen = 0.0


## Caught: pay the fine (whatever you have, up to bust_fine) and go clean.
func bust() -> void:
	if level == 0:
		return
	var fine := mini(bust_fine, Wallet.money)
	if fine > 0:
		Wallet.spend(fine)
	_since_seen = INF
	set_level(0)
	busted.emit(fine)


func _cooldown_for(stars: int) -> float:
	return cooldown_base + cooldown_per_star * stars


func _load_config() -> void:
	var police := load_police_config()
	cooldown_base = float(police.get("cooldown_base", cooldown_base))
	cooldown_per_star = float(police.get("cooldown_per_star", cooldown_per_star))
	bust_fine = int(police.get("bust_fine", bust_fine))


## The "police" block of ktmmap.json, or {} if missing. Shared with the
## officers and the spawner so all police tuning sits in one place.
static func load_police_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if data is Dictionary and data.get("police") is Dictionary:
		return data["police"]
	return {}
