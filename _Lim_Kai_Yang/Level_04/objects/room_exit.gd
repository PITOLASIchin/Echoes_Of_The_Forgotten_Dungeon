extends Area2D

@export_file("*.tscn") var next_scene_path: String = ""

signal player_entered

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	player_entered.emit()
	if next_scene_path != "":
		get_tree().call_deferred("change_scene_to_file", next_scene_path)
