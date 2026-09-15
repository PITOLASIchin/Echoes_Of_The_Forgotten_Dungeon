extends Node2D


# ==========================
# NODE REFERENCES
# ==========================

@onready var hud = $Hud/hud
var player: CharacterBody2D


# ==========================
# READY
# ==========================

func _ready() -> void:

	player = get_tree().get_first_node_in_group("player")

	if player == null:
		print("Player not found")
		return


	# ==========================
	# HEALTH
	# ==========================

	if not player.health_changed.is_connected(
		hud.update_health
	):
		player.health_changed.connect(
			hud.update_health
		)


	# ==========================
	# COINS
	# ==========================

	if not player.coins_changed.is_connected(
		hud.update_coins
	):
		player.coins_changed.connect(
			hud.update_coins
		)


	# ==========================
	# POTIONS
	# ==========================

	if not player.potions_changed.is_connected(
		hud.update_potions
	):
		player.potions_changed.connect(
			hud.update_potions
		)


	# ==========================
	# INITIAL HUD VALUES
	# ==========================

	hud.update_health(
		player.current_health,
		player.max_health
	)

	hud.update_coins(
		player.coins
	)

	hud.update_potions(
		player.potions
	)
