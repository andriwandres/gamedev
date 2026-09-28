class_name OutlineDistanceMap
extends RefCounted
## Bakes how far each point inside a polygon is from its outline into a small
## texture, plus the per-vertex UVs that map the polygon onto it. Terrain uses it
## to round off its edges in terrain_surface.gdshader.

## Texel size in 2D units for small polygons. Large ones use bigger texels so
## baking stays fast; linear filtering keeps the distances smooth.
const MIN_TEXEL_SIZE := 4.0
const MAX_TEXELS_PER_SIDE := 160.0

var texture: ImageTexture
## UV of every polygon vertex, in texels, as Polygon2D.uv expects.
var uv: PackedVector2Array


## `max_distance` is the distance a full texel value stands for.
static func bake(outline: PackedVector2Array, max_distance: float) -> OutlineDistanceMap:
	var result := OutlineDistanceMap.new()
	if outline.size() < 3:
		return result

	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		bounds = bounds.expand(point)
	var texel_size := maxf(MIN_TEXEL_SIZE, maxf(bounds.size.x, bounds.size.y) / MAX_TEXELS_PER_SIDE)
	# A blank border keeps the outline at distance 0, even with linear filtering.
	bounds = bounds.grow(texel_size)
	var texels := Vector2i((bounds.size / texel_size).ceil())

	var image := Image.create(texels.x, texels.y, false, Image.FORMAT_R8)
	for y in texels.y:
		for x in texels.x:
			var point := bounds.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * texel_size
			if Geometry2D.is_point_in_polygon(point, outline):
				var distance := _distance_to_outline(point, outline)
				image.set_pixel(x, y, Color(minf(distance / max_distance, 1.0), 0.0, 0.0))
	result.texture = ImageTexture.create_from_image(image)

	for point in outline:
		result.uv.append((point - bounds.position) / texel_size)
	return result


static func _distance_to_outline(point: Vector2, outline: PackedVector2Array) -> float:
	var closest := INF
	for i in outline.size():
		var start := outline[i]
		var end := outline[(i + 1) % outline.size()]
		closest = minf(closest, point.distance_to(Geometry2D.get_closest_point_to_segment(point, start, end)))
	return closest
