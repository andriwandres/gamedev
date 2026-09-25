@tool
class_name Level2D
extends Node2D
## Root of a level. Everything inside is designed in 2D (Wall2D, Terrain2D,
## MudBurst2D, ...). The level owns its size; the 3D stage adapts to it.
##
## Run a level scene on its own (F6) to test it: it then brings its own mud
## simulation and camera.

signal area_changed
signal mud_consumed_changed(total: int, limit: int)
signal mud_limit_reached

const SIM_RIG_PATH := "res://Scenes/river_2d_scene.tscn"

## Level size in meters. This is also the size of the plane in 3D.
@export var size := Vector2(10, 40):
	set(value):
		size = value.max(Vector2.ONE)
		_on_area_changed()

## How many 2D units (pixels) make up one meter.
@export var pixels_per_meter := 40.0:
	set(value):
		pixels_per_meter = maxf(value, 0.01)
		_on_area_changed()

## Gravity relative to the project default (980). Lower values make the mud
## flow slower and give the player more time.
@export_range(0.0, 2.0, 0.05) var gravity_scale := 0.3:
	set(value):
		gravity_scale = value
		_apply_gravity()

## How much mud (in particles) may reach a MudSink2D before the level is lost.
@export var mud_limit := 30

## Mud that has reached a MudSink2D so far.
var mud_consumed := 0

## The mud simulation this level feeds. Bound by the stage, or by the level
## itself when run on its own.
var fluid: Fluid2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_apply_gravity()
	var runs_standalone := get_parent() == get_tree().root
	if fluid == null and runs_standalone:
		_attach_sim_rig()


## The Level2D that `node` belongs to, or null.
static func find_level(node: Node) -> Level2D:
	while node != null and not node is Level2D:
		node = node.get_parent()
	return node as Level2D


## Called by MudSink2D when mud reaches it.
func add_consumed_mud(amount: int) -> void:
	var was_below_limit := mud_consumed < mud_limit
	mud_consumed += amount
	mud_consumed_changed.emit(mud_consumed, mud_limit)
	if was_below_limit and mud_consumed >= mud_limit:
		mud_limit_reached.emit()


## Playable area in global 2D coordinates.
func get_area_2d() -> Rect2:
	return Rect2(global_position, size * pixels_per_meter)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size * pixels_per_meter), Color(1, 0.8, 0.2, 0.8), false, 4.0)


func _apply_gravity() -> void:
	# Each stage renders into its own SubViewport, which has its own physics
	# space, so this only affects this level.
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	var default_gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	PhysicsServer2D.area_set_param(get_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY, default_gravity * gravity_scale)


func _on_area_changed() -> void:
	queue_redraw()
	area_changed.emit()


func _attach_sim_rig() -> void:
	var rig: Node = load(SIM_RIG_PATH).instantiate()
	add_child(rig)
	fluid = rig.find_children("*", "Fluid2D", true, false).front()
	_frame_camera(rig.find_children("*", "Camera2D", true, false).front())
	propagate_call(&"fit_to_river_area", [get_area_2d()])


func _frame_camera(camera: Camera2D) -> void:
	var area := get_area_2d()
	var fit := get_viewport().get_visible_rect().size / area.size
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camera.global_position = area.position
	camera.zoom = Vector2.ONE * minf(fit.x, fit.y)
