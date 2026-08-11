extends Control
## Room4 自己的 HUD:血条 + 金币 + 药水数量 + 暂停菜单。
## 暂停这块是从队友 ui.gd 合并进来的, 逻辑不变, 只是换了挂载位置。

@export var full_heart_texture: Texture2D
@export var empty_heart_texture: Texture2D
@export var potion_icon_texture: Texture2D

@onready var hearts: Array[TextureRect] = [
	$Hearts/Heart1,
	$Hearts/Heart2,
	$Hearts/Heart3,
	$Hearts/Heart4,
	$Hearts/Heart5
]

@onready var coin_count: Label = $CoinCount
@onready var potion_display: HBoxContainer = $PotionDisplay
@onready var potion_icon: TextureRect = $PotionDisplay/PotionIcon
@onready var potion_count: Label = $PotionDisplay/PotionCount

@onready var pause_button: TextureButton = $PauseButton
@onready var pause_menu: Control = $PauseMenu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if potion_icon_texture != null:
		potion_icon.texture = potion_icon_texture

	update_health(5, 5)
	update_coins(0)
	update_potions(0)

	pause_menu.hide()
	pause_button.pressed.connect(_on_pause_button_pressed)

func update_health(current_health: int, max_health: int) -> void:
	for index in range(hearts.size()):
		var heart := hearts[index]
		if index < current_health and index < max_health:
			heart.texture = full_heart_texture
		else:
			heart.texture = empty_heart_texture

func update_coins(amount: int) -> void:
	coin_count.text = str(amount)

func update_potions(amount: int) -> void:
	potion_count.text = "x%d" % amount
	potion_display.visible = amount > 0

func _on_pause_button_pressed() -> void:
	if get_tree().paused:
		resume_game()
	else:
		pause_game()

func _on_resume_button_pressed() -> void:
	resume_game()

func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func pause_game() -> void:
	get_tree().paused = true
	pause_button.hide()
	pause_menu.show()

func resume_game() -> void:
	get_tree().paused = false
	pause_menu.hide()
	pause_button.show()
