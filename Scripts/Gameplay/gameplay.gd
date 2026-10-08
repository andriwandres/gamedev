class_name Gameplay
extends Node2D
## Plays the levels of a LevelCatalog. Owns everything levels share: the mud
## simulation and its look, the camera, the backdrop, screen effects and HUD.
## A level only brings its pieces (see Level2D).
##
## Every level gets a fresh mud simulation from `fluid_scene`. Reusing one
## breaks in Rapier: once a level's colliders are removed, the old fluid
## silently ignores new particles.

signal level_started(level: Level2D)
signal level_completed(level: Level2D)

@export var catalog: LevelCatalog
## The mud simulation, with its physics tuning (elasticity, surface tension).
@export var fluid_scene: PackedScene
@export var start_index := 0
## Lets the player place mud. Exported rather than looked up, so the HUD can
## connect to it before Gameplay is ready.
@export var placer: MudPlacer2D
@export var mud_surface: MudSurfaceRenderer2D
## Mud this far outside the level bounds is gone for good and gets removed.
@export var lost_mud_margin := 200.0

## Played instead of the catalog, e.g. when a level runs on its own (F6).
var level_override: PackedScene

var level: Level2D
var level_index := -1

var _level_scene: PackedScene
var _fluid: MudFluid2D
var _play_area := Rect2()

@onready var _level_slot: Node2D = $LevelSlot
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	get_viewport().size_changed.connect(_frame_camera)
	if level_override:
		_play(level_override)
	else:
		load_level(start_index)


func load_level(index: int) -> void:
	if catalog == null or not catalog.has_level(index):
		push_error("No level %d in the catalog." % index)
		return
	level_index = index
	_play(catalog.get_level(index))


func restart() -> void:
	if _level_scene:
		_play(_level_scene)


func has_next_level() -> bool:
	return level_override == null and catalog != null and catalog.has_level(level_index + 1)


func next_level() -> void:
	if has_next_level():
		load_level(level_index + 1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart_level"):
		restart()
	elif event.is_action_pressed(&"next_level") and level and level.is_completed:
		next_level()


func _physics_process(_delta: float) -> void:
	if _fluid:
		_remove_lost_mud()


func _play(scene: PackedScene) -> void:
	_unload_level()
	_level_scene = scene
	level = scene.instantiate() as Level2D
	if level == null:
		push_error("%s must have a Level2D as its root." % scene.resource_path)
		return
	_spawn_fluid()
	level.fluid = _fluid
	_level_slot.add_child(level)
	level.completed.connect(func() -> void: level_completed.emit(level))
	_play_area = level.get_bounds()
	placer.reset(level)
	_frame_camera()
	level_started.emit(level)


func _unload_level() -> void:
	# Leave the tree right away, so nothing old collides or drains this frame.
	for node: Node in [level, _fluid]:
		if node:
			node.get_parent().remove_child(node)
			node.queue_free()
	level = null
	_fluid = null


func _spawn_fluid() -> void:
	_fluid = fluid_scene.instantiate() as MudFluid2D
	add_child(_fluid)
	mud_surface.fluid = _fluid
	placer.blob.fluid = _fluid


## Zooms so the whole level is visible, centered in the window.
func _frame_camera() -> void:
	if not _play_area.has_area():
		return
	var fit := get_viewport_rect().size / _play_area.size
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	_camera.global_position = _play_area.get_center()
	_camera.zoom = Vector2.ONE * minf(fit.x, fit.y)


func _remove_lost_mud() -> void:
	var keep_area := _play_area.grow(lost_mud_margin)
	var lost := PackedInt32Array()
	var points := _fluid.points
	for i in points.size():
		if not keep_area.has_point(_fluid.to_global(points[i])):
			lost.append(i)
	if not lost.is_empty():
		_fluid.remove_particles(lost)
