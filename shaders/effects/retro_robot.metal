//
//  retro_robot.metal
//  ShaderCandy
//
//  1950s "Raygun Gothic" style robot
//

using namespace ShaderUtils;

// SDF for a rounded box (used for robot body/limbs)
float sdRoundBox(float3 p, float3 b, float r) {
    float3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

// Robot SDF
float robotSDF(float3 p, float t, thread float& material) {
    // Body
    float body = sdRoundBox(p - float3(0, 0, 0), float3(0.4, 0.5, 0.3), 0.1);
    material = 0.0; // Metal
    
    // Head
    float3 headP = p - float3(0, 0.7, 0);
    float head = sdRoundBox(headP, float3(0.25, 0.2, 0.25), 0.05);
    if (head < body) { body = head; material = 0.0; }
    
    // Eyes (glowing)
    float eyeL = length(headP - float3(-0.1, 0.05, 0.25)) - 0.05;
    float eyeR = length(headP - float3(0.1, 0.05, 0.25)) - 0.05;
    float eyes = min(eyeL, eyeR);
    if (eyes < body) { body = eyes; material = 1.0; } // Glow
    
    // Antenna
    float antenna = length(headP.xz) - 0.01;
    antenna = max(antenna, headP.y - 0.5);
    antenna = max(antenna, 0.2 - headP.y);
    float bulb = length(headP - float3(0, 0.5, 0)) - 0.04;
    antenna = min(antenna, bulb);
    if (antenna < body) { body = antenna; material = (bulb < antenna + 0.01) ? 1.0 : 0.0; }
    
    // Arms
    float armSide = sign(p.x);
    float3 armP = p;
    armP.x = abs(armP.x) - 0.55;
    // Animate arms
    armP = rotateX(armP, sin(t * 2.0) * 0.5);
    float arm = sdRoundBox(armP - float3(0, -0.2, 0), float3(0.08, 0.4, 0.08), 0.02);
    if (arm < body) { body = arm; material = 0.0; }
    
    return body;
}

float3 getRobotNormal(float3 p, float t) {
    float dummy = 0.0;
    float2 e = float2(0.001, 0.0);
    return normalize(float3(
        robotSDF(p + e.xyy, t, dummy) - robotSDF(p - e.xyy, t, dummy),
        robotSDF(p + e.yxy, t, dummy) - robotSDF(p - e.yxy, t, dummy),
        robotSDF(p + e.yyx, t, dummy) - robotSDF(p - e.yyx, t, dummy)
    ));
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;
    uv.x *= aspect;
    
    float t = uniforms.time * uniforms.speed;
    
    // Camera
    float3 ro = float3(2.0 * sin(t * 0.2), 0.5, 3.0);
    float3 ta = float3(0.0, 0.2, 0.0);
    float3 fwd = normalize(ta - ro);
    float3 right = normalize(cross(float3(0, 1, 0), fwd));
    float3 up = cross(fwd, right);
    float3 rd = normalize(fwd + uv.x * right + uv.y * up);
    
    // Raymarch
    float d = 0.0, t_dist = 0.0;
    float mat = 0.0;
    for(int i=0; i<80; i++) {
        d = robotSDF(ro + rd * t_dist, t, mat);
        if(d < 0.001 || t_dist > 10.0) break;
        t_dist += d;
    }
    
    float3 color = float3(0.1, 0.1, 0.12); // Background
    
    if(t_dist < 10.0) {
        float3 p = ro + rd * t_dist;
        float3 n = getRobotNormal(p, t);
        float3 light = normalize(float3(1, 2, 1));
        
        if(mat < 0.5) { // Metal
            float diff = max(0.0, dot(n, light));
            float spec = pow(max(0.0, dot(reflect(-light, n), -rd)), 32.0);
            color = float3(0.6, 0.6, 0.65) * diff + float3(spec);
            // Add some "scratches" with noise
            color *= 0.8 + 0.2 * noise(p.xy * 10.0);
        } else { // Glowing parts
            float pulse = 0.8 + 0.2 * sin(t * 10.0);
            color = float3(1.0, 0.2, 0.1) * pulse * 2.0;
        }
    }
    
    // Retro film grain and flicker
    float grain = noise(uv * 100.0 + t);
    color += grain * 0.05;
    color *= 0.9 + 0.1 * sin(t * 50.0);
    
    // Vignette
    color *= 1.0 - length(in.texCoord - 0.5) * 0.5;
    
    return float4(color * uniforms.intensity, uniforms.alpha);
}
