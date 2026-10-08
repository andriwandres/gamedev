@tool
class_name MudBurst2D
extends Node2D
## Releases a blob manually with release(), or on a schedule when autostart is on.
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

## Circle radius, in particle spacings. Particles are packed hexagonally, so
## the blob is as round as its particle count allows: 1 gives 7 particles,
## 2 gives 19.
@export_range(0.0, 10.0, 0.1) var radius := 2.0:
	set(value):
		radius = maxf(value, 0.0)
		queue_redraw()

## Fluid to release into. Leave empty to use the fluid of the level it is in.
@export var fluid: MudFluid2D

@export_group("Timing")
## Start the release schedule when the level loads. Turn off for cursor bursts.
@export var autostart := true
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
	if not Engine.is_editor_hint() and autostart:
		_run_schedule()


func release() -> void:
	var target := _find_fluid()
	if target == null:
		push_warning("%s has no fluid to release into. Is it inside a Level2D?" % name)
		return
	var velocity := target.global_transform.basis_xform_inv(global_transform.basis_xform(launch_velocity))
	var points := PackedVector2Array()
	var velocities := PackedVector2Array()
	for offset in get_particle_offsets():
		points.append(target.to_local(to_global(offset)))
		velocities.append(velocity)
	target.spawn_particles(points, velocities)
	released.emit(points.size())


## Particle spawn positions, local to this node and centered on it.
func get_particle_offsets() -> PackedVector2Array:
	var spacing := 2.0 * MudFluid2D.particle_radius()
	var offsets := PackedVector2Array()
	match shape:
		BlobShape.RECTANGLE:
			var center := Vector2(grid - Vector2i.ONE) / 2.0
			for y in grid.y:
				for x in grid.x:
					offsets.append((Vector2(x, y) - center) * spacing)
		BlobShape.CIRCLE:
			offsets = _hexagonal_disc(radius * spacing, spacing)
	return offsets


## Points `spacing` apart in a hexagonal grid centered on the origin, within
## `disc_radius` of it.
static func _hexagonal_disc(disc_radius: float, spacing: float) -> PackedVector2Array:
	const ROW_HEIGHT := sqrt(3.0) / 2.0
	# Tolerance, so a radius of exactly n spacings includes ring n.
	var limit := disc_radius + spacing * 0.01
	var points := PackedVector2Array()
	var rows := floori(limit / (spacing * ROW_HEIGHT))
	for row in range(-rows, rows + 1):
		var y := row * spacing * ROW_HEIGHT
		var shift := 0.5 * spacing if row % 2 != 0 else 0.0
		var columns := ceili(limit / spacing) + 1
		for column in range(-columns, columns + 1):
			var point := Vector2(column * spacing + shift, y)
			if point.length() <= limit:
				points.append(point)
	return points


func _run_schedule() -> void:
	await get_tree().create_timer(delay, false).timeout
	release()
	for i in repeat_count:
		await get_tree().create_timer(repeat_interval, false).timeout
		release()


func _find_fluid() -> MudFluid2D:
	if fluid:
		return fluid
	var level := Level2D.find_level(self)
	return level.fluid if level != null else null


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var preview_color := Color(0.55, 0.35, 0.15, 0.6)
	for offset in get_particle_offsets():
		draw_circle(offset, MudFluid2D.particle_radius(), preview_color)
	if launch_velocity != Vector2.ZERO:
		# Arrow shows roughly where the blob travels in the first half second.
		draw_line(Vector2.ZERO, launch_velocity * 0.5, Color.ORANGE, 4.0)
