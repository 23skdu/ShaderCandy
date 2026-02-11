// Particle Swarm Simulation
// compute_particles: Updates particle physics on the GPU
// vertex_particles: Processes particles for rendering
// fragment_particles: Renders each particle as a soft glow point

// Update Pass (Compute)
kernel void compute_particles(device Particle *particles [[buffer(0)]],
                            constant Uniforms &uniforms [[buffer(1)]],
                            uint id [[thread_position_in_grid]]) {
    device Particle &p = particles[id];
    
    // Interactive Gravity Behavior
    float2 toMouse = uniforms.mouse - p.position;
    float dist = length(toMouse);
    float force = 0.0;
    
    int buttons = (int)uniforms.mouseButtons;
    if (buttons & 1) { // Left Click: Strong Pull
        force = 0.005 * uniforms.gravity;
    } else if (buttons & 2) { // Right Click: Strong Push
        force = -0.005 * uniforms.gravity;
    } else { // No Click: Gentle Swarm
        force = 0.0005;
    }
    
    if (dist > 0.01) {
        p.velocity += normalize(toMouse) * force / (dist + 0.1);
    }
    
    // 2. Add some turbulence/noise (scaled by intensity)
    float2 noisePos = p.position * 5.0 + uniforms.time * (0.2 * uniforms.speed);
    float2 turbulence = float2(ShaderUtils::hash(noisePos.x + id), ShaderUtils::hash(noisePos.y + id)) * 0.001 - 0.0005;
    p.velocity += turbulence * uniforms.intensity;
    
    // 3. Update physics
    p.position += p.velocity * uniforms.speed;
    p.velocity *= 0.98; // Friction
    
    // Bounce off walls
    if (p.position.x < -1.0 || p.position.x > 1.0) p.velocity.x *= -1.0;
    if (p.position.y < -1.0 || p.position.y > 1.0) p.velocity.y *= -1.0;
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

// Render Pass (Fragment)
fragment float4 fragment_particles(ParticleOut in [[stage_in]],
                                  float2 pointCoord [[point_coord]]) {
    // Soft round point
    float d = length(pointCoord - 0.5);
    if (d > 0.5) discard_fragment();
    
    float alpha = smoothstep(0.5, 0.2, d) * in.color.a;
    return float4(in.color.rgb, alpha);
}
