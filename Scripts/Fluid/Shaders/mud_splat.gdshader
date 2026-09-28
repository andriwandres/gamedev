shader_type canvas_item;
render_mode blend_add, unshaded;

// Drawn once per particle: a soft disc of the mud texture, sampled around the
// particle's material coordinate (where it was spawned). The discs are summed
// in an HDR viewport, and mud_surface.gdshader divides by the summed weight to
// get the blended value back. The texture therefore moves with the particles.
//
// blend_add scales color and alpha by the source alpha, so writing
// alpha = sqrt(weight) accumulates rgb += value * weight and a += weight.

// false: albedo pass (rgb = albedo). true: detail pass (r = height, g = AO).
uniform bool output_detail = false;
uniform sampler2D albedo_map : repeat_enable, filter_linear_mipmap;
uniform sampler2D height_map : repeat_enable, filter_linear_mipmap;
uniform sampler2D ao_map : repeat_enable, filter_linear_mipmap, hint_default_white;
// 2D units covered by one texture repeat.
uniform float tile_size = 128.0;
// Radius of each particle's disc in 2D units. Must match the instance scale.
uniform float splat_radius = 80.0;

varying vec2 material_uv;

void vertex() {
	// INSTANCE_CUSTOM.xy holds the particle's material coordinate.
	vec2 offset = (UV - 0.5) * 2.0 * splat_radius;
	material_uv = (INSTANCE_CUSTOM.xy + offset) / tile_size;
}

void fragment() {
	vec2 from_center = (UV - 0.5) * 2.0;
	float weight = max(1.0 - dot(from_center, from_center), 0.0);
	weight *= weight;

	vec3 value;
	if (output_detail) {
		value = vec3(texture(height_map, material_uv).r, texture(ao_map, material_uv).r, 0.0);
	} else {
		value = texture(albedo_map, material_uv).rgb;
	}
	COLOR = vec4(value, sqrt(weight));
}
