@tool
class_name Level2D
extends Node2D
## Root of a level. A level is just its pieces: walls and obstacles (see
## Scenes/Pieces), PlacementZone2Ds where the player may place mud and
## GoalZone2Ds the mud has to reach. Its bounds are whatever the pieces cover,
## so levels can be any size.
##
## Gameplay (gameplay_scene.tscn) brings the mud, camera and HUD and plays the
## level. Run a level scene on its own (F6) to play just that level.

signal completed

const GAMEPLAY_SCENE_PATH := "res://Scenes/gameplay_scene.tscn"
const BOUNDS_COLOR := Color(1.0, 0.8, 0.2, 0.8)

@export var title := "Untitled"
## Mud, in particles, the player may place in this level.
@export_range(0, 10000, 1, "or_greater") var mud_budget := 300
## Gravity relative to the project default (980). Lower values make the mud
## flow slower and give the player more time.
@export_range(0.0, 2.0, 0.05) var gravity_scale := 0.35
## Empty space kept around the pieces when framing the level, in pixels.
@export var margin := 40.0

## The mud simulation this level plays with. Bound by Gameplay.
var fluid: MudFluid2D
var is_completed := false


func _ready() -> void:
	# In the editor, keep the bounds outline following pieces as they move.
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		return
	if get_parent() == get_tree().root:
		_play_in_gameplay.call_deferred()
		return
	_apply_gravity()
	for goal in get_goals():
		goal.progressed.connect(_check_completed.unbind(2))


func _process(_delta: float) -> void:
	queue_redraw()


## The Level2D that `node` belongs to, or null.
static func find_level(node: Node) -> Level2D:
	while node != null and not node is Level2D:
		node = node.get_parent()
	return node as Level2D


## Smallest rect containing all `points`.
static func polygon_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


## Everything the level's pieces cover plus `margin`, in global coordinates.
func get_bounds() -> Rect2:
	var bounds := Rect2()
	var is_first := true
	for node in find_children("*", "", true, false):
		var piece_bounds := _piece_bounds(node)
		if not piece_bounds.has_area():
			continue
		bounds = piece_bounds if is_first else bounds.merge(piece_bounds)
		is_first = false
	return bounds.grow(margin)


func get_placement_zones() -> Array[PlacementZone2D]:
	var zones: Array[PlacementZone2D] = []
	zones.assign(_find_all(PlacementZone2D))
	return zones


func get_goals() -> Array[GoalZone2D]:
	var goals: Array[GoalZone2D] = []
	goals.assign(_find_all(GoalZone2D))
	return goals


## The point inside any placement zone closest to `global_point`, or null if
## the level has no placement zones.
func snap_to_placement_zones(global_point: Vector2) -> Variant:
	var closest: Variant = null
	for zone in get_placement_zones():
		var candidate := zone.clamp_global_point(global_point)
		if closest == null or global_point.distance_squared_to(candidate) < global_point.distance_squared_to(closest):
			closest = candidate
	return closest


func _draw() -> void:
	if Engine.is_editor_hint():
		var bounds := get_bounds()
		draw_set_transform_matrix(global_transform.affine_inverse())
		draw_rect(bounds, BOUNDS_COLOR, false, 4.0)


## Bounds of one piece in global coordinates, or an empty rect if it has none.
## Pieces opt in with get_global_bounds(); plain physics shapes count too.
func _piece_bounds(node: Node) -> Rect2:
	if node.has_method(&"get_global_bounds"):
		return node.get_global_bounds()
	if node is CollisionShape2D and node.shape != null:
		return node.global_transform * node.shape.get_rect()
	if node is CollisionPolygon2D and node.polygon.size() > 0:
		return node.global_transform * polygon_bounds(node.polygon)
	return Rect2()


func _find_all(type: Variant) -> Array[Node]:
	return find_children("*", "", true, false).filter(func(node: Node) -> bool: return is_instance_of(node, type))


func _check_completed() -> void:
	if is_completed:
		return
	var goals := get_goals()
	if goals.is_empty() or not goals.all(func(goal: GoalZone2D) -> bool: return goal.is_reached()):
		return
	is_completed = true
	completed.emit()


func _apply_gravity() -> void:
	# Sets the gravity of the whole 2D world this level plays in.
	var default_gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	PhysicsServer2D.area_set_param(get_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY, default_gravity * gravity_scale)


## F6: swap this bare level for a Gameplay that plays it.
func _play_in_gameplay() -> void:
	var gameplay: Gameplay = load(GAMEPLAY_SCENE_PATH).instantiate()
	gameplay.level_override = load(scene_file_path)
	get_tree().root.add_child(gameplay)
	queue_free()
