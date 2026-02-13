//
//  starship_hud.metal
//  ShaderCandy
//
//  Tactical starship cockpit display
//

using namespace ShaderUtils;

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed;
    
    // Background: Moving Starfield
    float3 color = float3(0.0);
    float3 p = float3(uv * 2.0, 1.0);
    for(float i=0; i<4.0; i++) {
        float f = fract(t * 0.1 + i * 0.25);
        float2 startUV = uv * (1.0 / (f + 0.01));
        float starScale = 10.0 + i * 5.0;
        float s = pow(noise(startUV * starScale), 20.0) * (1.0 - f);
        color += s * float3(0.8, 0.9, 1.0);
    }
    
    // HUD Overlay: Crosshair
    float cross = smoothstep(0.01, 0.0, abs(uv.x)) * smoothstep(0.2, 0.0, abs(uv.y));
    cross += smoothstep(0.01, 0.0, abs(uv.y)) * smoothstep(0.2, 0.0, abs(uv.x));
    float circle = exp(-abs(length(uv) - 0.4) * 40.0);
    
    float3 hudCol = float3(0.1, 1.0, 0.4);
    color += hudCol * (cross + circle) * 0.6;
    
    // Tactical Bracket
    float2 targetPos = float2(cos(t * 0.5) * 0.6, sin(t * 0.7) * 0.4);
    float2 bracketUV = abs(uv - targetPos);
    if (bracketUV.x < 0.15 && bracketUV.y < 0.15) {
        float edge = step(0.14, max(bracketUV.x, bracketUV.y));
        color += float3(1.0, 0.2, 0.2) * edge * (0.5 + 0.5 * sin(t * 15.0));
    }
    
    // Scanlines & Digital Noise
    float scanline = sin(uv.y * 200.0) * 0.05;
    color += scanline;
    if (hash(t) > 0.98) color += 0.05 * hash(uv);
    
    // Vignette
    color *= 1.0 - length(in.texCoord - 0.5) * 0.4;
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
