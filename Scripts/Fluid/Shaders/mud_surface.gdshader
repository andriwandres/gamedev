shader_type canvas_item;

#include "res://Scripts/Shaders/lighting_2d.gdshaderinc"

// Turns the summed particle splats (see mud_splat.gdshader) into a lit mud
// surface. TEXTURE is the albedo pass: rgb = sum(albedo * w), a = sum(w).
// detail_pass has the same layout with r = height and g = ambient occlusion.
//
// The summed weight doubles as fluid thickness: thick mud bulges up, thin mud
// stays flat. Together with the texture's height this gives a height field,
// whose slope becomes the normal used for lighting.

uniform sampler2D detail_pass : filter_linear;

// Summed weight at which the mud's edge sits.
uniform float threshold = 0.7;
uniform float edge_softness = 0.08;

uniform vec4 tint : source_color = vec4(1.0);
uniform float ao_strength = 0.8;
uniform float edge_darkening = 0.45;

uniform float bulge_height = 10.0;
uniform float bulge_range = 2.5;
uniform float detail_height = 3.0;

uniform float wetness = 0.35;
uniform float shininess = 48.0;

const float EPSILON = 1e-4;

// 0 at the mud's edge, 1 where it is thick enough to be fully bulged.
float body(float weight) {
	return smoothstep(threshold, threshold + bulge_range, weight);
}

float surface_height(sampler2D albedo_pass, vec2 uv) {
	vec4 detail = texture(detail_pass, uv);
	float weight = texture(albedo_pass, uv).a;
	float relief = detail.r / max(detail.a, EPSILON);
	return body(weight) * (bulge_height + relief * detail_height);
}

vec3 surface_normal(sampler2D albedo_pass, vec2 uv, vec2 pixel) {
	float left = surface_height(albedo_pass, uv - vec2(pixel.x, 0.0));
	float right = surface_height(albedo_pass, uv + vec2(pixel.x, 0.0));
	float up = surface_height(albedo_pass, uv - vec2(0.0, pixel.y));
	float down = surface_height(albedo_pass, uv + vec2(0.0, pixel.y));
	// Central differences span two pixels, heights are in pixels.
	return normal_from_heights(left, right, up, down, 2.0);
}

void fragment() {
	vec4 albedo_sum = texture(TEXTURE, UV);
	float weight = albedo_sum.a;
	float coverage = smoothstep(threshold - edge_softness, threshold + edge_softness, weight);
	if (coverage <= 0.0) {
		discard;
	}

	vec3 albedo = albedo_sum.rgb / max(weight, EPSILON) * tint.rgb;
	vec4 detail_sum = texture(detail_pass, UV);
	float ao = mix(1.0, detail_sum.g / max(detail_sum.a, EPSILON), ao_strength);
	float thin_mud_shade = mix(1.0 - edge_darkening, 1.0, body(weight));

	vec3 normal = surface_normal(TEXTURE, UV, TEXTURE_PIXEL_SIZE);
	vec3 lit = light_surface_2d(albedo * ao * thin_mud_shade, normal, wetness, shininess);
	COLOR = vec4(lit, coverage * tint.a);
}
