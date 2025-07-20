// File: shaders/raymarch_vertex.vert
#version 320 es

uniform Uniforms {
    vec3 iResolution;
    float iTime;
} frame;

out vec2 v_uv;

void main() {
  vec2 positions[3] = vec2[](
    vec2(-1.0, -1.0),
    vec2( 3.0, -1.0),
    vec2(-1.0,  3.0)
  );
  
  // FINAL, ABSOLUTE FIX: Use gl_VertexIndex as required by your compiler version.
  gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
  
  v_uv = gl_Position.xy;
}