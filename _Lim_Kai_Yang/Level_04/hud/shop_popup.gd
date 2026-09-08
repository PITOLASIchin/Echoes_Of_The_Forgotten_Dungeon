extends Control

@onready var item_icon: TextureRect = $Panel/ItemIcon
@onready var item_name_label: Label = $Panel/ItemName
@onready var item_cost_label: Label = $Panel/ItemCost
@onready var hint_label: Label = $Panel/HintLabel

func _ready() -> void:
	visible = false

func open(shown_name: String, cost: int, icon: Texture2D) -> void:
	item_name_label.text = shown_name
	item_cost_label.text = "%d Coin" % cost
	if icon != null:
		item_icon.texture = icon
	hint_label.text = "Press E to Buy"
	visible = true

func close() -> void:
	visible = false

func show_not_enough_coins() -> void:
	hint_label.text = "Not Enough Coin!"

func show_purchased() -> void:
	hint_label.text = "Buy Sucessful!"


func _on_resume_button_pressed() -> void:
	pass # Replace with function body.


func _on_main_menu_button_pressed() -> void:
	pass # Replace with function body.


func _on_restart_button_pressed() -> void:
	pass # Replace with function body.
