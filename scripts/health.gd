class_name Health
extends Node

signal health_changed(current: float, max_hp: float)
signal died

@export var max_hp := 100.0
var current_hp := 0.0


func _ready() -> void:
	current_hp = max_hp


func is_dead() -> bool:
	return current_hp <= 0.0


func take_damage(amount: float) -> void:
	if is_dead() or amount <= 0.0:
		return
	current_hp = maxf(current_hp - amount, 0.0)
	health_changed.emit(current_hp, max_hp)
	if is_dead():
		died.emit()


func heal(amount: float) -> void:
	if is_dead() or amount <= 0.0:
		return
	current_hp = minf(current_hp + amount, max_hp)
	health_changed.emit(current_hp, max_hp)


func revive() -> void:
	current_hp = max_hp
	health_changed.emit(current_hp, max_hp)


static func of(node: Object) -> Health:
	if node is Node:
		return node.get_node_or_null("Health") as Health
	return null
