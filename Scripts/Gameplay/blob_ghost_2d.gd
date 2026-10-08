class_name BlobGhost2D
extends CanvasGroup
## Translucent preview of a mud blob. Its particles are drawn as one merged
## silhouette with a rim: the CanvasGroup flattens overlapping circles, so the
## shape reads as a single blob instead of a cluster of dots.

@export var valid_color := Color(0.95, 0.65, 0.35)
@export var invalid_color := Color(0.55, 0.5, 0.5)
@export var rim_color := Color(1.0, 0.9, 0.7)
@export_range(0.0, 1.0) var opacity := 0.45
## Drawn particle radius relative to the physics radius. The rendered mud
## looks bigger than its particles, so the ghost does too.
@export_range(0.5, 3.0, 0.05) var particle_scale := 2.0
@export_range(0.0, 20.0) var rim_width := 5.0
## Breathing speed, in cycles per second.
@export var pulse_speed := 1.2

## Particle positions, local to the ghost (see MudBurst2D.get_particle_offsets).
var offsets := PackedVector2Array():
	set(value):
		offsets = value
		_shape.queue_redraw()

## Whether the blob would fit where the ghost is. Picks the color.
var is_valid := true

var _shape := Node2D.new()
var _time := 0.0


func _ready() -> void:
	_shape.draw.connect(_draw_shape)
	add_child(_shape)


func _process(delta: float) -> void:
	_time += delta
	var breathing := 0.5 + 0.5 * sin(_time * TAU * pulse_speed)
	var alpha := opacity * lerpf(0.75, 1.0, breathing)
	self_modulate = Color(valid_color, alpha) if is_valid else Color(invalid_color, alpha * 0.6)


## A quick squash when the blob manifests.
func pulse() -> void:
	var tween := create_tween()
	tween.tween_property(_shape, "scale", Vector2.ONE * 0.8, 0.05)
	tween.tween_property(_shape, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw_shape() -> void:
	var radius := MudFluid2D.particle_radius() * particle_scale
	# Rim first, the body on top: what stays visible of the rim is the outline
	# of the whole blob.
	for offset in offsets:
		_shape.draw_circle(offset, radius + rim_width, rim_color)
	for offset in offsets:
		_shape.draw_circle(offset, radius, Color.WHITE)
