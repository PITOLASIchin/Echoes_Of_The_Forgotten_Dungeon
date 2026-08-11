class_name DoDamage
extends Area2D

#Default damage value
@export var damage: int = 1

#Able to do repeated damage
@export var repeat_damage: bool = false

# Time between repeated hits
@export var damage_interval: float = 1.0

@onready var owner_entity: Node = get_parent()

var active: bool = false

var already_hit: Array[TakeDamage] = []

var target_cooldowns: Dictionary = {}

func _ready() -> void:
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if not area_exited.is_connected(_on_area_exited):
		area_exited.connect(_on_area_exited)

	deactivate()

func _physics_process(delta: float) -> void:
	if not active:
		return

	if not repeat_damage:
		return

	var targets: Array = target_cooldowns.keys()

	for target in targets:
		if not is_instance_valid(target):
			target_cooldowns.erase(target)
			continue

		# Remove targets that are no longer overlapping.
		if not overlaps_area(target):
			target_cooldowns.erase(target)
			continue

		target_cooldowns[target] -= delta

		if target_cooldowns[target] <= 0.0:
			damage_target(target)
			target_cooldowns[target] = damage_interval

func _on_area_entered(area: Area2D) -> void:
	if not active:
		return

	if not area is TakeDamage:
		return

	var target := area as TakeDamage

	if is_own_take_damage_area(target):
		return

	if repeat_damage:
		# Damage immediately when entering.
		damage_target(target)

		# Start this target's individual cooldown.
		target_cooldowns[target] = damage_interval
	else:
		damage_target_once(target)


func _on_area_exited(area: Area2D) -> void:
	if area is TakeDamage:
		var target := area as TakeDamage

		target_cooldowns.erase(target)

func damage_target_once(target: TakeDamage) -> void:
	if not is_instance_valid(target):
		return

	if is_own_take_damage_area(target):
		return

	if target in already_hit:
		return

	already_hit.append(target)
	damage_target(target)

func damage_target(target: TakeDamage) -> void:
	if not is_instance_valid(target):
		return

	if is_own_take_damage_area(target):
		return

	target.receive_damage(damage)

func damage_current_overlaps() -> void:
	if not active:
		return

	for area in get_overlapping_areas():
		if not area is TakeDamage:
			continue

		var target := area as TakeDamage

		if is_own_take_damage_area(target):
			continue

		if repeat_damage:
			if target not in target_cooldowns:
				damage_target(target)
				target_cooldowns[target] = damage_interval
		else:
			damage_target_once(target)

func is_own_take_damage_area(target: TakeDamage) -> bool:
	if not is_instance_valid(target):
		return true

	return target.owner_entity == owner_entity

func activate() -> void:
	active = true

	already_hit.clear()
	target_cooldowns.clear()

	set_deferred("monitoring", true)

func deactivate() -> void:
	active = false

	already_hit.clear()
	target_cooldowns.clear()

	set_deferred("monitoring", false)
