#include "base/common.glsl"

// orcs - Converted from Metal to GLSL
// Note: This is a simplified 2D version. The original Metal shader used 3D raymarching.

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.5;
    
    // TODO: Implement shader logic here
    // Original Metal shader used raymarching which needs to be adapted to 2D
    
    vec3 color = vec3(0.5);
    
    color *= intensity;
    return vec4(color, alpha);
}
