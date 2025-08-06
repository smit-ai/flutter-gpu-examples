// File: shaders/tetris.frag
#version 320 es
precision mediump float;

// Standard lighting info
uniform LightInfo {
  vec3 light_direction;
  vec4 light_color;
  vec4 ambient_color;
} light_info;

// NEW: A uniform block to receive the object's color
uniform ColorInfo {
  vec4 color;
} color_info;

in vec3 v_normal; // Comes from the vertex shader

out vec4 frag_color;

void main() {
  vec3 normal = normalize(v_normal);
  vec3 light_dir = normalize(light_info.light_direction);
  float diffuse_intensity = max(dot(normal, light_dir), 0.0);
  vec4 diffuse_color = diffuse_intensity * light_info.light_color;

  // Use the uniform color from the ColorInfo block
  frag_color = (light_info.ambient_color + diffuse_color) * color_info.color;
}