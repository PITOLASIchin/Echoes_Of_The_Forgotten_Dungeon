extends Area2D

@export var gate: Node2D

var collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if collected:
		return

	if body.name != "knight1":
		return

	collect_key()


func collect_key() -> void:
	collected = true

	if gate != null:
		if gate.has_method("open"):
			gate.open()
		else:
			push_warning(
				"Assigned gate does not have an open() function."
			)
	else:
		push_warning(
			"No gate assigned to this key."
		)

	queue_free()
