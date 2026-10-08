class_name LevelHud
extends Control
## Shows the level's title, the mud left to place (as a MudGauge) and how far
## the goals are.

@export var gameplay: Gameplay

var _goals: Array[GoalZone2D] = []
var _mud_budget := 0

@onready var _title: Label = %Title
@onready var _mud_gauge: MudGauge = %MudGauge
@onready var _mud_left: Label = %MudLeft
@onready var _goal_progress: Label = %GoalProgress
@onready var _message: Label = %Message


func _ready() -> void:
	gameplay.level_started.connect(_on_level_started)
	gameplay.level_completed.connect(_on_level_completed)
	gameplay.placer.mud_left_changed.connect(_show_mud_left)


func _on_level_started(level: Level2D) -> void:
	_title.text = level.title
	_message.text = "Click or hold to place mud · R: restart"
	_mud_budget = level.mud_budget
	_goals = level.get_goals()
	for goal in _goals:
		goal.progressed.connect(_show_goal_progress.unbind(2))
	_show_mud_left(gameplay.placer.mud_left)
	_show_goal_progress()


func _on_level_completed(_level: Level2D) -> void:
	_message.text = "Level complete! Enter: next level" if gameplay.has_next_level() else "All levels complete!"


func _show_mud_left(mud_left: int) -> void:
	_mud_left.text = str(mud_left)
	_mud_gauge.set_amount(mud_left, _mud_budget)


func _show_goal_progress() -> void:
	var collected := 0
	var required := 0
	for goal in _goals:
		collected += mini(goal.collected, goal.required_mud)
		required += goal.required_mud
	_goal_progress.text = "Goal: %d / %d" % [collected, required]
