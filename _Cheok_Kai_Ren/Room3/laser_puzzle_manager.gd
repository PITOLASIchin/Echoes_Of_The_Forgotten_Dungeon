extends Node

@export var laser_levers: Node

@export var laser1: Node
@export var laser2: Node
@export var laser3: Node
@export var laser4: Node
@export var laser5: Node
@export var laser6: Node
@export var laser7: Node
@export var laser8: Node

@export var final_gate: Node


func _ready() -> void:
	connect_levers()
	reset_puzzle()


func connect_levers() -> void:
	if laser_levers == null:
		push_error("LaserPuzzleManager: laser_levers is not assigned.")
		return

	for lever: Node in laser_levers.get_children():
		if not lever.has_signal("activated"):
			continue

		if not lever.activated.is_connected(_on_lever_activated):
			lever.activated.connect(_on_lever_activated)


func _on_lever_activated(lever_id: int, is_on: bool) -> void:
	match lever_id:
		4:
			apply_lever_4(is_on)

		2:
			apply_lever_2(is_on)

		1:
			apply_lever_1(is_on)

		3:
			apply_lever_3(is_on)

		5:
			apply_lever_5(is_on)


# --------------------------------------------------
# LEVER LOGIC
# true  = laser ON  = RED   = blocking
# false = laser OFF = GREEN = safe
# --------------------------------------------------

func apply_lever_4(is_on: bool) -> void:
	# Lever 4:
	# ON  -> Laser 7 OFF, Laser 8 OFF
	# OFF -> Laser 7 ON,  Laser 8 ON
	set_laser_group(laser7, not is_on)
	set_laser_group(laser8, not is_on)

	print("Lever 4 toggled: Laser 7 and Laser 8 updated.")


func apply_lever_2(is_on: bool) -> void:
	# Lever 2:
	# ON  -> Laser 6 OFF
	# OFF -> Laser 6 ON
	set_laser_group(laser6, not is_on)

	print("Lever 2 toggled: Laser 6 updated.")


func apply_lever_1(is_on: bool) -> void:
	# Lever 1:
	# ON  -> Laser 4 OFF, Laser 5 OFF, Laser 6/7/8 ON
	# OFF -> Laser 4 ON,  Laser 5 ON,  Laser 6/7/8 OFF
	set_laser_group(laser4, not is_on)
	set_laser_group(laser5, not is_on)

	set_laser_group(laser6, is_on)
	set_laser_group(laser7, is_on)
	set_laser_group(laser8, is_on)

	print("Lever 1 toggled: Lasers 4, 5, 6, 7, 8 updated.")


func apply_lever_3(is_on: bool) -> void:
	# Lever 3:
	# ON  -> Laser 2 OFF, Laser 3 OFF, Laser 4 ON, Laser 5 ON
	# OFF -> Laser 2 ON,  Laser 3 ON,  Laser 4 OFF, Laser 5 OFF
	set_laser_group(laser2, not is_on)
	set_laser_group(laser3, not is_on)

	set_laser_group(laser4, is_on)
	set_laser_group(laser5, is_on)

	print("Lever 3 toggled: Lasers 2, 3, 4, 5 updated.")


func apply_lever_5(is_on: bool) -> void:
	# Lever 5:
	# ON  -> Laser 1 OFF, Laser 2 ON, Laser 3 ON
	# OFF -> Laser 1 ON,  Laser 2 OFF, Laser 3 OFF
	set_laser_group(laser1, not is_on)
	set_laser_group(laser2, is_on)
	set_laser_group(laser3, is_on)

	# Optional final gate behavior:
	# If you want the final gate to open only when Lever 5 is ON:
	if final_gate != null and final_gate.has_method("set_activated"):
		final_gate.set_activated(is_on)

	print("Lever 5 toggled: Lasers 1, 2, 3 updated.")


func reset_puzzle() -> void:
	# Reset all levers back to OFF state
	if laser_levers != null:
		for lever: Node in laser_levers.get_children():
			if lever.has_method("reset_lever"):
				lever.reset_lever()

	# Initial laser setup:
	# Start everything RED / active / blocking
	set_laser_group(laser1, true)
	set_laser_group(laser2, true)
	set_laser_group(laser3, true)
	set_laser_group(laser4, true)
	set_laser_group(laser5, true)
	set_laser_group(laser6, true)
	set_laser_group(laser7, true)
	set_laser_group(laser8, true)

	# Optional gate reset
	if final_gate != null and final_gate.has_method("set_activated"):
		final_gate.set_activated(false)

	print("Laser puzzle reset.")


func set_laser_group(target: Node, active: bool) -> void:
	if target == null:
		return

	_apply_activation_recursive(target, active)


func _apply_activation_recursive(node: Node, active: bool) -> void:
	if node.has_method("set_activated"):
		node.set_activated(active)

	for child: Node in node.get_children():
		_apply_activation_recursive(child, active)
