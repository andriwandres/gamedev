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

## Main level size in meters. The cursor area can extend the plane upstream.
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

@export_group("Cursor Spawning")
## Manual burst used for clicks.
@export var cursor_burst: MudBurst2D
## Clickable rectangle in level-local 2D units. May extend upstream of the level.
@export var cursor_spawn_area := Rect2(0, 0, 400, 300):
	set(value):
		cursor_spawn_area = value.abs()
		_on_area_changed()
## Maximum live particles allowed.
@export_range(1, 10000, 1, "or_greater") var max_cursor_particles := 1000
@export_flags_2d_physics var spawn_collision_mask := 1

## Mud that has reached a MudSink2D so far.
var mud_consumed := 0

## The mud simulation this level feeds. Bound by the stage, or by the level
## itself when run on its own.
var fluid: MudFluid2D

var _pending_cursor_spawns: Array[Vector2] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_apply_gravity()
	var runs_standalone := get_parent() == get_tree().root
	# The 3D stage maps input for embedded levels. F6 uses the 2D camera directly.
	set_process_unhandled_input(runs_standalone)
	if fluid == null and runs_standalone:
		_attach_sim_rig()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not event is InputEventMouseButton:
		return
	if event.is_action_pressed(&"spawn_liquid"):
		var world_position: Vector2 = get_canvas_transform().affine_inverse() * event.position
		if request_cursor_spawn(world_position):
			get_viewport().set_input_as_handled()


## Queues a world-space 2D position; physics queries and spawning run next tick.
func request_cursor_spawn(world_position: Vector2) -> bool:
	if Engine.is_editor_hint() or cursor_burst == null or fluid == null:
		return false
	if not world_position.is_finite() or not get_cursor_spawn_area_2d().has_point(world_position):
		return false
	_pending_cursor_spawns.append(world_position)
	return true


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _pending_cursor_spawns.is_empty():
		return
	if cursor_burst == null or fluid == null:
		_pending_cursor_spawns.clear()
		return
	var offsets := cursor_burst.get_particle_offsets()
	var particle_count := fluid.points.size()
	for world_position in _pending_cursor_spawns:
		if not get_cursor_spawn_area_2d().has_point(world_position):
			continue
		if particle_count + offsets.size() > max_cursor_particles:
			break
		cursor_burst.global_position = world_position
		if not _cursor_burst_fits(offsets):
			continue
		cursor_burst.release()
		# Reserve this tick's spawns even if the physics backend updates points later.
		particle_count += offsets.size()
	_pending_cursor_spawns.clear()


func _cursor_burst_fits(offsets: PackedVector2Array) -> bool:
	var particle_shape := CircleShape2D.new()
	particle_shape.radius = MudFluid2D.particle_radius()
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = particle_shape
	query.collision_mask = spawn_collision_mask
	query.collide_with_areas = false
	# Restrict the click center to the placement rectangle, while allowing the
	# blob to extend past its edges into empty space.
	var safe_area := get_area_2d().grow(-particle_shape.radius)
	var space := get_world_2d().direct_space_state
	for offset in offsets:
		var point := cursor_burst.to_global(offset)
		if not safe_area.has_point(point):
			return false
		query.transform = Transform2D(0.0, point)
		if not space.intersect_shape(query, 1).is_empty():
			return false
	return true


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


## Simulation/rendering bounds, including room for bursts around the spawn zone.
func get_area_2d() -> Rect2:
	var area := Rect2(Vector2.ZERO, size * pixels_per_meter)
	if cursor_spawn_area.has_area():
		var margin := MudFluid2D.particle_radius()
		if cursor_burst != null:
			for offset in cursor_burst.get_particle_offsets():
				margin = maxf(margin, offset.length() + MudFluid2D.particle_radius())
		area = area.merge(cursor_spawn_area.grow(margin))
	return Rect2(global_position + area.position, area.size)


## Clickable area in global 2D coordinates, independent of obstacle bounds.
func get_cursor_spawn_area_2d() -> Rect2:
	return Rect2(global_position + cursor_spawn_area.position, cursor_spawn_area.size)


func _draw() -> void:
	if Engine.is_editor_hint():
		var area := get_area_2d()
		draw_rect(Rect2(area.position - global_position, area.size), Color(1, 0.8, 0.2, 0.8), false, 4.0)
		draw_rect(cursor_spawn_area, Color(0.2, 0.8, 1.0, 0.8), false, 3.0)


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
	fluid = rig.find_children("*", "Fluid2D", true, false).front() as MudFluid2D
	_frame_camera(rig.find_children("*", "Camera2D", true, false).front())
	propagate_call(&"fit_to_river_area", [get_area_2d()])


func _frame_camera(camera: Camera2D) -> void:
	var area := get_area_2d()
	var fit := get_viewport().get_visible_rect().size / area.size
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camera.global_position = area.position
	camera.zoom = Vector2.ONE * minf(fit.x, fit.y)
