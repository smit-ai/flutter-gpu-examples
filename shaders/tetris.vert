// File: shaders/tetris.vert
#version 320 es

// Uniforms updated once per object draw call
uniform FrameInfo {
  mat4 mvp;
  mat4 model_matrix; // For transforming the normal
} frame_info;

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;

out vec3 v_normal; // Pass the transformed normal to the fragment shader

void main() {
  gl_Position = frame_info.mvp * vec4(position, 1.0);
  // Transform normal to world space for correct lighting
  v_normal = (frame_info.model_matrix * vec4(normal, 0.0)).xyz;
}