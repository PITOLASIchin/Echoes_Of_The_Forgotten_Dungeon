extends CharacterBody2D

@export var push_speed: float = 150.0
@export var push_threshold: float = 30.0
@export var hint_text: String = "Move closer to push it"

@onready var hint_label: Label = $HintLabel
@onready var zone_directions: Dictionary = {
	$PushZoneUp: Vector2.DOWN,
	$PushZoneDown: Vector2.UP,
	$PushZoneLeft: Vector2.RIGHT,
	$PushZoneRight: Vector2.LEFT,
}

var occupants: Dictionary = {}  

func _ready() -> void:
	for zone: Area2D in zone_directions:
		zone.body_entered.connect(_on_zone_entered.bind(zone))
		zone.body_exited.connect(_on_zone_exited.bind(zone))
		occupants[zone] = null
		
	hint_label.text = hint_text
	hint_label.global_position = global_position + Vector2(-40, -40)
	hint_label.hide()

func _on_zone_entered(body: Node2D, zone: Area2D) -> void:
	if body.is_in_group("player"):
		occupants[zone] = body
		_update_hint() 

func _on_zone_exited(body: Node2D, zone: Area2D) -> void:
	if occupants[zone] == body:
		occupants[zone] = null
		_update_hint()
		
func _update_hint() -> void:
	var any_near := false
	for zone in occupants:
		if occupants[zone] != null:
			any_near = true
			break
	hint_label.visible = any_near

func _physics_process(_delta: float) -> void:
	velocity = Vector2.ZERO

	var move_input: Vector2 = Input.get_vector(
		"left", "right", "up", "down"
	)

	if move_input == Vector2.ZERO:
		move_and_slide()
		return

	for zone: Area2D in zone_directions:
		var player: Node2D = occupants[zone]
		if player == null or not is_instance_valid(player):
			continue

		var push_dir: Vector2 = zone_directions[zone]
		if move_input.dot(push_dir) > 0.5:
			velocity = push_dir * push_speed
			break

	move_and_slide()
