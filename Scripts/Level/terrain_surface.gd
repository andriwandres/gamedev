@tool
class_name TerrainSurface
extends Resource
## Look of Terrain2D (and Wall2D) pieces. Every piece using the same surface
## shares one material, so tweaking the resource updates them all at once.
## The light itself is shared with the mud, see lighting_2d.gdshaderinc.

const SHADER := preload("res://Scripts/Level/Shaders/terrain_surface.gdshader")
## Distance in 2D units that a full edge map value stands for. Bevels wider
## than this are cut off.
const MAX_EDGE_DISTANCE := 64.0

@export_group("Textures")
@export var albedo: Texture2D:
	set(value):
		albedo = value
		_sync()
## Grayscale height, used for the relief inside the rock.
@export var height: Texture2D:
	set(value):
		height = value
		_sync()
@export var ambient_occlusion: Texture2D:
	set(value):
		ambient_occlusion = value
		_sync()
## 2D units (pixels) covered by one repeat of the textures.
@export var tile_size := 256.0:
	set(value):
		tile_size = maxf(value, 1.0)
		_sync()

@export_group("Color")
@export var tint := Color.WHITE:
	set(value):
		tint = value
		_sync()
@export_range(0.0, 1.0) var ambient_occlusion_strength := 0.8:
	set(value):
		ambient_occlusion_strength = value
		_sync()
## How much the rock darkens towards its outline.
@export_range(0.0, 1.0) var edge_darkening := 0.35:
	set(value):
		edge_darkening = value
		_sync()

@export_group("Relief")
## How far in from the outline the rock keeps rising, in pixels.
@export_range(1.0, 64.0) var bevel_width := 18.0:
	set(value):
		bevel_width = value
		_sync()
## How high the rock rises over the bevel, in pixels.
@export var bevel_height := 10.0:
	set(value):
		bevel_height = value
		_sync()
## Height of the texture relief, in pixels.
@export var detail_height := 4.0:
	set(value):
		detail_height = value
		_sync()

@export_group("Wetness")
@export_range(0.0, 2.0) var wetness := 0.08:
	set(value):
		wetness = value
		_sync()
@export_range(1.0, 256.0) var shininess := 16.0:
	set(value):
		shininess = value
		_sync()

var _material: ShaderMaterial


## The material shared by every terrain piece using this surface.
func get_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_sync()
	return _material


func _sync() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"albedo_map", albedo)
	_material.set_shader_parameter(&"height_map", height)
	_material.set_shader_parameter(&"ao_map", ambient_occlusion)
	_material.set_shader_parameter(&"tile_size", tile_size)
	_material.set_shader_parameter(&"tint", tint)
	_material.set_shader_parameter(&"ao_strength", ambient_occlusion_strength)
	_material.set_shader_parameter(&"edge_darkening", edge_darkening)
	_material.set_shader_parameter(&"max_edge_distance", MAX_EDGE_DISTANCE)
	_material.set_shader_parameter(&"bevel_width", bevel_width)
	_material.set_shader_parameter(&"bevel_height", bevel_height)
	_material.set_shader_parameter(&"detail_height", detail_height)
	_material.set_shader_parameter(&"wetness", wetness)
	_material.set_shader_parameter(&"shininess", shininess)
