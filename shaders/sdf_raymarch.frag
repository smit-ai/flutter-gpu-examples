#version 460 core

layout(location = 0) in vec2 fragTexCoord;
layout(location = 1) in vec3 rayDir;

layout(location = 0) out vec4 fragColor;

uniform SceneInfo {
    vec4 cameraPos;
    vec4 resolution;
    vec4 animData; // time, smoothUnionK, isRigidMode, metaballCount
    vec4 metaballs[16 * 2]; // position+radius, color+temperature for each
} sceneInfo;

// SDF for sphere
float sdSphere(vec3 p, vec3 center, float radius) {
    return length(p - center) - radius;
}

// Smooth union operation for metaballs
float smoothUnion(float d1, float d2, float k) {
    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

// Scene SDF - combines all metaballs
float sceneSDF(vec3 p) {
    float result = 1000.0;
    int count = int(sceneInfo.animData.w);
    
    for (int i = 0; i < count && i < 16; i++) {
        vec3 center = sceneInfo.metaballs[i * 2].xyz;
        float radius = sceneInfo.metaballs[i * 2].w;
        
        if (radius > 0.0) {
            float sphereDist = sdSphere(p, center, radius);
            
            if (sceneInfo.animData.z > 0.5) {
                // Rigid mode - simple union
                result = min(result, sphereDist);
            } else {
                // Soft mode - smooth union
                result = smoothUnion(result, sphereDist, sceneInfo.animData.y);
            }
        }
    }
    
    // Add floor
    float floorDist = p.y + 2.0;
    result = min(result, floorDist);
    
    return result;
}

// Calculate normal using gradient
vec3 calculateNormal(vec3 p) {
    const float eps = 0.001;
    return normalize(vec3(
        sceneSDF(p + vec3(eps, 0, 0)) - sceneSDF(p - vec3(eps, 0, 0)),
        sceneSDF(p + vec3(0, eps, 0)) - sceneSDF(p - vec3(0, eps, 0)),
        sceneSDF(p + vec3(0, 0, eps)) - sceneSDF(p - vec3(0, 0, eps))
    ));
}

// Get color for point based on nearest metaball
vec3 getMetaballColor(vec3 p) {
    float minDist = 1000.0;
    vec3 color = vec3(0.5, 0.5, 0.8);
    int count = int(sceneInfo.animData.w);
    
    for (int i = 0; i < count && i < 16; i++) {
        vec3 center = sceneInfo.metaballs[i * 2].xyz;
        float radius = sceneInfo.metaballs[i * 2].w;
        
        if (radius > 0.0) {
            float dist = length(p - center);
            if (dist < minDist) {
                minDist = dist;
                vec3 baseColor = sceneInfo.metaballs[i * 2 + 1].xyz;
                float temperature = sceneInfo.metaballs[i * 2 + 1].w;
                
                // Add temperature effect for soft bodies
                if (sceneInfo.animData.z < 0.5) {
                    color = mix(baseColor, vec3(1.0, 0.3, 0.1), temperature * 0.5);
                } else {
                    color = baseColor;
                }
            }
        }
    }
    
    return color;
}

// Simple lighting
vec3 lighting(vec3 p, vec3 normal, vec3 rayDir, vec3 color) {
    vec3 lightPos = vec3(5.0, 10.0, 5.0);
    vec3 lightDir = normalize(lightPos - p);
    
    // Ambient
    vec3 ambient = color * 0.2;
    
    // Diffuse
    float diff = max(dot(normal, lightDir), 0.0);
    vec3 diffuse = color * diff * 0.8;
    
    // Specular
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(-rayDir, reflectDir), 0.0), 32.0);
    vec3 specular = vec3(1.0) * spec * 0.3;
    
    return ambient + diffuse + specular;
}

void main() {
    vec3 rayOrigin = sceneInfo.cameraPos.xyz;
    vec3 rayDirection = normalize(rayDir);
    
    // Ray marching
    float t = 0.0;
    const int maxSteps = 100;
    const float maxDist = 50.0;
    const float epsilon = 0.001;
    
    for (int i = 0; i < maxSteps; i++) {
        vec3 p = rayOrigin + t * rayDirection;
        float dist = sceneSDF(p);
        
        if (dist < epsilon) {
            // Hit surface
            vec3 normal = calculateNormal(p);
            vec3 color = getMetaballColor(p);
            
            // Special floor coloring
            if (p.y < -1.9) {
                color = vec3(0.3, 0.3, 0.4);
            }
            
            vec3 finalColor = lighting(p, normal, rayDirection, color);
            
            // Add some atmospheric perspective
            float fog = 1.0 - exp(-t * 0.02);
            finalColor = mix(finalColor, vec3(0.02, 0.02, 0.05), fog);
            
            fragColor = vec4(finalColor, 1.0);
            return;
        }
        
        if (t > maxDist) break;
        
        t += dist;
    }
    
    // Background
    vec2 uv = fragTexCoord;
    vec3 bgColor = mix(vec3(0.02, 0.02, 0.05), vec3(0.05, 0.05, 0.1), uv.y);
    fragColor = vec4(bgColor, 1.0);
}