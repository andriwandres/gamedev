@tool
class_name PlacementZone2D
extends Zone2D
## Where the player may place mud by clicking.

const FILL_COLOR := Color(0.55, 0.85, 1.0, 0.1)
const OUTLINE_COLOR := Color(0.55, 0.85, 1.0, 0.6)
const DASH_LENGTH := 16.0


func _draw() -> void:
	var rect := get_local_rect()
	draw_rect(rect, FILL_COLOR)
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in corners.size():
		draw_dashed_line(corners[i], corners[(i + 1) % corners.size()], OUTLINE_COLOR, 3.0, DASH_LENGTH)
