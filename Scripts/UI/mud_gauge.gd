class_name MudGauge
extends ColorRect
## A glass tube of mud showing how much is left. The level eases towards its
## new value and the surface sloshes when it changes. Draws with
## mud_gauge.gdshader, whose look is tweaked on this node's material.

## Fill to show, 0 to 1. Set with set_amount() or directly.
@export_range(0.0, 1.0) var value := 1.0
## How quickly the shown level catches up with `value`.
@export var settle_speed := 6.0
## How much a change sets the surface sloshing, per unit of fill change.
@export var slosh_per_change := 12.0
## How quickly the sloshing calms down.
@export var slosh_decay := 2.5

var _shown_fill := 1.0
var _slosh := 0.0


func set_amount(amount: int, capacity: int) -> void:
	value = clampf(float(amount) / capacity, 0.0, 1.0) if capacity > 0 else 0.0


func _process(delta: float) -> void:
	var previous_fill := _shown_fill
	_shown_fill = lerpf(_shown_fill, value, 1.0 - exp(-settle_speed * delta))
	_slosh = minf(_slosh * exp(-slosh_decay * delta) + absf(_shown_fill - previous_fill) * slosh_per_change, 1.0)
	var shader_material := material as ShaderMaterial
	if shader_material:
		shader_material.set_shader_parameter(&"rect_size", size)
		shader_material.set_shader_parameter(&"fill", _shown_fill)
		shader_material.set_shader_parameter(&"slosh", _slosh)
