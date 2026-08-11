extends Control


# ==========================
# HEALTH SETTINGS
# ==========================

@export var full_heart_texture: Texture2D
@export var empty_heart_texture: Texture2D


# ==========================
# NODE REFERENCES
# ==========================

@onready var potrait: TextureRect = $Potrait

@onready var hearts: Array[TextureRect] = [
	$Hearts/Heart1,
	$Hearts/Heart2,
	$Hearts/Heart3,
	$Hearts/Heart4,
	$Hearts/Heart5
]

#@onready var coin_count: Label = $CoinCount
#@onready var key_count: Label = $KeyCount


# ==========================
# READY
# ==========================

func _ready() -> void:
	update_health(5, 5)
	#update_coins(0)
	#update_keys(0)


# ==========================
# HEALTH
# ==========================

func update_health(
	current_health: int,
	max_health: int
) -> void:
	for index in range(hearts.size()):
		var heart := hearts[index]

		if index < current_health and index < max_health:
			heart.texture = full_heart_texture
		else:
			heart.texture = empty_heart_texture


# ==========================
# COINS
# ==========================

#func update_coins(amount: int) -> void:
	#coin_count.text = str(amount)


# ==========================
# KEYS
# ==========================

#func update_keys(amount: int) -> void:
	#key_count.text = str(amount)
