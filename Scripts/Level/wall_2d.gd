@tool
class_name Wall2D
extends Terrain2D
## Rectangular wall. Set `size`, then move and rotate the node to place it.
## For other shapes, use Terrain2D and draw the polygon.

@export var size := Vector2(240, 30):
	set(value):
		size = value.max(Vector2.ONE)
		polygon = _centered_rectangle(size)


func _init() -> void:
	super()
	polygon = _centered_rectangle(size)


static func _centered_rectangle(rect_size: Vector2) -> PackedVector2Array:
	var half := rect_size / 2.0
	return PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
