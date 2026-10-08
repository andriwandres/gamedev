class_name MudSurfaceRenderer2D
extends CanvasLayer
## Draws a MudFluid2D as a textured, lit mud surface whose texture travels with
## the particles.
##
## Every particle is splatted into two offscreen HDR viewports sharing one
## MultiMesh: an albedo pass and a detail pass (height + AO), see
## mud_splat.gdshader. The albedo pass is shown through a SubViewportContainer
## whose material, mud_surface.gdshader, combines both into the final surface.
## The light is shared with the terrain, see lighting_2d.gdshaderinc.
##
## It covers the viewport it lives in and mirrors that viewport's camera.

const SPLAT_SHADER := preload("res://Scripts/Fluid/Shaders/mud_splat.gdshader")
const SURFACE_SHADER := preload("res://Scripts/Fluid/Shaders/mud_surface.gdshader")
const SPLAT_MESH := preload("res://addons/godot-rapier2d/circle_mesh.tres")
## Half the side length of SPLAT_MESH, in its own units.
const SPLAT_MESH_RADIUS := 16.0
## Floats per instance in the MultiMesh buffer: a 2D transform (8) + custom data (4).
const FLOATS_PER_SPLAT := 12

@export var fluid: MudFluid2D
@export var camera: Camera2D
@export var surface: MudSurfaceMaterial
## Splat radius relative to the particle radius. Bigger splats merge into
## smoother, rounder mud; smaller ones keep more of the particle structure.
@export_range(1.0, 8.0, 0.1) var splat_scale := 4.0

@export_group("Edge")
## Summed splat weight at which the mud's edge sits. Lower values grow the mud.
@export_range(0.05, 4.0, 0.05) var threshold := 0.7
@export_range(0.0, 0.5, 0.01) var edge_softness := 0.08

var _multimesh := MultiMesh.new()
var _albedo_splat := ShaderMaterial.new()
var _detail_splat := ShaderMaterial.new()
var _surface_material := ShaderMaterial.new()
var _container: SubViewportContainer
var _pass_viewports: Array[SubViewport] = []
var _pass_cameras: Array[Camera2D] = []
var _pass_splats: Array[MultiMeshInstance2D] = []


func _ready() -> void:
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_custom_data = true
	_multimesh.mesh = SPLAT_MESH
	_albedo_splat.shader = SPLAT_SHADER
	_detail_splat.shader = SPLAT_SHADER
	_detail_splat.set_shader_parameter(&"output_detail", true)
	_surface_material.shader = SURFACE_SHADER

	_container = SubViewportContainer.new()
	_container.name = "Surface"
	_container.material = _surface_material
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	_create_splat_pass("AlbedoPass", _albedo_splat, _container)
	var detail_pass := _create_splat_pass("DetailPass", _detail_splat, self)
	_surface_material.set_shader_parameter(&"detail_pass", detail_pass.get_texture())

	if fluid:
		fluid.debug_draw = false


func _process(_delta: float) -> void:
	_fit_to_parent_viewport()
	_mirror_camera()
	_apply_settings()
	_update_splats()


func _create_splat_pass(pass_name: String, splat_material: ShaderMaterial, parent: Node) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = pass_name
	viewport.transparent_bg = true
	# Summed splat weights go well above 1, which an 8-bit target would clip.
	viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# The passes hold data, not colors: keep the screen's WorldEnvironment
	# (glow, background) out of them.
	viewport.own_world_3d = true
	parent.add_child(viewport)

	var splats := MultiMeshInstance2D.new()
	splats.multimesh = _multimesh
	splats.material = splat_material
	viewport.add_child(splats)

	var pass_camera := Camera2D.new()
	viewport.add_child(pass_camera)

	_pass_viewports.append(viewport)
	_pass_cameras.append(pass_camera)
	_pass_splats.append(splats)
	return viewport


func _fit_to_parent_viewport() -> void:
	# CanvasLayer draws in screen space: cover the viewport we live in, 1:1,
	# so the passes line up pixel for pixel with what the camera sees.
	var viewport_size := get_viewport().get_visible_rect().size
	_container.position = Vector2.ZERO
	_container.size = viewport_size
	for viewport in _pass_viewports:
		viewport.size = Vector2i(viewport_size)


func _mirror_camera() -> void:
	if camera == null:
		return
	for pass_camera in _pass_cameras:
		pass_camera.anchor_mode = camera.anchor_mode
		pass_camera.ignore_rotation = camera.ignore_rotation
		pass_camera.offset = camera.offset
		pass_camera.zoom = camera.zoom
		pass_camera.global_transform = camera.global_transform


## Pushes the settings to the shaders every frame, so tweaks made in the
## remote inspector while the game runs show up immediately.
func _apply_settings() -> void:
	var splat_radius := _splat_radius()
	for splat_material in [_albedo_splat, _detail_splat]:
		splat_material.set_shader_parameter(&"splat_radius", splat_radius)
		if surface:
			surface.apply_to_splat(splat_material)
	if surface:
		surface.apply_to_surface(_surface_material)
	_surface_material.set_shader_parameter(&"threshold", threshold)
	_surface_material.set_shader_parameter(&"edge_softness", edge_softness)


func _update_splats() -> void:
	if fluid == null:
		_multimesh.instance_count = 0
		return
	var positions := fluid.points
	var material_coords := fluid.get_material_coords()
	var count := mini(positions.size(), material_coords.size())
	_multimesh.instance_count = count
	if count == 0:
		return

	var mesh_scale := _splat_radius() / SPLAT_MESH_RADIUS
	var buffer := PackedFloat32Array()
	buffer.resize(count * FLOATS_PER_SPLAT)
	for i in count:
		var point := positions[i]
		var material_coord := material_coords[i]
		var offset := i * FLOATS_PER_SPLAT
		# Transform2D rows: (x.x, y.x, padding, origin.x), (x.y, y.y, padding, origin.y).
		buffer[offset] = mesh_scale
		buffer[offset + 3] = point.x
		buffer[offset + 5] = mesh_scale
		buffer[offset + 7] = point.y
		# Custom data, read as INSTANCE_CUSTOM in mud_splat.gdshader.
		buffer[offset + 8] = material_coord.x
		buffer[offset + 9] = material_coord.y
	_multimesh.buffer = buffer

	# Points are local to the fluid.
	for splats in _pass_splats:
		splats.global_transform = fluid.global_transform


func _splat_radius() -> float:
	return MudFluid2D.particle_radius() * splat_scale
