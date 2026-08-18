extends StaticBody2D


# ==========================
# SIGNALS
# ==========================

# Simple signal for spikes, lasers, doors, etc.
signal toggled(active: bool)

# Optional signal if you need to know which lever was used.
signal activated(lever_id: int, is_on: bool)


# ==========================
# SETTINGS
# ==========================

@export var lever_id: int = 0

@export var starts_on: bool = false

# If false, the lever can only be turned ON once.
@export var can_toggle_off: bool = true


# ==========================
# NODE REFERENCES
# ==========================

@onready var interaction_area: Area2D = $Area2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Optional interaction prompt.
# If you don't have this node, this will safely be null.
@onready var interaction_prompt: Label = (
	get_node_or_null("InteractionPrompt")
)


# ==========================
# VARIABLES
# ==========================

var player_near: bool = false
var active: bool = false


# ==========================
# READY
# ==========================

func _ready() -> void:
	active = starts_on

	if not interaction_area.body_entered.is_connected(
		_on_body_entered
	):
		interaction_area.body_entered.connect(
			_on_body_entered
		)

	if not interaction_area.body_exited.is_connected(
		_on_body_exited
	):
		interaction_area.body_exited.connect(
			_on_body_exited
		)

	update_visual()

	if interaction_prompt != null:
		interaction_prompt.hide()


# ==========================
# PROCESS
# ==========================

func _process(_delta: float) -> void:
	if not player_near:
		return

	if not Input.is_action_just_pressed("interact"):
		return

	toggle_lever()


# ==========================
# TOGGLE
# ==========================

func toggle_lever() -> void:
	# Prevent turning it off again if this lever
	# should only activate once.
	if active and not can_toggle_off:
		return

	active = not active

	update_visual()

	# Existing systems can use this.
	toggled.emit(active)

	# Systems with multiple lever IDs can use this.
	activated.emit(
		lever_id,
		active
	)


# ==========================
# VISUAL
# ==========================

func update_visual() -> void:
	if sprite == null:
		return

	if active:
		# Supports either "on" or "On".
		if sprite.sprite_frames.has_animation("on"):
			sprite.play("on")

		elif sprite.sprite_frames.has_animation("On"):
			sprite.play("On")

	else:
		if sprite.sprite_frames.has_animation("off"):
			sprite.play("off")

		elif sprite.sprite_frames.has_animation("Off"):
			sprite.play("Off")


# ==========================
# RESET
# ==========================

func reset_lever() -> void:
	active = starts_on

	update_visual()

	if interaction_prompt == null:
		return

	if player_near:
		interaction_prompt.show()
	else:
		interaction_prompt.hide()


# ==========================
# MANUAL STATE
# ==========================

func set_state(value: bool) -> void:
	active = value

	update_visual()


# ==========================
# PLAYER ENTERED
# ==========================

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return

	player_near = true

	if interaction_prompt != null:
		interaction_prompt.show()


# ==========================
# PLAYER EXITED
# ==========================

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return

	player_near = false

	if interaction_prompt != null:
		interaction_prompt.hide()
