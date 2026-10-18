#include "../base/common.glsl"

float map(vec3 p, inout float trap) {
    vec3 z = p;
    float dr = 1.0;
    float r = 0.0;
    float Power = 8.0;
    
    for (int i = 0; i < 8; i++) {
        r = length(z);
        if (r > 2.0) break;
        
        float theta = acos(z.z / r);
        float phi = atan(z.y, z.x);

        // Power is 8, so both exponents are integers: a squaring chain
        // replaces two pow calls (each a log2 + exp2 pair).
        float r2 = r * r;
        float r4 = r2 * r2;
        float zr = r4 * r4;              // r^8  == pow(r, Power)
        float rp1 = zr / r;              // r^7  == pow(r, Power - 1.0)

        dr = rp1 * Power * dr + 1.0;

        theta = theta * Power;
        phi = phi * Power;
        
        z = zr * vec3(sin(theta) * cos(phi), sin(phi) * sin(theta), cos(theta));
        z += p;
        
        trap = min(trap, length(z));
    }
    return 0.5 * log(r) * r / dr;
}

vec3 getNormal(vec3 p) {
    float dummy = 0.0;
    // 4-tap tetrahedral normal: 4 DE evaluations instead of the 6 that
    // central differencing needs.
    vec2 e = vec2(0.001, 0.0);
    const vec2 k = vec2(1.0, -1.0);
    return normalize(
        k.xyy * map(p + k.xyy * e.x, dummy) +
        k.yyx * map(p + k.yyx * e.x, dummy) +
        k.yxy * map(p + k.yxy * e.x, dummy) +
        k.xxx * map(p + k.xxx * e.x, dummy));
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.2;
    
    // Camera setup
    vec3 ro = vec3(2.5 * sin(t), 1.5 * cos(t * 0.5), 2.5 * cos(t));
    vec3 lookat = vec3(0.0);
    vec3 fwd = normalize(lookat - ro);
    vec3 right = normalize(cross(vec3(0, 1, 0), fwd));
    vec3 up = cross(fwd, right);
    vec3 rd = normalize(fwd + centered.x * right + centered.y * up);
    
    // Raymarching
    float d = 0.0;
    float t_dist = 0.0;
    float trap = 1e10;
    vec3 p;
    
    for (int i = 0; i < 128; i++) {
        p = ro + rd * t_dist;
        d = map(p, trap);
        if (d < 0.001 || t_dist > 10.0) break;
        t_dist += d;
    }
    
    vec3 color = vec3(0.0);
    if (t_dist < 10.0) {
        vec3 norm = getNormal(p);
        vec3 lightPos = vec3(5.0, 5.0, 5.0);
        vec3 lightDir = normalize(lightPos - p);
        float diff = max(0.0, dot(norm, lightDir));
        
        vec3 trapColor = 0.5 + 0.5 * sin(vec3(trap * 3.0, trap * 3.0 + 2.0, trap * 3.0 + 4.0));
        color = trapColor * (diff + 0.1);
        
        color = mix(color, vec3(0.0), 1.0 - exp(-0.1 * t_dist));
    }
    
    color *= intensity;
    return vec4(color, alpha);
}
