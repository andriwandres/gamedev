@tool
class_name RiverWalls2D
extends StaticBody2D
## Solid walls on the left and right ends of the river area.
##
## River3D pushes its projected area in through `fit_to_river_area`, so the
## walls follow the river size. They sit just outside the area, so they never
## cover visible river.

## River area in global 2D coordinates. Set automatically when used inside River3D.
@export var area := Rect2(0, 0, 1600, 400):
	set(value):
		area = value
		_rebuild()

## Wall thickness in 2D units. Thick walls stop fast particles from tunneling through.
@export var thickness := 40.0:
	set(value):
		thickness = maxf(value, 1.0)
		_rebuild()

var _left_wall: CollisionShape2D
var _right_wall: CollisionShape2D


func _ready() -> void:
	# Created at runtime (no owner), so the walls are never saved into the scene.
	_left_wall = _create_wall("LeftWall")
	_right_wall = _create_wall("RightWall")
	_rebuild()


## Called by River3D whenever the projected area changes.
func fit_to_river_area(river_area: Rect2) -> void:
	area = river_area


func _create_wall(wall_name: String) -> CollisionShape2D:
	var wall := CollisionShape2D.new()
	wall.name = wall_name
	wall.shape = RectangleShape2D.new()
	add_child(wall)
	return wall


func _rebuild() -> void:
	if _left_wall == null:
		return
	var local_area := global_transform.affine_inverse() * area
	var wall_size := Vector2(thickness, local_area.size.y)
	var center_y := local_area.get_center().y
	_place_wall(_left_wall, wall_size, Vector2(local_area.position.x - thickness / 2.0, center_y))
	_place_wall(_right_wall, wall_size, Vector2(local_area.end.x + thickness / 2.0, center_y))


func _place_wall(wall: CollisionShape2D, wall_size: Vector2, center: Vector2) -> void:
	(wall.shape as RectangleShape2D).size = wall_size
	wall.position = center
