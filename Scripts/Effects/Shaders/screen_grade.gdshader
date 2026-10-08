shader_type canvas_item;

#include "res://Scripts/Shaders/lighting_2d.gdshaderinc"

// Final look of the game, applied on top of everything below the HUD:
// drifting cloud shadows, warm sunlight from the shared 2D light direction,
// color grading (exposure, vibrance, saturation, contrast, split toning) and a
// lens finish (vignette, chromatic aberration, grain).
// Glow comes from the WorldEnvironment next to it (Assets/Effects/environment.tres).
// Set any strength to 0 to turn that effect off.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;

group_uniforms clouds;
// Grayscale noise, best seamless. Bright areas cast shadow.
uniform sampler2D cloud_noise : repeat_enable, filter_linear;
uniform float cloud_shadow_strength : hint_range(0.0, 1.0) = 0.2;
// Noise repeats per screen height.
uniform float cloud_scale = 0.8;
// Screen heights per second.
uniform vec2 cloud_velocity = vec2(0.01, 0.004);
// Share of the sky without clouds.
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_softness : hint_range(0.01, 0.5) = 0.15;

group_uniforms sunlight;
uniform vec4 sun_color : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform float sun_strength : hint_range(0.0, 1.0) = 0.25;
// How far the sunlight reaches into the screen, in screen heights.
uniform float sun_reach = 1.4;

group_uniforms color;
uniform float exposure : hint_range(0.0, 3.0) = 1.05;
// Boosts dull colors more than already colorful ones.
uniform float vibrance : hint_range(-1.0, 2.0) = 0.5;
uniform float saturation : hint_range(0.0, 3.0) = 1.15;
uniform float contrast : hint_range(0.0, 3.0) = 1.1;
// Overlay tints: 0.5 grey is neutral.
uniform vec4 shadow_tint : source_color = vec4(0.38, 0.45, 0.62, 1.0);
uniform vec4 highlight_tint : source_color = vec4(0.66, 0.56, 0.42, 1.0);
uniform float split_tone_strength : hint_range(0.0, 1.0) = 0.35;

group_uniforms lens;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.4;
// Distance from the center (1 = corner) where darkening is halfway.
uniform float vignette_radius : hint_range(0.0, 1.5) = 0.85;
uniform float vignette_softness : hint_range(0.01, 1.0) = 0.5;
// Color fringe at the corners, in pixels.
uniform float chromatic_aberration : hint_range(0.0, 10.0) = 1.5;
uniform float grain : hint_range(0.0, 0.3) = 0.03;
group_uniforms;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float luminance(vec3 color) {
	return dot(color, LUMA);
}

vec3 screen_blend(vec3 base, vec3 light) {
	return 1.0 - (1.0 - base) * (1.0 - light);
}

vec3 overlay_blend(vec3 base, vec3 tint) {
	vec3 dark = 2.0 * base * tint;
	vec3 bright = 1.0 - 2.0 * (1.0 - base) * (1.0 - tint);
	return mix(dark, bright, step(0.5, base));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Two noise layers drifting at different speeds, so clouds slowly change shape.
float cloud_shadow(vec2 view) {
	vec2 uv = view * cloud_scale;
	float near = texture(cloud_noise, uv + TIME * cloud_velocity).r;
	float far = texture(cloud_noise, uv * 0.6 - TIME * cloud_velocity * 0.4).r;
	float density = mix(near, far, 0.4);
	return smoothstep(cloud_coverage - cloud_softness, cloud_coverage + cloud_softness, density);
}

// Sunlight enters from outside the screen, from where the shared light shines.
float sunlight(vec2 view, float aspect) {
	vec2 center = vec2(aspect, 1.0) * 0.5;
	vec2 sun = center + normalize(light_direction_2d.xy) * length(center);
	float falloff = max(1.0 - distance(view, sun) / sun_reach, 0.0);
	return falloff * falloff;
}

vec3 grade(vec3 color) {
	color *= exposure;
	float luma = luminance(color);
	float chroma = max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b));
	color = mix(vec3(luma), color, 1.0 + vibrance * (1.0 - clamp(chroma, 0.0, 1.0)));
	color = mix(vec3(luminance(color)), color, saturation);
	color = (color - 0.5) * contrast + 0.5;
	color = clamp(color, 0.0, 1.0);
	vec3 tone = mix(shadow_tint.rgb, highlight_tint.rgb, smoothstep(0.0, 1.0, luminance(color)));
	return mix(color, overlay_blend(color, tone), split_tone_strength);
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	// Aspect-correct position: y spans 0..1, x spans 0..aspect.
	vec2 view = SCREEN_UV * vec2(aspect, 1.0);
	vec2 from_center = SCREEN_UV - 0.5;
	// 0 at the center, 1 in the corners.
	float edge = length(from_center * vec2(aspect, 1.0)) / length(vec2(aspect, 1.0) * 0.5);

	vec2 fringe = normalize(from_center + 1e-6) * edge * edge * chromatic_aberration * SCREEN_PIXEL_SIZE;
	vec3 color = vec3(
		texture(screen_texture, SCREEN_UV + fringe).r,
		texture(screen_texture, SCREEN_UV).g,
		texture(screen_texture, SCREEN_UV - fringe).b);

	color *= 1.0 - cloud_shadow(view) * cloud_shadow_strength;
	color = screen_blend(color, sun_color.rgb * sunlight(view, aspect) * sun_strength);
	color = grade(color);
	color *= 1.0 - vignette_strength * smoothstep(vignette_radius - vignette_softness, vignette_radius + vignette_softness, edge);

	// Grain is strongest in the midtones, like film.
	float noise = hash(floor(SCREEN_UV / SCREEN_PIXEL_SIZE) + fract(TIME) * 61.0) - 0.5;
	float midtones = 1.0 - abs(luminance(color) * 2.0 - 1.0);
	color += noise * grain * (0.5 + midtones);

	COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
