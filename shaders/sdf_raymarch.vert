#version 460 core

layout(location = 0) in vec2 position;
layout(location = 1) in vec2 texCoord;

layout(location = 0) out vec2 fragTexCoord;
layout(location = 1) out vec3 rayDir;

uniform SceneInfo {
    vec4 cameraPos;
    vec4 resolution;
    vec4 animData; // time, smoothUnionK, isRigidMode, metaballCount
    vec4 metaballs[16 * 2]; // position+radius, color+temperature for each
} sceneInfo;

void main() {
    gl_Position = vec4(position, 0.0, 1.0);
    fragTexCoord = texCoord;
    
    // Calculate ray direction for ray marching
    vec2 screenPos = (texCoord * 2.0 - 1.0);
    screenPos.x *= sceneInfo.resolution.x / sceneInfo.resolution.y;
    
    // Simple camera setup - looking at origin
    vec3 cameraTarget = vec3(0.0, 0.0, 0.0);
    vec3 cameraUp = vec3(0.0, 1.0, 0.0);
    
    vec3 forward = normalize(cameraTarget - sceneInfo.cameraPos.xyz);
    vec3 right = normalize(cross(forward, cameraUp));
    vec3 up = cross(right, forward);
    
    rayDir = normalize(forward + screenPos.x * right + screenPos.y * up);
}