#include "ShaderInterop.h"

using namespace metal;
using namespace ShaderUtils;

// #include "common.metal" (Removed for runtime compatibility)

// Threadgroup memory for optimized local interactions
#define GROUP_SIZE 512

// Update Pass (Compute)
kernel void compute_particles(device Particle *particles [[buffer(0)]],
                            constant Uniforms &uniforms [[buffer(1)]],
                            uint id [[thread_position_in_grid]],
                            uint tid [[thread_index_in_threadgroup]],
                            uint simd_id [[thread_index_in_simdgroup]]) {
    device Particle &p = particles[id];
    
    // 1. Threadgroup caching for local interactions
    threadgroup float2 localPos[GROUP_SIZE];
    localPos[tid] = p.position;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // 2. Local Flocking / Avoidance (O(N_group) instead of O(N_total))
    float2 separation = float2(0.0f);
    float2 alignment = float2(0.0f);
    float neighborCount = 0.0f;
    
    // Unroll slightly for better instruction throughput on Apple Silicon
    for (int i = 0; i < GROUP_SIZE; i++) {
        float2 otherPos = localPos[i];
        float2 diff = p.position - otherPos;
        float d2 = dot(diff, diff);
        
        // Use step and select to avoid branching in the loop
        float isNeighbor = step(0.0001f, d2) * step(d2, 0.01f);
        separation += (diff / (d2 + 0.001f)) * isNeighbor;
        neighborCount += isNeighbor;
    }
    
    if (neighborCount > 0.0f) {
        p.velocity += (separation / neighborCount) * 0.001f * uniforms.intensity;
    }
    
    // 3. Mouse Interaction (Direct Uniform Access)
    float2 mousePos = uniforms.mouse;
    float2 toMouse = mousePos - p.position;
    float distSq = dot(toMouse, toMouse) + 0.001f;
    float invDist = rsqrt(distSq);
    
    int buttons = (int)uniforms.mouseButtons;
    float forceSign = float(buttons & 1) - float((buttons & 2) >> 1);
    float mouseForce = (forceSign != 0.0f) ? forceSign * 0.005f * uniforms.gravity : 0.0002f;
    
    p.velocity += (toMouse * invDist * mouseForce * invDist);
    
    // 4. Update physics
    p.position += p.velocity * uniforms.speed;
    p.velocity *= 0.985f; // Friction
    
    // 5. Boundary Handling (Fast Branchless)
    p.velocity = select(p.velocity, -p.velocity, abs(p.position) > 1.0f);
    p.position = clamp(p.position, -1.0f, 1.0f);
    
    // 6. Lifecycle Reset
    p.life -= 0.002f;
    if (p.life <= 0.0f) {
        float2 rand = ShaderUtils::hash2(float2(float(id), uniforms.time));
        p.position = rand * 2.0f - 1.0f;
        p.velocity *= 0.0f;
        p.life = 1.0f + rand.x;
        p.color = float4(ShaderUtils::hsv2rgb(float3(rand.y + uniforms.time * 0.05f, 0.7f, 1.0f)), 1.0f);
    }
}

// Render Pass (Vertex)
struct ParticleOut {
    float4 position [[position]];
    float4 color;
    float pointSize [[point_size]];
};

vertex ParticleOut vertex_particles(device Particle *particles [[buffer(0)]],
                                   uint id [[vertex_id]]) {
    ParticleOut out;
    float2 pos = particles[id].position;
    out.position = float4(pos, 0.0, 1.0);
    out.color = particles[id].color;
    out.color.a *= particles[id].life; // Fade out as it dies
    out.pointSize = particles[id].size * 10.0;
    return out;
}

// Render Pass (Fragment - Branchless)
fragment float4 fragment_main(ParticleOut in [[stage_in]],
                                  float2 pointCoord [[point_coord]]) {
    // Soft round point
    float d = length(pointCoord - 0.5);
    // Multiply by step-like smoothstep to handle the 0.5 clip branchlessly
    float alpha = smoothstep(0.5, 0.45, d) * smoothstep(0.5, 0.2, d) * in.color.a;
    return float4(in.color.rgb, alpha);
}
