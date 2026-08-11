extends Node2D


# ==========================
# NODE REFERENCES
# ==========================

@onready var player: CharacterBody2D = $knight1
@onready var hud: Control = $UI/HUD


# ==========================
# READY
# ==========================

func _ready() -> void:
	if not player.health_changed.is_connected(
		hud.update_health
	):
		player.health_changed.connect(
			hud.update_health
		)

	#if not player.coins_changed.is_connected(
		#hud.update_coins
	#):
		#player.coins_changed.connect(
			#hud.update_coins
		#)

	#if not player.keys_changed.is_connected(
		#hud.update_keys
	#):
		#player.keys_changed.connect(
			#hud.update_keys
		#)

	hud.update_health(
		player.health,
		player.max_health
	)

	#hud.update_coins(player.coins)
	#hud.update_keys(player.keys)
