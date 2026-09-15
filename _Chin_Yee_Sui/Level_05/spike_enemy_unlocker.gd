extends Node


# Monsters that must be killed.
@export var enemy_paths: Array[NodePath] = []

# Spikes that should go down after all monsters are gone.
@export var spike_paths: Array[NodePath] = []


var alive_enemies: Array[Node] = []
var unlocked: bool = false


func _ready() -> void:
	if enemy_paths.is_empty():
		push_warning("SpikeEnemyUnlocker: No enemies assigned.")
		return

	if spike_paths.is_empty():
		push_warning("SpikeEnemyUnlocker: No spikes assigned.")
		return

	for enemy_path in enemy_paths:
		var enemy: Node = get_node_or_null(enemy_path)

		if enemy == null:
			push_warning(
				"SpikeEnemyUnlocker: Enemy path not found: %s"
				% enemy_path
			)
			continue

		alive_enemies.append(enemy)

		# Works for your Golem / boss enemies that emit died.
		if enemy.has_signal("died"):
			enemy.connect(
				"died",
				Callable(self, "_on_enemy_defeated").bind(enemy),
				CONNECT_ONE_SHOT
			)

		# Backup: also works for enemies that just queue_free() on death.
		enemy.tree_exited.connect(
			Callable(self, "_on_enemy_defeated").bind(enemy),
			CONNECT_ONE_SHOT
		)


func _on_enemy_defeated(enemy: Node) -> void:
	if unlocked:
		return

	alive_enemies.erase(enemy)

	if alive_enemies.is_empty():
		_lower_spikes()


func _lower_spikes() -> void:
	if unlocked:
		return

	unlocked = true

	for spike_path in spike_paths:
		var spike: Node = get_node_or_null(spike_path)

		if spike == null:
			push_warning(
				"SpikeEnemyUnlocker: Spike path not found: %s"
				% spike_path
			)
			continue

		if spike.has_method("deactivate"):
			spike.deactivate()
		elif spike.has_method("set_spikes"):
			spike.set_spikes(false)
		else:
			push_warning(
				"SpikeEnemyUnlocker: Spike has no deactivate() function: %s"
				% spike.name
			)
