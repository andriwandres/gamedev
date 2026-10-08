@tool
class_name GoalZone2D
extends Zone2D
## Mud has to reach this zone. Mud that arrives is drained and counted; the
## goal is reached once `required_mud` particles have arrived.

signal progressed(collected: int, required: int)

const EMPTY_COLOR := Color(1.0, 0.8, 0.3, 0.12)
const FILLED_COLOR := Color(1.0, 0.8, 0.3, 0.45)
const OUTLINE_COLOR := Color(1.0, 0.8, 0.3, 0.8)

## Particles that must arrive to reach this goal.
@export_range(1, 10000, 1, "or_greater") var required_mud := 30:
	set(value):
		required_mud = value
		queue_redraw()

var collected := 0


func is_reached() -> bool:
	return collected >= required_mud


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var level := Level2D.find_level(self)
	if level == null or level.fluid == null:
		return
	var arrived := level.fluid.get_particles_in_aabb(get_global_bounds())
	if arrived.is_empty():
		return
	level.fluid.remove_particles(arrived)
	collected += arrived.size()
	queue_redraw()
	progressed.emit(collected, required_mud)


func _draw() -> void:
	var rect := get_local_rect()
	draw_rect(rect, EMPTY_COLOR)
	# Fills up from the bottom as mud arrives.
	var fill := clampf(float(collected) / required_mud, 0.0, 1.0)
	draw_rect(Rect2(rect.position.x, rect.end.y - rect.size.y * fill, rect.size.x, rect.size.y * fill), FILLED_COLOR)
	draw_rect(rect, OUTLINE_COLOR, false, 3.0)
