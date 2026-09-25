@tool
class_name ViewportFluid2DShaderRenderer
extends Fluid2DShaderRenderer
## Fluid2DShaderRenderer that works in any viewport (e.g. a SubViewport
## projected onto a 3D mesh), not just the game window.
##
## The base renderer sizes itself to the project window and positions itself by
## the camera's world position, which only lines up when it renders straight to
## the window with a centered camera at the origin.


func _ready() -> void:
	super()
	_fit_to_parent_viewport()


func _process(_delta: float) -> void:
	_fit_to_parent_viewport()
	_mirror_camera()


func _fit_to_parent_viewport() -> void:
	# CanvasLayer draws in screen space: cover the viewport we live in, 1:1,
	# so the water shader's SCREEN_UV sampling matches the fluid texture.
	var viewport_size := get_viewport().get_visible_rect().size
	sub_viewport_container.position = Vector2.ZERO
	sub_viewport_container.rotation = 0.0
	sub_viewport_container.scale = Vector2.ONE
	sub_viewport_container.size = viewport_size
	sub_viewport.size = Vector2i(viewport_size)


func _mirror_camera() -> void:
	if camera == null:
		return
	inside_camera.anchor_mode = camera.anchor_mode
	inside_camera.ignore_rotation = camera.ignore_rotation
	inside_camera.offset = camera.offset
	inside_camera.zoom = camera.zoom
	inside_camera.global_transform = camera.global_transform
