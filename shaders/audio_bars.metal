#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// Audio frequency bars
fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = uv * 2.0 - 1.0;
    p.x *= uniforms.resolution.x / uniforms.resolution.y;
    float t = uniforms.time * uniforms.speed;
    
    // Audio levels
    float bass = uniforms.bass;
    float mid = uniforms.mid;
    float treble = uniforms.treble;
    float volume = uniforms.volume;
    
    // Dark background
    float3 color = float3(0.02, 0.02, 0.04);
    
    // Bar parameters
    int numBars = 32;
    float barWidth = 1.8 / float(numBars);
    float startX = -0.9;
    float baseY = -0.5;
    float maxHeight = 1.2;
    
    // Draw bars
    for (int i = 0; i < 32; i++) {
        float x = startX + float(i) * barWidth;
        
        // Calculate bar height based on position (bass on left, treble on right)
        float position = float(i) / float(numBars);
        
        // Different frequency emphasis for each bar position
        float freqMix = position;
        float barHeight = mix(bass, treble, position) * maxHeight;
        
        // Add some variation
        barHeight *= 0.5 + 0.5 * sin(float(i) * 1.5 + t * 3.0);
        
        // Beat impact
        barHeight *= 1.0 + uniforms.beat * 0.5;
        
        // Draw bar
        if (p.x > x && p.x < x + barWidth * 0.9 && p.y > baseY && p.y < baseY + barHeight) {
            // Gradient color based on height
            float heightRatio = (p.y - baseY) / barHeight;
            float3 barColor = hsv2rgb(float3(
                0.6 - heightRatio * 0.4 + t * 0.1,  // Hue shifts with height
                0.9,
                0.7 + heightRatio * 0.3
            ));
            color = barColor;
            
            // Add shine on top
            if (heightRatio > 0.9) {
                color += float3(0.3);
            }
        }
        
        // Reflection below bars
        if (p.x > x && p.x < x + barWidth * 0.9 && p.y < baseY && p.y > baseY - barHeight * 0.3) {
            float reflectY = (baseY - p.y) / (barHeight * 0.3);
            float reflectHeight = barHeight * 0.3 * reflectY;
            
            if (reflectHeight < barHeight) {
                color = mix(color, float3(0.1, 0.15, 0.2), reflectY * 0.5);
            }
        }
    }
    
    // Beat flash
    float beat = uniforms.beat;
    color += float3(0.2, 0.1, 0.3) * beat * 0.3;
    
    // Grid lines
    float2 grid = abs(fract(p * 5.0) - 0.5);
    float gridLine = smoothstep(0.48, 0.5, max(grid.x, grid.y));
    color += float3(0.1) * gridLine * 0.2;
    
    color *= uniforms.intensity;
    return float4(color, uniforms.alpha);
}
