class_name TakeDamage
extends Area2D

@onready var owner_entity: Node = get_parent()

func receive_damage(amount: int) -> void:
	if not is_instance_valid(owner_entity):
		return

	if owner_entity.has_method("take_damage"):
		owner_entity.take_damage(amount)
