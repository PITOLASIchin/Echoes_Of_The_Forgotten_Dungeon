extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass





func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://_Narvin/main_menu.tscn")


func _on_floor1_pressed() -> void:
	get_tree().change_scene_to_file("res://node_2d.tscn")

func _on_floor2_pressed() -> void:
	get_tree().change_scene_to_file("res://_Goh_Mei_Heng/Level_02/level_2.tscn")
	
func _on_floor3_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/game.tscn")
	
func _on_floor4_pressed() -> void:
	get_tree().change_scene_to_file("res://_Lim_Kai_Yang/Level_04/room_4.tscn")

func _on_floor5_pressed() -> void:
	get_tree().change_scene_to_file("res://_Chin_Yee_Sui/Level_05/Level_05.tscn")
