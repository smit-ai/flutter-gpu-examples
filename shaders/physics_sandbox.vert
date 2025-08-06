// File: shaders/physics_sandbox.vert (FINAL, WORKING VERSION)
#version 320 es

uniform FrameInfo {
  mat4 mvp;
  mat4 model_matrix;
  float time;
  float physics_mode;
} frame_info;

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec4 color;

out vec3 v_normal;
out vec4 v_color;

// Simple random function using vertex position as a seed
float random (vec3 st) {
    return fract(sin(dot(st.xyz, vec3(12.9898,78.233,45.5432))) * 43758.5453123);
}

void main() {
  vec3 final_pos = position;
  vec3 final_normal = normal;
  v_color = color;

  // FIX: Access the uniform variables via the 'frame_info' instance name.
  if (frame_info.physics_mode == 0.0) {
    // --- RIGID BODY STATE ---
    // Do nothing.

  } else if (frame_info.physics_mode == 1.0) {
    // --- SOFT BODY (JIGGLY) STATE ---
    // FIX: Access 'time' via 'frame_info.time'.
    float displacement = 0.15 * sin(position.y * 5.0 + frame_info.time * 10.0);
    final_pos += normal * displacement;

  } else {
    // --- EXPLODING (PARTICLE) STATE ---
    // FIX: Access 'time' and 'physics_mode' via 'frame_info'.
    float time_since_explosion = frame_info.time - frame_info.physics_mode;
    
    if (time_since_explosion > 0.0) {
        vec3 initial_velocity = normalize(normal + vec3(random(position), random(position*0.5), random(position*0.3))) * 5.0;
        
        float gravity = 9.8;
        final_pos += initial_velocity * time_since_explosion;
        final_pos.y -= 0.5 * gravity * time_since_explosion * time_since_explosion;

        v_color.a = max(0.0, 1.0 - time_since_explosion / 2.0);
    }
  }

  gl_Position = frame_info.mvp * vec4(final_pos, 1.0);
  v_normal = (frame_info.model_matrix * vec4(final_normal, 0.0)).xyz;
}