// Particle Swarm Simulation
// compute_particles: Updates particle physics on the GPU
// vertex_particles: Processes particles for rendering
// fragment_particles: Renders each particle as a soft glow point

// Update Pass (Compute)
kernel void compute_particles(device Particle *particles [[buffer(0)]],
                            constant Uniforms &uniforms [[buffer(1)]],
                            uint id [[thread_position_in_grid]]) {
    device Particle &p = particles[id];
    
    // 1. Mouse Interaction Behavior (Branchless)
    float2 toMouse = uniforms.mouse - p.position;
    float dist = length(toMouse);
    
    // Branchless force selection based on bitmask
    int buttons = (int)uniforms.mouseButtons;
    float isLeft = float(buttons & 1);
    float isRight = float((buttons & 2) >> 1);
    float noClick = 1.0 - clamp(isLeft + isRight, 0.0, 1.0);
    
    float force = isLeft * (0.005 * uniforms.gravity) + 
                  isRight * (-0.005 * uniforms.gravity) + 
                  noClick * 0.0005;
    
    // Branchless distance contribution
    p.velocity += (normalize(toMouse) * force / (dist + 0.1)) * step(0.01, dist);
    
    // 2. Add some turbulence/noise (scaled by intensity)
    float2 noisePos = p.position * 5.0 + uniforms.time * (0.2 * uniforms.speed);
    float2 turbulence = float2(ShaderUtils::hash(noisePos.x + id), ShaderUtils::hash(noisePos.y + id)) * 0.001 - 0.0005;
    p.velocity += turbulence * uniforms.intensity;
    
    // 3. Update physics
    p.position += p.velocity * uniforms.speed;
    p.velocity *= 0.98; // Friction
    
    // 4. Bounce off walls (Branchless using select)
    bool2 bounds = (abs(p.position) > 1.0);
    p.velocity = select(p.velocity, p.velocity * -1.0, bounds);
    p.position = clamp(p.position, -1.0, 1.0);
    
    // Lifecycle
    p.life -= 0.002;
    if (p.life <= 0.0) {
        // Respawn
        float2 seed = float2(id, uniforms.time);
        p.position = ShaderUtils::hash2(seed) * 2.0 - 1.0;
        p.velocity = float2(0.0);
        p.life = 1.0 + ShaderUtils::hash(id * 0.1);
        p.color = float4(ShaderUtils::hsv2rgb(float3(ShaderUtils::hash(id * 0.5) + uniforms.time * 0.1, 0.8, 1.0)), 1.0);
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
fragment float4 fragment_particles(ParticleOut in [[stage_in]],
                                  float2 pointCoord [[point_coord]]) {
    // Soft round point
    float d = length(pointCoord - 0.5);
    // Multiply by step-like smoothstep to handle the 0.5 clip branchlessly
    float alpha = smoothstep(0.5, 0.45, d) * smoothstep(0.5, 0.2, d) * in.color.a;
    return float4(in.color.rgb, alpha);
}
