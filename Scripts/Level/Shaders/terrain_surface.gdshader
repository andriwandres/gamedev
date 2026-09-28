shader_type canvas_item;

#include "res://Scripts/Shaders/lighting_2d.gdshaderinc"

// Textured, lit terrain. The textures are placed in world space: the pattern
// stays put when a piece is moved and lines up seamlessly where pieces touch.
//
// TEXTURE is the piece's edge map, baked by Terrain2D: r = distance to the
// outline / max_edge_distance. The rock rises over bevel_width from its outline,
// the height texture adds relief on top, and the slope of that height field is
// the normal used for lighting.

uniform sampler2D albedo_map : repeat_enable, filter_linear_mipmap;
uniform sampler2D height_map : repeat_enable, filter_linear_mipmap;
uniform sampler2D ao_map : repeat_enable, filter_linear_mipmap, hint_default_white;
// 2D units covered by one texture repeat.
uniform float tile_size = 256.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float ao_strength = 0.8;

// Distance in 2D units that an edge map value of 1 stands for.
uniform float max_edge_distance = 64.0;
uniform float bevel_width = 18.0;
uniform float bevel_height = 10.0;
uniform float detail_height = 4.0;
// How much the rock darkens towards its outline.
uniform float edge_darkening = 0.35;

uniform float wetness = 0.08;
uniform float shininess = 16.0;

// Distance between the height samples used for the normal, in 2D units.
const float NORMAL_SPAN = 2.0;
const float HALF_PI = 1.5707963;

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// 0 on the outline, rising in a rounded profile to 1 at bevel_width inside.
// edge_value is a sample of the edge map (TEXTURE).
float bevel(float edge_value) {
	float distance_to_outline = edge_value * max_edge_distance;
	return sin(clamp(distance_to_outline / bevel_width, 0.0, 1.0) * HALF_PI);
}

float surface_height(float edge_value, vec2 world) {
	float relief = texture(height_map, world / tile_size).r;
	return bevel(edge_value) * bevel_height + relief * detail_height;
}

void fragment() {
	// Edge map UVs are local to the piece, heights are sampled in world space.
	// Both are affine on screen, so this ratio is exact and also covers
	// rotated pieces.
	mat2 uv_per_screen = mat2(dFdx(UV), dFdy(UV));
	mat2 world_per_screen = mat2(dFdx(world_position), dFdy(world_position));
	mat2 uv_per_world = uv_per_screen * inverse(world_per_screen);

	vec2 step_x = vec2(NORMAL_SPAN * 0.5, 0.0);
	vec2 step_y = vec2(0.0, NORMAL_SPAN * 0.5);
	// TEXTURE can't be handed to functions in canvas shaders, so sample it here.
	float left = surface_height(texture(TEXTURE, UV - uv_per_world * step_x).r, world_position - step_x);
	float right = surface_height(texture(TEXTURE, UV + uv_per_world * step_x).r, world_position + step_x);
	float up = surface_height(texture(TEXTURE, UV - uv_per_world * step_y).r, world_position - step_y);
	float down = surface_height(texture(TEXTURE, UV + uv_per_world * step_y).r, world_position + step_y);
	vec3 normal = normal_from_heights(left, right, up, down, NORMAL_SPAN);

	vec2 tile_uv = world_position / tile_size;
	vec3 albedo = texture(albedo_map, tile_uv).rgb * tint.rgb;
	float ao = mix(1.0, texture(ao_map, tile_uv).r, ao_strength);
	float outline_shade = mix(1.0 - edge_darkening, 1.0, bevel(texture(TEXTURE, UV).r));

	// The node's own color is ignored on purpose: the surface decides the look.
	vec3 lit = light_surface_2d(albedo * ao * outline_shade, normal, wetness, shininess);
	COLOR = vec4(lit, tint.a);
}
