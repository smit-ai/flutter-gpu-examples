#version 460 core

layout(location = 0) in vec2 fragTexCoord;
layout(location = 1) in vec3 rayDir;

layout(location = 0) out vec4 fragColor;

uniform SceneInfo {
    vec4 cameraPos;
    vec4 resolution;
    vec4 animData; // time, smoothUnionK, isRigidMode, metaballCount
    vec4 worldRotation;
    vec4 metaballs[32 * 2]; // position+radius, color+temperature for each
} sceneInfo;

// Enhanced SDF for sphere with better precision
float sdSphere(vec3 p, vec3 center, float radius) {
    return length(p - center) - radius;
}

// Improved smooth union operation
float smoothUnion(float d1, float d2, float k) {
    if (k <= 0.0) return min(d1, d2);
    float h = max(k - abs(d1 - d2), 0.0) / k;
    return min(d1, d2) - h * h * h * k * (1.0/6.0);
}

// Enhanced scene SDF with better color blending
float sceneSDF(vec3 p, out vec3 color) {
    float result = 1000.0;
    color = vec3(0.5, 0.5, 0.8);
    vec3 blendedColor = vec3(0.0);
    float totalWeight = 0.0;
    
    int count = int(sceneInfo.animData.w);

    for (int i = 0; i < count && i < 32; i++) {
        vec3 center = sceneInfo.metaballs[i * 2].xyz;
        float radius = sceneInfo.metaballs[i * 2].w;

        if (radius > 0.0) {
            float sphereDist = sdSphere(p, center, radius);
            vec3 sphereColor = sceneInfo.metaballs[i * 2 + 1].xyz;
            
            // Weight based on distance for color blending
            float weight = 1.0 / (1.0 + sphereDist * sphereDist);
            blendedColor += sphereColor * weight;
            totalWeight += weight;

            if (sceneInfo.animData.z > 0.5) {
                // Rigid mode - simple union
                if (sphereDist < result) {
                    result = sphereDist;
                    color = sphereColor;
                }
            } else {
                // Soft mode - smooth union with color blending
                result = smoothUnion(result, sphereDist, sceneInfo.animData.y);
            }
        }
    }
    
    // Apply blended color in soft mode
    if (sceneInfo.animData.z < 0.5 && totalWeight > 0.0) {
        color = blendedColor / totalWeight;
    }

    // Enhanced floor with grid pattern
    float floorDist = p.y + 2.0;
    vec2 gridPos = p.xz;
    vec2 grid = abs(fract(gridPos) - 0.5);
    float gridLine = min(grid.x, grid.y);
    vec3 floorColor = mix(vec3(0.2, 0.2, 0.3), vec3(0.3, 0.3, 0.4), 
                         smoothstep(0.0, 0.1, gridLine));
    
    if (floorDist < result) {
        result = floorDist;
        color = floorColor;
    }

    return result;
}

// Enhanced normal calculation
vec3 calculateNormal(vec3 p) {
    const float eps = 0.0005;
    vec3 dummy;
    return normalize(vec3(
        sceneSDF(p + vec3(eps, 0, 0), dummy) - sceneSDF(p - vec3(eps, 0, 0), dummy),
        sceneSDF(p + vec3(0, eps, 0), dummy) - sceneSDF(p - vec3(0, eps, 0), dummy),
        sceneSDF(p + vec3(0, 0, eps), dummy) - sceneSDF(p - vec3(0, 0, eps), dummy)
    ));
}

// Enhanced lighting with multiple light sources
vec3 lighting(vec3 p, vec3 normal, vec3 rayDir, vec3 color) {
    // Primary light
    vec3 lightPos1 = vec3(5.0, 10.0, 5.0);
    vec3 lightDir1 = normalize(lightPos1 - p);
    
    // Secondary light
    vec3 lightPos2 = vec3(-3.0, 5.0, -3.0);
    vec3 lightDir2 = normalize(lightPos2 - p);

    // Ambient
    vec3 ambient = color * 0.15;

    // Diffuse from both lights
    float diff1 = max(dot(normal, lightDir1), 0.0);
    float diff2 = max(dot(normal, lightDir2), 0.0) * 0.5;
    vec3 diffuse = color * (diff1 * 0.7 + diff2 * 0.3);

    // Specular
    vec3 reflectDir1 = reflect(-lightDir1, normal);
    vec3 reflectDir2 = reflect(-lightDir2, normal);
    float spec1 = pow(max(dot(-rayDir, reflectDir1), 0.0), 64.0);
    float spec2 = pow(max(dot(-rayDir, reflectDir2), 0.0), 32.0) * 0.5;
    vec3 specular = vec3(1.0) * (spec1 * 0.4 + spec2 * 0.2);

    // Rim lighting
    float rim = 1.0 - max(dot(-rayDir, normal), 0.0);
    vec3 rimLight = color * pow(rim, 3.0) * 0.3;

    return ambient + diffuse + specular + rimLight;
}

void main() {
    vec3 rayOrigin = sceneInfo.cameraPos.xyz;
    vec3 rayDirection = normalize(rayDir);

    // Enhanced ray marching with adaptive step size
    float t = 0.0;
    const int maxSteps = 128;
    const float maxDist = 100.0;
    const float epsilon = 0.001;
    vec3 surfaceColor;

    for (int i = 0; i < maxSteps; i++) {
        vec3 p = rayOrigin + t * rayDirection;
        float dist = sceneSDF(p, surfaceColor);

        if (dist < epsilon) {
            // Hit surface - enhanced shading
            vec3 normal = calculateNormal(p);
            vec3 finalColor = lighting(p, normal, rayDirection, surfaceColor);

            // Enhanced atmospheric effects
            float fog = 1.0 - exp(-t * 0.015);
            vec3 fogColor = mix(vec3(0.02, 0.02, 0.05), vec3(0.1, 0.1, 0.2), 
                               fragTexCoord.y);
            finalColor = mix(finalColor, fogColor, fog);

            // Add subtle color temperature variation
            float temp = sin(sceneInfo.animData.x * 0.5) * 0.1 + 0.9;
            finalColor *= vec3(temp, 1.0, 1.0 / temp);

            fragColor = vec4(finalColor, 1.0);
            return;
        }

        if (t > maxDist) break;

        // Adaptive step size for better performance
        t += max(dist * 0.9, epsilon * 2.0);
    }

    // Enhanced background with gradient and stars
    vec2 uv = fragTexCoord;
    vec3 bgColor = mix(
        vec3(0.02, 0.02, 0.08), 
        vec3(0.05, 0.05, 0.15), 
        uv.y
    );
    
    // Add subtle stars
    vec2 starUV = uv * 50.0;
    float stars = smoothstep(0.98, 1.0, 
        sin(starUV.x * 12.34) * sin(starUV.y * 56.78));
    bgColor += vec3(stars * 0.3);
    
    fragColor = vec4(bgColor, 1.0);
}