extends Node2D


# =========================================================
# BLOODY HELL SCENE
# =========================================================

# We use the exact BloodyHell scene path.
# This means DemonSlimeBoss or other enemies inside
# this Node2D will NOT be counted.

const BLOODY_HELL_SCENE_PATH: String = \
	"res://_Chin_Yee_Sui/enemies/bloodyhell/bloodyhell.tscn"


# =========================================================
# SPIKES
# =========================================================

# Drag spikes4 here in the Inspector.
@export var spike_4: Node

# Drag spikes5 here in the Inspector.
@export var spike_5: Node


# =========================================================
# VARIABLES
# =========================================================

var bloodyhell_remaining: int = 0

var spikes_disabled: bool = false


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	_find_and_connect_bloodyhells()


# =========================================================
# FIND ALL BLOODYHELL CHILDREN
# =========================================================

func _find_and_connect_bloodyhells() -> void:
	bloodyhell_remaining = 0


	for child in get_children():

		# -------------------------------------------------
		# ONLY COUNT BLOODYHELL.TSCN
		# -------------------------------------------------

		if child.scene_file_path != BLOODY_HELL_SCENE_PATH:
			continue


		bloodyhell_remaining += 1


		# -------------------------------------------------
		# CONNECT DEATH SIGNAL
		# -------------------------------------------------

		if child.has_signal("died"):

			if not child.died.is_connected(
				_on_bloodyhell_died
			):

				child.died.connect(
					_on_bloodyhell_died
				)


	print(
		"Red Gate BloodyHells: ",
		bloodyhell_remaining
	)


	# Safety:
	# If there are somehow no BloodyHells,
	# disable the spikes immediately.
	if bloodyhell_remaining <= 0:
		_disable_red_gate_spikes()


# =========================================================
# BLOODYHELL DIED
# =========================================================

func _on_bloodyhell_died() -> void:
	if spikes_disabled:
		return


	bloodyhell_remaining -= 1


	bloodyhell_remaining = maxi(
		bloodyhell_remaining,
		0
	)


	print(
		"BloodyHell killed. Remaining: ",
		bloodyhell_remaining
	)


	# -----------------------------------------------------
	# ALL 4 BLOODYHELLS ARE DEAD
	# -----------------------------------------------------

	if bloodyhell_remaining <= 0:
		_disable_red_gate_spikes()


# =========================================================
# DISABLE SPIKES
# =========================================================

func _disable_red_gate_spikes() -> void:
	if spikes_disabled:
		return


	spikes_disabled = true


	print(
		"All BloodyHells defeated! "
		+ "Turning off Red Gate spikes."
	)


	# -----------------------------------------------------
	# SPIKE 4
	# -----------------------------------------------------

	if is_instance_valid(spike_4):

		if spike_4.has_method("deactivate"):

			spike_4.deactivate()

		else:

			push_warning(
				"spike_4 does not have deactivate()"
			)

	else:

		push_warning(
			"spike_4 is not assigned!"
		)


	# -----------------------------------------------------
	# SPIKE 5
	# -----------------------------------------------------

	if is_instance_valid(spike_5):

		if spike_5.has_method("deactivate"):

			spike_5.deactivate()

		else:

			push_warning(
				"spike_5 does not have deactivate()"
			)

	else:

		push_warning(
			"spike_5 is not assigned!"
		)
