extends Node
## Autoload "Wallet". The player's money for this run.
##
## Local only for now. Once Nakama is in, the server owns the real balance and
## this just mirrors it, so keep every change going through add() / spend().

signal money_changed(amount: int)

const BRANDING_PATH := "res://ktmmap.json"

var money := 0
## Read from branding.json so a rebrand can change it without code.
var currency_symbol := "Rs"


func _ready() -> void:
	_load_currency_symbol()


func add(amount: int) -> void:
	money += amount
	money_changed.emit(money)


## Returns false (and changes nothing) if the player can't afford it.
func spend(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	money_changed.emit(money)
	return true


func format(amount: int) -> String:
	return "%s %d" % [currency_symbol, amount]


func _load_currency_symbol() -> void:
	if not FileAccess.file_exists(BRANDING_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(BRANDING_PATH))
	if data is Dictionary and data.has("currency_symbol"):
		currency_symbol = str(data["currency_symbol"])
