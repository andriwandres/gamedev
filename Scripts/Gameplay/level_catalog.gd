class_name LevelCatalog
extends Resource
## The levels of the game, in play order. Gameplay plays through them; a level
## select can list them.

@export var levels: Array[PackedScene] = []


func has_level(index: int) -> bool:
	return index >= 0 and index < levels.size()


func get_level(index: int) -> PackedScene:
	return levels[index] if has_level(index) else null
