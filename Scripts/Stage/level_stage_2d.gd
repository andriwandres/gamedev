@tool
class_name LevelStage2D
extends Node2D
## Plays one level at a time. Swap `level_scene` to load another level.
##
## Levels are self-contained: each brings its own mud simulation and camera
## (see Level2D), so the stage only spawns the level and tells listeners
## such as the HUD which level is playing.

signal level_changed(level: Level2D)

## The level to play. Its root must be a Level2D.
@export var level_scene: PackedScene:
	set(value):
		level_scene = value
		if is_node_ready():
			_spawn_level()

var _level: Level2D


func _ready() -> void:
	_spawn_level()


func get_level() -> Level2D:
	return _level


func _spawn_level() -> void:
	if _level:
		_level.queue_free()
		_level = null
	if level_scene:
		var instance := level_scene.instantiate()
		_level = instance as Level2D
		if _level:
			add_child(_level)
		else:
			instance.free()
			push_error("level_scene must have a Level2D as its root.")
	level_changed.emit(_level)
