@tool
extends Node3D
## Projects the 2D river scene onto a 3D plane.
##
## `size` is the single source of truth. It drives the plane mesh, the SubViewport
## resolution and the Camera2D framing, so the 2D view always fills the plane
## exactly, with no stretching or cropping.

## Size of the river plane in meters.
@export var size := Vector2(40, 10):
	set(value):
		size = value.max(Vector2(0.01, 0.01))
		_sync()

## How many 2D units (pixels) make up one meter. This sets the scale of the 2D
## simulation, so keep it fixed once the physics is tuned.
@export var pixels_per_meter := 40.0:
	set(value):
		pixels_per_meter = maxf(value, 0.01)
		_sync()

## Resolution multiplier for the projected texture. It makes the texture sharper
## or cheaper without changing how much of the 2D world is visible.
@export_range(0.25, 4.0, 0.25) var render_scale := 1.0:
	set(value):
		render_scale = value
		_sync()

@onready var _mesh_instance: MeshInstance3D = $RiverMesh
@onready var _sub_viewport: SubViewport = $SubViewport


func _ready() -> void:
	_sync()


## Area of the 2D world (in 2D units) that is projected onto the plane.
func get_visible_area_2d() -> Vector2:
	return size * pixels_per_meter


func _sync() -> void:
	# Setters run before _ready when the scene loads; _ready syncs once nodes exist.
	if not is_node_ready():
		return
	_sync_mesh()
	_sync_viewport()
	_sync_camera()


func _sync_mesh() -> void:
	var plane := _mesh_instance.mesh as PlaneMesh
	if plane == null:
		push_warning("RiverMesh needs a PlaneMesh to be resized.")
		return
	plane.size = size


func _sync_viewport() -> void:
	var resolution := Vector2i((get_visible_area_2d() * render_scale).round())
	_sub_viewport.size = resolution.max(Vector2i.ONE)


func _sync_camera() -> void:
	var camera := _find_camera_2d()
	if camera == null:
		return
	# Top-left anchoring makes the camera position the top-left corner of the
	# projected area. Move the camera to pan; the area's size stays locked.
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camera.rotation = 0.0
	camera.zoom = Vector2.ONE * render_scale


func _find_camera_2d() -> Camera2D:
	var cameras := _sub_viewport.find_children("*", "Camera2D", true, false)
	return cameras.front() as Camera2D if not cameras.is_empty() else null
