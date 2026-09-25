@tool
class_name MudBurst2D
extends Node2D
## Releases a single blob of mud after `delay`, optionally repeating.
## The dots in the editor show exactly where the particles will spawn.

signal released(particle_count: int)

enum BlobShape { RECTANGLE, CIRCLE }

@export var shape := BlobShape.RECTANGLE:
	set(value):
		shape = value
		queue_redraw()

## Rectangle size, in particles.
@export var grid := Vector2i(6, 4):
	set(value):
		grid = value.max(Vector2i.ONE)
		queue_redraw()

## Circle radius, in particles.
@export var radius := 2:
	set(value):
		radius = maxi(value, 0)
		queue_redraw()

@export_group("Timing")
## Seconds after the level starts before the first release.
@export var delay := 0.0
## Extra releases after the first one.
@export var repeat_count := 0
## Seconds between releases.
@export var repeat_interval := 2.0

@export_group("Motion")
## Initial velocity in 2D units per second, relative to the burst's rotation.
@export var launch_velocity := Vector2.ZERO:
	set(value):
		launch_velocity = value
		queue_redraw()


func _ready() -> void:
	if not Engine.is_editor_hint():
		_run_schedule()


func release() -> void:
	var fluid := _find_fluid()
	if fluid == null:
		push_warning("%s has no fluid to release into. Is it inside a Level2D?" % name)
		return
	var velocity := fluid.global_transform.basis_xform_inv(global_transform.basis_xform(launch_velocity))
	var points := PackedVector2Array()
	var velocities := PackedVector2Array()
	for offset in get_particle_offsets():
		points.append(fluid.to_local(to_global(offset)))
		velocities.append(velocity)
	fluid.add_points_and_velocities(points, velocities)
	released.emit(points.size())


## Particle spawn positions, local to this node and centered on it.
func get_particle_offsets() -> PackedVector2Array:
	var spacing := 2.0 * _particle_radius()
	var offsets := PackedVector2Array()
	match shape:
		BlobShape.RECTANGLE:
			var center := Vector2(grid - Vector2i.ONE) / 2.0
			for y in grid.y:
				for x in grid.x:
					offsets.append((Vector2(x, y) - center) * spacing)
		BlobShape.CIRCLE:
			for y in range(-radius, radius + 1):
				for x in range(-radius, radius + 1):
					if Vector2(x, y).length() <= radius:
						offsets.append(Vector2(x, y) * spacing)
	return offsets


func _run_schedule() -> void:
	await get_tree().create_timer(delay, false).timeout
	release()
	for i in repeat_count:
		await get_tree().create_timer(repeat_interval, false).timeout
		release()


func _find_fluid() -> Fluid2D:
	var level := Level2D.find_level(self)
	return level.fluid if level != null else null


func _particle_radius() -> float:
	return float(ProjectSettings.get_setting("physics/rapier/fluid/fluid_particle_radius_2d", 20.0))


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var preview_color := Color(0.55, 0.35, 0.15, 0.6)
	for offset in get_particle_offsets():
		draw_circle(offset, _particle_radius(), preview_color)
	if launch_velocity != Vector2.ZERO:
		# Arrow shows roughly where the blob travels in the first half second.
		draw_line(Vector2.ZERO, launch_velocity * 0.5, Color.ORANGE, 4.0)
