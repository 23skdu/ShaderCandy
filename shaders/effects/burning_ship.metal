#include "ShaderInterop.h"

// Burning Ship Fractal - Modified Mandelbrot with absolute values

using namespace metal;

float2 burningShip(float2 c) {
    float2 z = float2(0.0);
    float2 dz = float2(0.0);
    float n = 0.0;
    
    for(int i = 0; i < 100; i++) {
        // Derivative
        dz = 2.0 * float2(z.x * dz.x - z.y * dz.y, z.x * dz.y + z.y * dz.x) + float2(1.0, 0.0);
        
        // z = z^2 + c with absolute values (the "ship" part)
        float x = (z.x * z.x - z.y * z.y) + c.x;
        float y = abs(2.0 * z.x * z.y) + c.y;
        z = float2(x, y);
        
        n += 1.0;
        if(dot(z, z) > 256.0) break;
    }
    
    float d = 0.5 * log(dot(z, z)) * sqrt(dot(z, z) / dot(dz, dz));
    return float2(d, n);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Uniforms &u [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 p = (uv - 0.5) * 4.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    // Offset to show the ship shape
    float2 c = p - float2(0.5, 0.0);
    
    float t = u.time * 0.1;
    
    // Animate the fractal slightly
    c += float2(0.05 * sin(t), 0.03 * cos(t));
    
    float2 d = burningShip(c);
    
    float3 col;
    if(d.x < 0.001) {
        col = float3(0.0); // Inside - dark
    } else {
        // Outside - color based on iterations
        float n = d.y / 100.0;
        float s = pow(d.x, 0.3);
        
        col = float3(
            0.5 + 0.5 * cos(3.0 + n * 10.0 + 0.0),
            0.5 + 0.5 * cos(3.0 + n * 10.0 + 2.0),
            0.5 + 0.5 * cos(3.0 + n * 10.0 + 4.0)
        );
        
        // Add glow
        col *= s * 2.0;
    }
    
    // Add scanlines
    col *= 0.9 + 0.1 * sin(uv.y * u.resolution.y);
    
    return float4(col * u.intensity, 1.0);
}
