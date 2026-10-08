class_name MudPlacer2D
extends Node
## Lets the player place mud in the level's placement zones.
##
## A ghost of `blob` follows the mouse, kept inside the nearest placement zone,
## and shows whether the blob fits there. Pressing manifests it, even on top
## of mud already there. Holding keeps placing blobs, but only where there is
## no mud yet, so dragging paints mud and holding still pours it. Every blob
## costs its particle count from the mud budget.

signal mud_left_changed(mud_left: int)

## The blob released on press. Its shape and size set what one blob places.
@export var blob: MudBurst2D
## Preview of the blob at the cursor.
@export var ghost: BlobGhost2D
## Physics layers a blob may not overlap when placed.
@export_flags_2d_physics var blocking_mask := 1
## Shortest time between two blobs while holding, in seconds. A new press
## always places right away.
@export_range(0.0, 1.0, 0.01) var placement_interval := 0.06

var mud_left := 0:
	set(value):
		mud_left = value
		mud_left_changed.emit(mud_left)

var _level: Level2D
## Last pointer position in viewport coordinates, or null before the first
## pointer event. Taken from input events, so injected and touch-emulated
## input move the cursor too.
var _pointer: Variant = null
var _is_holding := false
## Set on press until the next physics tick, so a click shorter than a tick
## still places.
var _has_pending_press := false
var _cooldown := 0.0


## Starts placing for `level` with its full mud budget.
func reset(level: Level2D) -> void:
	_level = level
	_is_holding = false
	_has_pending_press = false
	_cooldown = 0.0
	mud_left = level.mud_budget if level else 0
	ghost.offsets = blob.get_particle_offsets()


func _unhandled_input(event: InputEvent) -> void:
	if _level == null:
		return
	if event is InputEventMouse:
		_pointer = event.position
	if not event.is_action(&"place_mud"):
		return
	_is_holding = event.is_pressed()
	_has_pending_press = _has_pending_press or _is_holding
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var target: Variant = _cursor_target()
	ghost.visible = target != null
	if target != null:
		ghost.global_position = target


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var target: Variant = _cursor_target()
	if target == null:
		return
	blob.global_position = target
	# A new press places anywhere free of obstacles. Repeats while holding also
	# keep clear of mud, so they don't pile onto the blob just placed.
	var is_repeat := _is_holding and not _has_pending_press
	var offsets := blob.get_particle_offsets()
	var can_place := offsets.size() <= mud_left and _blob_fits(offsets, is_repeat)
	ghost.is_valid = can_place
	var wants_to_place := _has_pending_press or (is_repeat and _cooldown <= 0.0)
	_has_pending_press = false
	if can_place and wants_to_place:
		blob.release()
		mud_left -= offsets.size()
		_cooldown = placement_interval
		ghost.pulse()


## Where the blob would go: the mouse, kept inside the placement zones.
func _cursor_target() -> Variant:
	if _level == null or _level.is_completed or _pointer == null:
		return null
	var world_pointer: Vector2 = blob.get_canvas_transform().affine_inverse() * _pointer
	return _level.snap_to_placement_zones(world_pointer)


## True if no particle of the blob would end up inside an obstacle or outside
## the level, nor, with `avoid_mud`, inside mud already placed.
func _blob_fits(offsets: PackedVector2Array, avoid_mud: bool) -> bool:
	var particle_radius := MudFluid2D.particle_radius()
	var particle_shape := CircleShape2D.new()
	particle_shape.radius = particle_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = particle_shape
	query.collision_mask = blocking_mask
	query.collide_with_areas = false
	var level_bounds := _level.get_bounds()
	var space := blob.get_world_2d().direct_space_state
	var fluid := _level.fluid
	for offset in offsets:
		var point := blob.to_global(offset)
		if not level_bounds.has_point(point):
			return false
		if avoid_mud and not fluid.get_particles_in_circle(fluid.to_local(point), 2.0 * particle_radius).is_empty():
			return false
		query.transform = Transform2D(0.0, point)
		if not space.intersect_shape(query, 1).is_empty():
			return false
	return true
