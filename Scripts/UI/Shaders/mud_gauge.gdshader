shader_type canvas_item;

#include "res://Scripts/Shaders/lighting_2d.gdshaderinc"

// A glass tube filled with mud, for the HUD. The mud uses the same texture as
// the mud in the level and is lit by the shared 2D light as a cylinder, so it
// reads as the same material. Its surface waves gently and sloshes when the
// fill changes (see MudGauge).

// Size of the gauge in pixels; set by MudGauge.
uniform vec2 rect_size = vec2(44.0, 220.0);
uniform float fill : hint_range(0.0, 1.0) = 1.0;
// Extra surface motion from recent changes. 0 = calm, 1 = full slosh.
uniform float slosh : hint_range(0.0, 1.0) = 0.0;

group_uniforms mud;
uniform sampler2D mud_albedo : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 mud_tint : source_color = vec4(1.0);
// Pixels per texture repeat.
uniform float texture_tile = 90.0;
// How fast the mud churns upwards, in pixels per second.
uniform float churn_speed = 5.0;
// How much darker the mud gets towards the bottom.
uniform float depth_darkening : hint_range(0.0, 1.0) = 0.35;
uniform vec4 surface_color : source_color = vec4(1.0, 0.82, 0.6, 1.0);
uniform float wetness = 0.6;
uniform float shininess = 40.0;

group_uniforms waves;
uniform float wave_height = 1.2;
uniform float wave_length = 30.0;
uniform float wave_speed = 2.2;
// Wave height added at full slosh.
uniform float slosh_height = 6.0;

group_uniforms bubbles;
uniform int bubble_count : hint_range(0, 16) = 5;
uniform float bubble_radius = 2.2;
// Pixels per second.
uniform float bubble_speed = 22.0;

group_uniforms glass;
uniform vec4 glass_color : source_color = vec4(0.7, 0.82, 0.88, 0.22);
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 0.6);
uniform float wall_thickness = 3.0;
group_uniforms;

float hash(float n) {
	return fract(sin(n * 91.3458) * 47453.5453);
}

// Signed distance to a rounded box centered on the origin.
float rounded_box(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

// Height of the mud surface (y down) at x, in pixels.
float surface_y(float x, float across, float top, float bottom) {
	float height = wave_height + slosh * slosh_height;
	float phase = x / wave_length * TAU;
	float waves = sin(phase + TIME * wave_speed) + 0.5 * sin(phase * 1.7 - TIME * wave_speed * 1.3);
	// Sloshing also tilts the surface back and forth.
	float tilt = slosh * slosh_height * sin(TIME * 7.0) * across;
	return mix(bottom, top, fill) + waves * height + tilt;
}

// 1 inside one of the bubbles rising from the bottom to the surface.
float bubbles(vec2 p, float surface, float bottom) {
	float inside = 0.0;
	float span = max(bottom - surface, 1.0);
	for (int i = 0; i < bubble_count; i++) {
		float seed = float(i) + 1.0;
		float x = mix(wall_thickness * 2.0, rect_size.x - wall_thickness * 2.0, hash(seed));
		float speed = bubble_speed * mix(0.6, 1.4, hash(seed * 7.7));
		float rise = fract(hash(seed * 3.1) + TIME * speed / span);
		vec2 center = vec2(x + sin(TIME * 3.0 + seed) * 1.5, bottom - rise * span);
		inside += 1.0 - smoothstep(bubble_radius - 0.75, bubble_radius + 0.75, distance(p, center));
	}
	return clamp(inside, 0.0, 1.0);
}

void fragment() {
	vec2 p = UV * rect_size;
	vec2 center = rect_size * 0.5;
	float outline = rounded_box(p - center, center, center.x);
	float shape = 1.0 - smoothstep(-1.0, 0.0, outline);
	if (shape <= 0.0) {
		discard;
	}
	// -1 at the left wall, 1 at the right.
	float across = (p.x - center.x) / center.x;
	float inside_glass = smoothstep(0.0, 1.0, -outline - wall_thickness);

	float top = wall_thickness;
	float bottom = rect_size.y - wall_thickness;
	float surface = surface_y(p.x, across, top, bottom);
	float mud = fill > 0.001 ? smoothstep(surface - 0.75, surface + 0.75, p.y) * inside_glass : 0.0;

	// The tube is a cylinder: its normal turns away from the viewer at the sides.
	float side = clamp(across * 0.85, -0.99, 0.99);
	vec3 normal = normalize(vec3(side, 0.0, sqrt(1.0 - side * side)));

	vec2 texture_position = (p + vec2(0.0, TIME * churn_speed)) / texture_tile;
	vec3 albedo = texture(mud_albedo, texture_position).rgb * mud_tint.rgb;
	float depth = clamp((p.y - surface) / rect_size.y, 0.0, 1.0);
	albedo *= 1.0 - depth_darkening * depth;
	// A thin lighter band where the mud meets the air.
	float meniscus = 1.0 - smoothstep(0.0, 3.0, p.y - surface);
	albedo = mix(albedo, surface_color.rgb, meniscus * 0.6);
	albedo = mix(albedo, surface_color.rgb, bubbles(p, surface, bottom) * 0.5);
	vec3 mud_color = light_surface_2d(albedo, normal, wetness, shininess);

	vec3 color = mix(glass_color.rgb, mud_color, mud);
	float alpha = mix(glass_color.a, 1.0, mud);

	// Glass: a bright rim and a vertical reflection on the left.
	float rim = 1.0 - smoothstep(0.0, wall_thickness + 1.0, -outline);
	float reflection = exp(-pow((across + 0.45) / 0.12, 2.0)) * 0.35;
	color = mix(color, rim_color.rgb, rim * rim_color.a);
	color += vec3(reflection);
	alpha = max(alpha, max(rim * rim_color.a, reflection));

	COLOR = vec4(color, alpha * shape);
}
