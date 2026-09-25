@tool
class_name MudSink2D
extends Node2D
## Removes mud that reaches it and reports the amount to the level.
## By default it stretches across the bottom edge of the level.

signal consumed(amount: int, total: int)

## Zone size in 2D units. The node's position is the zone's top-left corner.
@export var size := Vector2(400, 60):
	set(value):
		size = value.max(Vector2.ONE)
		queue_redraw()

## Stretch across the level's bottom edge automatically.
@export var snap_to_bottom := true

var total_consumed := 0


## Called by the stage (or a standalone level) whenever the level area changes.
func fit_to_river_area(area: Rect2) -> void:
	if not snap_to_bottom:
		return
	size = Vector2(area.size.x, size.y)
	global_position = Vector2(area.position.x, area.end.y - size.y)


func get_global_zone() -> Rect2:
	return global_transform * Rect2(Vector2.ZERO, size)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var level := Level2D.find_level(self)
	if level == null or level.fluid == null:
		return
	var arrived := level.fluid.get_particles_in_aabb(get_global_zone())
	if arrived.is_empty():
		return
	level.fluid.delete_points(arrived)
	total_consumed += arrived.size()
	consumed.emit(arrived.size(), total_consumed)
	level.add_consumed_mud(arrived.size())


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.9, 0.2, 0.2, 0.35))
