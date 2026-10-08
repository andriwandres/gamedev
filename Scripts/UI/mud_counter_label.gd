class_name MudCounterLabel
extends Label
## Shows how much mud has reached the bottom of the level the stage is playing.

@export var stage: LevelStage2D

var _level: Level2D


func _ready() -> void:
	stage.level_changed.connect(_watch_level)
	_watch_level(stage.get_level())


func _watch_level(level: Level2D) -> void:
	_level = level
	if level == null:
		text = ""
		return
	level.mud_consumed_changed.connect(_refresh.unbind(2))
	_refresh()


func _refresh() -> void:
	text = "Score: %d " % [_level.mud_consumed]
