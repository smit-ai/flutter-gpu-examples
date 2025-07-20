// File: shaders/game_scene.vert
#version 320 es

uniform FrameInfo {
  mat4 mvp;
} frame_info;

// FINAL FIX: The shader inputs now perfectly match the Dart data structure.
// Layout location corresponds to the order in the buffer.
layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec4 color;

out vec3 v_normal;
out vec4 v_color;

void main() {
  gl_Position = frame_info.mvp * vec4(position, 1.0);
  v_normal = normal;
  v_color = color;
}

/*// shaders/scene.vert
#version 320 es

// Uniforms now include separate matrices for world transformation and camera view/projection.
uniform SceneInfo {
  mat4 mvp;         // Combined Model-View-Projection matrix
  mat4 model_matrix;  // Just the Model (object's world transform) matrix
} scene_info;

// Vertex attributes
in vec3 position;
in vec3 normal; // We now need normals for lighting

// Outputs to the fragment shader
out vec3 v_world_position;
out vec3 v_normal;

void main() {
  // Transform the vertex position to screen space
  gl_Position = scene_info.mvp * vec4(position, 1.0);

  // Transform the vertex and normal to world space for the fragment shader
  // to perform lighting calculations in a consistent coordinate system.
  v_world_position = (scene_info.model_matrix * vec4(position, 1.0)).xyz;
  v_normal = (scene_info.model_matrix * vec4(normal, 0.0)).xyz;
}*/