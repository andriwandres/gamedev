class_name MudFluid2D
extends Fluid2D
## Fluid2D that remembers where each particle was spawned. That spawn position
## is the particle's "material coordinate": the renderer samples the mud texture
## there, so the texture travels, stretches and tears with the mud.
##
## Spawn and remove particles through spawn_particles() / remove_particles() so
## the coordinates stay in step with `points`. Changes made behind its back
## (the native methods, `lifetime`) are reconciled on a best-effort basis.

const PARTICLE_RADIUS_SETTING := "physics/rapier/fluid/fluid_particle_radius_2d"
const DEFAULT_PARTICLE_RADIUS := 20.0

var _material_coords := PackedVector2Array()
## Indices queued for removal. They refer to `points` as it is until Rapier's
## next step, which is when it actually removes them.
var _pending_removals := {}


## Radius of a single particle in 2D units, as configured for Rapier.
static func particle_radius() -> float:
	return float(ProjectSettings.get_setting(PARTICLE_RADIUS_SETTING, DEFAULT_PARTICLE_RADIUS))


func spawn_particles(new_points: PackedVector2Array, velocities: PackedVector2Array) -> void:
	_sync_material_coords()
	add_points_and_velocities(new_points, velocities)
	_material_coords.append_array(new_points)


func remove_particles(indices: PackedInt32Array) -> void:
	_sync_material_coords()
	delete_points(indices)
	for index in indices:
		if index >= 0 and index < _material_coords.size():
			_pending_removals[index] = true


## Material coordinate of every particle, in the same order as `points`.
func get_material_coords() -> PackedVector2Array:
	_sync_material_coords()
	return _material_coords


func _sync_material_coords() -> void:
	var current_points := points
	var count := current_points.size()
	# Untracked spawns: use where the particle is now as its material coordinate.
	for i in range(_material_coords.size(), count):
		_material_coords.append(current_points[i])
	if not _pending_removals.is_empty() and count <= _material_coords.size() - _pending_removals.size():
		_apply_pending_removals()
	# Untracked removals (e.g. lifetime): we can't know which ones, drop the tail.
	if _pending_removals.is_empty() and count < _material_coords.size():
		_material_coords.resize(count)


func _apply_pending_removals() -> void:
	# Rapier removes particles without reordering the rest, so mirror that.
	var removed: Array = _pending_removals.keys()
	removed.sort()
	removed.reverse()
	for index: int in removed:
		_material_coords.remove_at(index)
	_pending_removals.clear()
