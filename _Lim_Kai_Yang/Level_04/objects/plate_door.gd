extends StaticBody2D
@export var plate_paths: Array[NodePath] = []

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var plates: Array = []

func _ready() -> void:
	if plate_paths.is_empty():
		push_warning("PlateDoor: havent done ")
		return
	for path in plate_paths:
		var plate := get_node(path)
		plates.append(plate)
		plate.state_changed.connect(_on_any_plate_changed)

func _on_any_plate_changed(_pressed: bool) -> void:
	var all_pressed := true
	for plate in plates:
		if not plate.is_pressed:
			all_pressed = false
			break
	_set_open(all_pressed)

func _set_open(open: bool) -> void:
	collision.set_deferred("disabled", open)
	if sprite.hframes >= 2:
		sprite.frame = 1 if open else 0
	else:
		sprite.visible = not open
