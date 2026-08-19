extends StaticBody2D


# ==========================
# SETTINGS
# ==========================

@export var active_on_ready: bool = true

@export var damage: int = 1
@export var knockback_force: float = 120.0


# ==========================
# AUTOMATIC SPIKES
# ==========================

# OFF = normal lever/crystal spikes
# ON = automatically goes up and down
@export var automatic: bool = false

# How long spikes stay up
@export var active_time: float = 2.0

# How long spikes stay down
@export var inactive_time: float = 2.0


# ==========================
# NODE REFERENCES
# ==========================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var collision: CollisionShape2D = (
	$CollisionShape2D
)

@onready var damage_area: DoDamage = $do_damage


# ==========================
# VARIABLES
# ==========================

var active: bool = false

var automatic_timer: Timer


# ==========================
# READY
# ==========================

func _ready() -> void:
	# Pass spike damage settings into DoDamage.
	damage_area.damage = damage

	# If your DoDamage script has knockback support.
	if "knockback_force" in damage_area:
		damage_area.knockback_force = knockback_force

	# Set initial spike state.
	set_spikes(active_on_ready)

	# Only create/start the timer when
	# automatic mode is enabled.
	if automatic:
		setup_automatic_timer()


# ==========================
# SPIKES
# ==========================

func set_spikes(value: bool) -> void:
	active = value

	collision.set_deferred(
		"disabled",
		not active
	)

	if active:
		damage_area.activate()
		sprite.play("up")
	else:
		damage_area.deactivate()
		sprite.play("down")


# ==========================
# AUTOMATIC SPIKES
# ==========================

func setup_automatic_timer() -> void:
	automatic_timer = Timer.new()

	automatic_timer.one_shot = true

	add_child(automatic_timer)

	automatic_timer.timeout.connect(
		_on_automatic_timer_timeout
	)

	start_automatic_timer()


func start_automatic_timer() -> void:
	if not automatic:
		return

	if automatic_timer == null:
		return

	if active:
		automatic_timer.start(
			active_time
		)
	else:
		automatic_timer.start(
			inactive_time
		)


func _on_automatic_timer_timeout() -> void:
	if not automatic:
		return

	# Switch:
	# UP -> DOWN
	# DOWN -> UP
	set_spikes(
		not active
	)

	start_automatic_timer()


# ==========================
# LEVER
# ==========================

func _on_lever_toggled(
	lever_active: bool
) -> void:
	# Ignore lever when this spike
	# is using automatic mode.
	if automatic:
		return

	# Lever ON = spikes DOWN
	set_spikes(
		not lever_active
	)


# ==========================
# CRYSTAL
# ==========================

func set_activated(
	crystal_active: bool
) -> void:
	# Ignore crystal when this spike
	# is using automatic mode.
	if automatic:
		automatic = false

	if crystal_active:
		deactivate()
	else:
		activate()


func activate() -> void:
	set_spikes(true)


func deactivate() -> void:
	set_spikes(false)
