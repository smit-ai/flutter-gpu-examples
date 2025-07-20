// File: shaders/game_scene_interactive.vert
#version 320 es

uniform FrameInfo {
  mat4 mvp;
  float time;
  // State: 0.0=Alive. >0.0=Dying (value is animation progress 0-1)
  float anim_state; 
} frame_info;

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec4 color;

out vec3 v_normal;
out vec4 v_color;

void main() {
  vec3 final_pos = position;
  vec4 final_color = color;

  if (frame_info.anim_state == 0.0) {
    // --- ALIVE STATE: Bobbing Animation ---
    // This is a simplified version of the world animation.
    // The y-offset is calculated from the UN-TRANSFORMED position.
    final_pos.y += 0.25 * sin(position.x + position.z + frame_info.time * 2.0);
  } else {
    // --- DYING STATE: Shrink and Fade Animation ---
    float scale = 1.0 - frame_info.anim_state; // Scale from 1 to 0
    final_pos *= scale; // Shrink the cube
    final_color.a *= scale; // Fade the cube's alpha
  }

  // Final calculations
  gl_Position = frame_info.mvp * vec4(final_pos, 1.0);
  v_normal = normal;
  v_color = final_color;
}