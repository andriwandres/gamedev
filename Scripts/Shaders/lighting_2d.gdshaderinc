// One light for everything drawn in the 2D world, so mud and terrain agree.
// Tweak it in Project Settings > Shader Globals, or at runtime with
// RenderingServer.global_shader_parameter_set().

// Direction towards the light: x right, y down the screen, z out of the screen.
global uniform vec3 light_direction_2d;
// Share of the light that reaches surfaces facing away from it.
global uniform float ambient_light_2d;

// Normal of a height field from central differences. Heights and span are in
// the same units (2D pixels), span being the distance between left and right.
vec3 normal_from_heights(float left, float right, float up, float down, float span) {
	return normalize(vec3(left - right, up - down, span));
}

vec3 light_surface_2d(vec3 albedo, vec3 normal, float wetness, float shininess) {
	vec3 to_light = normalize(light_direction_2d);
	vec3 halfway = normalize(to_light + vec3(0.0, 0.0, 1.0));
	float diffuse = ambient_light_2d + (1.0 - ambient_light_2d) * max(dot(normal, to_light), 0.0);
	float specular = wetness * pow(max(dot(normal, halfway), 0.0), shininess);
	return albedo * diffuse + vec3(specular);
}
