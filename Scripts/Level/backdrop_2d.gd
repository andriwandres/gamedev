@tool
class_name Backdrop2D
extends Node2D
## Ground behind the level. Fills whatever part of the world the camera shows,
## so letterbox margins around the level are covered too.
##
## It reuses TerrainSurface: drawn without an outline, the terrain shader is a
## flat, lit, world-space tiled surface sharing the light with mud and rock.

## Look of the ground.
@export var surface: TerrainSurface:
	set(value):
		surface = value
		material = surface.get_material() if surface else null

## Edge map value 1 everywhere: no outline, so no bevel.
static var _no_outline: ImageTexture

var _drawn_rect := Rect2()


func _ready() -> void:
	if _no_outline == null:
		var image := Image.create(1, 1, false, Image.FORMAT_R8)
		image.fill(Color.WHITE)
		_no_outline = ImageTexture.create_from_image(image)


func _process(_delta: float) -> void:
	var visible_rect := _visible_rect()
	if visible_rect != _drawn_rect:
		_drawn_rect = visible_rect
		queue_redraw()


func _draw() -> void:
	draw_texture_rect(_no_outline, _drawn_rect, false)


## The visible part of the world, in this node's local coordinates.
func _visible_rect() -> Rect2:
	var screen_to_local := (get_viewport().get_canvas_transform() * get_global_transform()).affine_inverse()
	return screen_to_local * get_viewport_rect()
