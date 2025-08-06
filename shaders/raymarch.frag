#version 320 es
precision mediump float;

uniform Uniforms {
    vec2 iResolution;
    float iTime;
} frame;

out vec4 frag_color;

mat2 rotate(float a){float s=sin(a),c=cos(a);return mat2(c,-s,s,c);}
float sdBox(vec3 p,vec3 b){vec3 q=abs(p)-b;return length(max(q,vec3(0.))) + min(max(q.x,max(q.y,q.z)),0.);}

void main() {
    vec2 uv = (gl_FragCoord.xy * 2.0 - frame.iResolution.xy) / frame.iResolution.y;

    vec3 ro = vec3(0., 0., -4.);
    vec3 rd = normalize(vec3(uv, 1.));

    float t = 0.;
    vec3 col = vec3(0.);

    for(int i = 0; i < 32; i++) {
        vec3 p = ro + rd * t;
        p.xz *= rotate(frame.iTime);
        p.xy *= rotate(frame.iTime * 0.7);
        float d = sdBox(p, vec3(1.));
        if(d < 0.001) {
            col = vec3(0.8);
            break;
        }
        t += d;
        if(t > 20.) break;
    }
    frag_color = vec4(col, 1.0);
}

/*// File: shaders/raymarch_cube.frag
#version 320 es
precision mediump float;

// FINAL FIX: All uniforms are in a single block.
uniform Uniforms {
    vec3 iResolution;
    float iTime;
    vec3 iLightPos;
} frame;

in vec2 v_uv;
out vec4 frag_color;

mat2 rotate(float a) { float s=sin(a),c=cos(a); return mat2(c,-s,s,c); }
float sdBox(vec3 p, vec3 b) { vec3 q = abs(p) - b; return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0); }
vec3 getNormal(vec3 p) { vec2 e=vec2(.001,0.); return normalize(vec3(sdBox(p+e.xyy,vec3(1.))-sdBox(p-e.xyy,vec3(1.)),sdBox(p+e.yxy,vec3(1.))-sdBox(p-e.yxy,vec3(1.)),sdBox(p+e.yyx,vec3(1.))-sdBox(p-e.yyx,vec3(1.)))); }

float raymarch(vec3 ro, vec3 rd) {
    float t = 0.0;
    for(int i = 0; i < 64; i++) {
        vec3 p = ro + rd * t;
        p.xz *= rotate(frame.iTime); p.xy *= rotate(frame.iTime * 0.7);
        float d = sdBox(p, vec3(1.0));
        if(d < 0.001) return t;
        t += d;
        if(t > 100.0) break;
    }
    return -1.0;
}

void main() {
    vec2 uv = v_uv;
    vec3 ro = vec3(uv * vec2(1.5, 1.0), -4.0);
    vec3 rd = normalize(vec3(uv, 1.0));

    float t = raymarch(ro, rd);
    
    vec3 col = vec3(0.1, 0.12, 0.15);
    if (t > -1.0) {
        vec3 p = ro + rd * t;
        p.xz *= rotate(frame.iTime); p.xy *= rotate(frame.iTime * 0.7);
        vec3 normal = getNormal(p);
        vec3 light_dir = normalize(frame.iLightPos - p);
        float diffuse = max(dot(normal, light_dir), 0.0);
        vec3 materialColor = vec3(0.8);
        col = materialColor * diffuse + vec3(0.1);
    }
    
    frag_color = vec4(col, 1.0);
}*/

/*// File: shaders/raymarch_cube.frag
#version 320 es
precision mediump float;

// Uniforms to receive time, aspect ratio, and lighting info from Flutter
uniform vec3 iResolution; // width, height, pixel_aspect
uniform float iTime;
uniform vec3 iLightPos;

out vec4 frag_color;

// --- Helper Functions for Raymarching ---

// Rotation matrix for the camera/world
mat2 rotate(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

// Signed Distance Function (SDF) for a Box.
// Tells us how far a point 'p' is from the surface of a box of size 'b'.
// If the result is < 0, we are inside the box.
// If the result is > 0, we are outside the box.
float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

// Function to estimate the normal of a surface at a point.
// It checks the SDF in tiny increments around the point.
vec3 getNormal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        sdBox(p + e.xyy, vec3(1.0)) - sdBox(p - e.xyy, vec3(1.0)),
        sdBox(p + e.yxy, vec3(1.0)) - sdBox(p - e.yxy, vec3(1.0)),
        sdBox(p + e.yyx, vec3(1.0)) - sdBox(p - e.yyx, vec3(1.0))
    ));
}

// The main raymarching function.
float raymarch(vec3 ro, vec3 rd) {
    float t = 0.0; // Total distance traveled
    for(int i = 0; i < 64; i++) { // Max steps to prevent infinite loops
        vec3 p = ro + rd * t;

        // --- World Objects ---
        // Rotate the world to make the cube spin
        p.xz *= rotate(iTime);
        p.xy *= rotate(iTime * 0.7);

        float d = sdBox(p, vec3(1.0));
        if(d < 0.001) return t; // We hit something!
        t += d;
        if(t > 100.0) break; // We're too far, give up
    }
    return -1.0;
}


// --- Main Shader Program ---
void main() {
    // Normalize pixel coordinates (from -1 to 1)
    vec2 uv = (gl_FragCoord.xy * 2.0 - iResolution.xy) / iResolution.y;

    // --- Camera Setup ---
    vec3 ro = vec3(0.0, 0.0, -4.0); // Ray Origin (camera position)
    vec3 rd = normalize(vec3(uv, 1.0)); // Ray Direction (into the screen)

    // Raymarch to find intersections
    float t = raymarch(ro, rd);
    
    vec3 col = vec3(0.1, 0.12, 0.15); // Background color
    if (t > -1.0) {
        // --- Lighting ---
        vec3 p = ro + rd * t; // Point of intersection

        // Re-apply the same world rotations to calculate normal correctly
        p.xz *= rotate(iTime);
        p.xy *= rotate(iTime * 0.7);
        vec3 normal = getNormal(p);

        // Simple diffuse lighting
        vec3 light_dir = normalize(iLightPos - p);
        float diffuse = max(dot(normal, light_dir), 0.0);
        
        vec3 materialColor = vec3(0.8);
        col = materialColor * diffuse + vec3(0.1); // Lit color
    }
    
    frag_color = vec4(col, 1.0);
}*/