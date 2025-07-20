// File: shaders/game_scene.frag
#version 320 es
precision mediump float;

uniform LightInfo {
  vec3 light_direction;
  vec4 light_color;
  vec4 ambient_color;
} light_info;

in vec3 v_normal;
in vec4 v_color;

out vec4 frag_color;

void main() {
  vec3 normal = normalize(v_normal);
  vec3 light_dir = normalize(light_info.light_direction);
  float diffuse_intensity = max(dot(normal, light_dir), 0.0);
  vec4 diffuse_color = diffuse_intensity * light_info.light_color;
  frag_color = (light_info.ambient_color + diffuse_color) * v_color;
}

/*// shaders/scene.frag
#version 320 es
precision mediump float;

uniform LightInfo {
  vec3 light_direction;
  vec4 light_color;
  vec4 ambient_color;
} light_info;

in vec3 v_world_position;
in vec3 v_normal;
in vec4 v_color; // NEW: Accept color from the vertex shader

out vec4 frag_color;

void main() {
  vec3 normal = normalize(v_normal);
  vec3 light_dir = normalize(light_info.light_direction);

  float diffuse_intensity = max(dot(normal, light_dir), 0.0);
  vec4 diffuse_color = diffuse_intensity * light_info.light_color;

  // MODIFIED: Use v_color instead of a hardcoded object_color
  frag_color = (light_info.ambient_color + diffuse_color) * v_color;
}

// shaders/scene.frag
#version 320 es
precision mediump float;

// Uniforms for lighting information
uniform LightInfo {
  vec3 light_direction;
  vec4 light_color;
  vec4 ambient_color;
} light_info;

// Inputs from the vertex shader
in vec3 v_world_position;
in vec3 v_normal;

// Output color
out vec4 frag_color;

void main() {
  // Normalize the inputs
  vec3 normal = normalize(v_normal);
  vec3 light_dir = normalize(light_info.light_direction);

  // Calculate the diffuse intensity.
  // The dot product gives us the cosine of the angle between the light and the normal.
  // max(..., 0.0) ensures that we don't have negative light on the back side of the object.
  float diffuse_intensity = max(dot(normal, light_dir), 0.0);

  // Calculate the final diffuse color
  vec4 diffuse_color = diffuse_intensity * light_info.light_color;

  // The final color is a combination of ambient light (so objects are never pure black)
  // and the calculated diffuse light. We'll use a hardcoded object color for now.
  vec4 object_color = vec4(0.6, 0.6, 0.6, 1.0);
  frag_color = (light_info.ambient_color + diffuse_color) * object_color;
}
*/