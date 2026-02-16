#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Art Deco design
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed * 0.1;
    
    // Cream/gold background
    float3 color = float3(0.95, 0.92, 0.85);
    
    // Dark elements
    float3 darkColor = float3(0.15, 0.12, 0.1);
    float3 goldColor = float3(0.85, 0.7, 0.3);
    
    // Art deco sunburst in center
    float r = length(p);
    float angle = atan2(p.y, p.x);
    
    // Radial lines
    float numLines = 24.0;
    float lineAngle = mod(angle + t * 0.1, 6.28318 / numLines);
    float radialLine = smoothstep(0.02, 0.0, abs(lineAngle - 3.14159 / numLines));
    
    float centerGlow = smoothstep(0.5, 0.0, r);
    color = mix(color, darkColor, radialLine * centerGlow * 0.7);
    
    // Concentric circles
    for (float i = 0.0; i < 5.0; i++) {
        float circleR = 0.15 + i * 0.12;
        float circle = smoothstep(0.015, 0.01, abs(r - circleR));
        
        if (mod(i, 2.0) > 0.5) {
            color = mix(color, darkColor, circle);
        } else {
            color = mix(color, goldColor, circle);
        }
    }
    
    // Corner triangles
    float2 corners[4] = {float2(-0.9, 0.9), float2(0.9, 0.9), float2(-0.9, -0.9), float2(0.9, -0.9)};
    float2 cornerSigns[4] = {float2(1, -1), float2(-1, -1), float2(1, 1), float2(-1, 1)};
    
    for (int i = 0; i < 4; i++) {
        float2 cornerP = (p - corners[i]) * cornerSigns[i];
        
        // Triangle fan
        if (cornerP.x > 0.0 && cornerP.x < 0.4 && cornerP.y > 0.0 && cornerP.y < 0.4) {
            float triX = cornerP.y * 0.8;
            if (cornerP.x < triX) {
                color = darkColor;
            }
        }
        
        // Vertical lines in corners
        if (abs(cornerP.x) < 0.03 && cornerP.y > 0.0 && cornerP.y < 0.5) {
            color = goldColor;
        }
    }
    
    // Horizontal bands
    float bandY1 = 0.3;
    float bandY2 = -0.3;
    float bandHeight = 0.08;
    
    float band1 = smoothstep(bandHeight, 0.0, abs(p.y - bandY1));
    float band2 = smoothstep(bandHeight, 0.0, abs(p.y - bandY2));
    
    color = mix(color, darkColor, band1 * 0.8);
    color = mix(color, darkColor, band2 * 0.8);
    
    // Chevron pattern in bands
    float chevron = sin(p.x * 30.0) * 0.5 + 0.5;
    color = mix(color, goldColor, (band1 + band2) * chevron * 0.3);
    
    // Border
    float border = smoothstep(0.98, 0.95, max(abs(p.x), abs(p.y)));
    color = mix(color, goldColor, border);
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
