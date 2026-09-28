class_name MudSurfaceMaterial
extends Resource
## Look of the mud surface: which texture set it uses and how it catches light.
## One resource per material (e.g. Assets/Mud/1/mud_surface.tres) so switching
## looks is a single swap on the MudSurfaceRenderer2D.

@export_group("Textures")
@export var albedo: Texture2D
## Grayscale height, used for the fine relief on top of the blob shape.
@export var height: Texture2D
@export var ambient_occlusion: Texture2D
## 2D units (pixels) covered by one repeat of the textures.
@export var tile_size := 128.0

@export_group("Color")
@export var tint := Color.WHITE
@export_range(0.0, 1.0) var ambient_occlusion_strength := 0.8
## How much thin mud (edges, stragglers) darkens.
@export_range(0.0, 1.0) var edge_darkening := 0.45

@export_group("Relief")
## How high thick mud bulges, in pixels. Gives the blobs their round shape.
@export var bulge_height := 10.0
## How much extra fluid (above the edge) it takes to reach full bulge height.
@export var bulge_range := 2.5
## Height of the texture relief, in pixels.
@export var detail_height := 3.0

@export_group("Wetness")
@export_range(0.0, 2.0) var wetness := 0.35
@export_range(1.0, 256.0) var shininess := 48.0


func apply_to_splat(splat_material: ShaderMaterial) -> void:
	splat_material.set_shader_parameter(&"albedo_map", albedo)
	splat_material.set_shader_parameter(&"height_map", height)
	splat_material.set_shader_parameter(&"ao_map", ambient_occlusion)
	splat_material.set_shader_parameter(&"tile_size", tile_size)


func apply_to_surface(surface_material: ShaderMaterial) -> void:
	surface_material.set_shader_parameter(&"tint", tint)
	surface_material.set_shader_parameter(&"ao_strength", ambient_occlusion_strength)
	surface_material.set_shader_parameter(&"edge_darkening", edge_darkening)
	surface_material.set_shader_parameter(&"bulge_height", bulge_height)
	surface_material.set_shader_parameter(&"bulge_range", bulge_range)
	surface_material.set_shader_parameter(&"detail_height", detail_height)
	surface_material.set_shader_parameter(&"wetness", wetness)
	surface_material.set_shader_parameter(&"shininess", shininess)
