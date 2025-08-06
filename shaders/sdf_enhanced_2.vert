#version 460 core

layout(location = 0) in vec2 position;
layout(location = 1) in vec2 texCoord;

layout(location = 0) out vec2 fragTexCoord;
layout(location = 1) out vec3 rayDir;

uniform SceneInfo {
    vec4 cameraPos;
    vec4 resolution;
    vec4 animData; // time, smoothUnionK, isRigidMode, metaballCount
    vec4 worldRotation; // x, y, z rotations
    vec4 metaballs[32 * 2]; // position+radius, color+temperature for each (increased capacity)
} sceneInfo;

void main() {
    gl_Position = vec4(position, 0.0, 1.0);
    fragTexCoord = texCoord;

    // Calculate ray direction for ray marching with world rotation
    vec2 screenPos = (texCoord * 2.0 - 1.0);
    screenPos.x *= sceneInfo.resolution.x / sceneInfo.resolution.y;

    // Apply world rotation to camera
    float cosY = cos(sceneInfo.worldRotation.y);
    float sinY = sin(sceneInfo.worldRotation.y);
    float cosX = cos(sceneInfo.worldRotation.x);
    float sinX = sin(sceneInfo.worldRotation.x);

    // Camera setup with rotation
    vec3 cameraTarget = vec3(0.0, 0.0, 0.0);
    vec3 cameraUp = vec3(0.0, 1.0, 0.0);

    vec3 forward = normalize(cameraTarget - sceneInfo.cameraPos.xyz);
    vec3 right = normalize(cross(forward, cameraUp));
    vec3 up = cross(right, forward);

    // Apply rotations
    vec3 rotatedForward = vec3(
        forward.x * cosY - forward.z * sinY,
        forward.y * cosX - (forward.x * sinY + forward.z * cosY) * sinX,
        forward.y * sinX + (forward.x * sinY + forward.z * cosY) * cosX
    );

    vec3 rotatedRight = vec3(
        right.x * cosY - right.z * sinY,
        right.y * cosX - (right.x * sinY + right.z * cosY) * sinX,
        right.y * sinX + (right.x * sinY + right.z * cosY) * cosX
    );

    vec3 rotatedUp = vec3(
        up.x * cosY - up.z * sinY,
        up.y * cosX - (up.x * sinY + up.z * cosY) * sinX,
        up.y * sinX + (up.x * sinY + up.z * cosY) * cosX
    );

    rayDir = normalize(rotatedForward + screenPos.x * rotatedRight + screenPos.y * rotatedUp);
}