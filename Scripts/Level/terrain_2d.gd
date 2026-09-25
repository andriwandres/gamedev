@tool
class_name Terrain2D
extends Polygon2D
## Solid level geometry of any shape. Draw it with the polygon editor; at
## runtime it collides with the mud. A repeating texture gives the paper look.

## Physics layers this terrain is on. The mud collides with layer 1 by default.
@export_flags_2d_physics var collision_layer := 1


func _init() -> void:
	color = Color(0.36, 0.29, 0.22)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func _ready() -> void:
	if not Engine.is_editor_hint():
		_build_collision()


func _build_collision() -> void:
	var shape := CollisionPolygon2D.new()
	shape.polygon = Transform2D(0.0, offset) * polygon
	var body := StaticBody2D.new()
	body.collision_layer = collision_layer
	body.add_child(shape)
	add_child(body)
