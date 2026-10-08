@tool
class_name Zone2D
extends Node2D
## A rectangular area of a level, centered on the node. Move, rotate and
## resize it like any node; `size` sets the rectangle before scaling.

@export var size := Vector2(400, 200):
	set(value):
		size = value.max(Vector2.ONE)
		queue_redraw()


func get_local_rect() -> Rect2:
	return Rect2(-size / 2.0, size)


## What this zone covers, in global coordinates. Used for the level bounds.
func get_global_bounds() -> Rect2:
	return global_transform * get_local_rect()


func contains_global_point(global_point: Vector2) -> bool:
	return get_local_rect().has_point(to_local(global_point))


## The point inside the zone closest to `global_point`.
func clamp_global_point(global_point: Vector2) -> Vector2:
	var rect := get_local_rect()
	return to_global(to_local(global_point).clamp(rect.position, rect.end))
