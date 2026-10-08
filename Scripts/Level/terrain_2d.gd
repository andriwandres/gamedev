@tool
class_name Terrain2D
extends Polygon2D
## Solid level geometry of any shape. Draw it with the polygon editor; at
## runtime it collides with the mud. Its look comes from a TerrainSurface,
## which replaces the Polygon2D color and texture.

const DEFAULT_SURFACE := preload("res://Assets/Ground/2/terrain_surface.tres")

## Look of this piece. Leave empty to use the default rock.
@export var surface: TerrainSurface:
	set(value):
		surface = value
		_apply_surface()

## Physics layers this terrain is on. The mud collides with layer 1 by default.
@export_flags_2d_physics var collision_layer := 1

## The polygon the current outline distance map was baked for.
var _baked_polygon := PackedVector2Array()


func _init() -> void:
	_apply_surface()


func _ready() -> void:
	_bake_outline()
	if not Engine.is_editor_hint():
		_build_collision()


## What this piece covers, in global coordinates. Used for the level bounds.
func get_global_bounds() -> Rect2:
	return global_transform * Transform2D(0.0, offset) * Level2D.polygon_bounds(polygon)


func _draw() -> void:
	# Polygon2D has no change signal, but it redraws whenever the polygon changes.
	if polygon != _baked_polygon:
		_bake_outline.call_deferred()


func _validate_property(property: Dictionary) -> void:
	match property.name:
		# Derived from the surface and the polygon: rebuilt, never saved.
		"material", "texture", "uv":
			property.usage = PROPERTY_USAGE_NONE
		# No effect under the surface's shader.
		"color":
			property.usage &= ~PROPERTY_USAGE_EDITOR


func _apply_surface() -> void:
	material = (surface if surface != null else DEFAULT_SURFACE).get_material()


## The surface shader rounds the rock off towards its outline using this map.
func _bake_outline() -> void:
	_baked_polygon = polygon
	var outline_map := OutlineDistanceMap.bake(polygon, TerrainSurface.MAX_EDGE_DISTANCE)
	texture = outline_map.texture
	uv = outline_map.uv


func _build_collision() -> void:
	var shape := CollisionPolygon2D.new()
	shape.polygon = Transform2D(0.0, offset) * polygon
	var body := StaticBody2D.new()
	body.collision_layer = collision_layer
	body.add_child(shape)
	add_child(body)
