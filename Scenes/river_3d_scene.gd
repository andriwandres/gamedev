@tool
class_name RiverStage3D
extends Node3D
## 3D stage for a level: renders the 2D mud simulation and the level onto a plane.
##
## The level (a Level2D scene) is the single source of truth for size. The stage
## derives the plane mesh, the SubViewport resolution and the Camera2D framing
## from it, so the 2D view always fills the plane exactly.

signal level_changed(level: Level2D)

## Used when no level is assigned.
const FALLBACK_SIZE := Vector2(10, 40)
const FALLBACK_PIXELS_PER_METER := 40.0

## The level to play. Its root must be a Level2D.
@export var level_scene: PackedScene:
	set(value):
		level_scene = value
		if is_node_ready():
			_spawn_level()
			_sync()

## Resolution multiplier for the projected texture. It makes the texture sharper
## or cheaper without changing how much of the 2D world is visible.
@export_range(0.25, 4.0, 0.25) var render_scale := 1.0:
	set(value):
		render_scale = value
		_sync()

var _level: Level2D

@onready var _mesh_instance: MeshInstance3D = $RiverMesh
@onready var _sub_viewport: SubViewport = $SubViewport


func _ready() -> void:
	_spawn_level()
	_sync()


func get_level() -> Level2D:
	return _level


## Level size in meters, which is also the plane size.
func get_size_meters() -> Vector2:
	return _level.size if _level else FALLBACK_SIZE


## Rect of the 2D world projected onto the plane, in global 2D coordinates.
func get_projected_area_2d() -> Rect2:
	if _level:
		return _level.get_area_2d()
	return Rect2(Vector2.ZERO, FALLBACK_SIZE * FALLBACK_PIXELS_PER_METER)


func _spawn_level() -> void:
	if _level:
		_level.queue_free()
		_level = null
	if level_scene == null:
		level_changed.emit(null)
		return
	_level = level_scene.instantiate() as Level2D
	if _level == null:
		push_error("level_scene must have a Level2D as its root.")
		return
	_level.fluid = _find_first(Fluid2D)
	_level.area_changed.connect(_sync)
	_sub_viewport.add_child(_level)
	level_changed.emit(_level)


func _sync() -> void:
	# Setters run before _ready when the scene loads; _ready syncs once nodes exist.
	if not is_node_ready():
		return
	_sync_mesh()
	_sync_viewport()
	_sync_camera()
	_sync_area_listeners()


func _sync_mesh() -> void:
	var plane := _mesh_instance.mesh as PlaneMesh
	if plane == null:
		push_warning("RiverMesh needs a PlaneMesh to be resized.")
		return
	plane.size = get_size_meters()


func _sync_viewport() -> void:
	var resolution := Vector2i((get_projected_area_2d().size * render_scale).round())
	_sub_viewport.size = resolution.max(Vector2i.ONE)


func _sync_camera() -> void:
	var camera := _find_first(Camera2D) as Camera2D
	if camera == null:
		return
	# Top-left anchoring puts the camera exactly on the level's top-left corner.
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camera.rotation = 0.0
	camera.global_position = get_projected_area_2d().position
	camera.zoom = Vector2.ONE * render_scale


func _sync_area_listeners() -> void:
	# Any node in the 2D scene can fit itself to the level by implementing
	# fit_to_river_area(area: Rect2), e.g. walls or the end-of-river consumer.
	_sub_viewport.propagate_call(&"fit_to_river_area", [get_projected_area_2d()])


func _find_first(type: Variant) -> Node:
	for node in _sub_viewport.find_children("*", "", true, false):
		if is_instance_of(node, type):
			return node
	return null
