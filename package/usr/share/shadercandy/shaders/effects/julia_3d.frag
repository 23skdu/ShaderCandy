#include "../base/common.glsl"

vec4 qMul(vec4 q1, vec4 q2) {
    return vec4(
        q1.x * q2.x - q1.y * q2.y - q1.z * q2.z - q1.w * q2.w,
        q1.x * q2.y + q1.y * q2.x + q1.z * q2.w - q1.w * q2.z,
        q1.x * q2.z - q1.y * q2.w + q1.z * q2.x + q1.w * q2.y,
        q1.x * q2.w + q1.y * q2.z - q1.z * q2.y + q1.w * q2.x
    );
}

float map(vec3 p, vec4 c, inout float trap) {
    vec4 z = vec4(p, 0.0);
    float m2 = dot(z, z);
    float dz2 = 1.0;
    
    for (int i = 0; i < 10; i++) {
        dz2 *= 4.0 * m2;
        z = qMul(z, z) + c;
        m2 = dot(z, z);
        if (m2 > 10.0) break;
        trap = min(trap, m2);
    }
    
    return 0.25 * sqrt(m2 / dz2) * log(m2);
}

vec3 getNormal(vec3 p, vec4 c) {
    float dummy = 0.0;
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        map(p + e.xyy, c, dummy) - map(p - e.xyy, c, dummy),
        map(p + e.yxy, c, dummy) - map(p - e.yxy, c, dummy),
        map(p + e.yyx, c, dummy) - map(p - e.yyx, c, dummy)
    ));
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed * 0.3;
    
    vec4 c = vec4(-0.2, 0.6 * sin(t * 0.4), 0.4 * cos(t * 0.3), 0.2 * sin(t * 0.5));
    
    vec3 ro = vec3(2.0 * sin(t * 0.5), 1.0 * cos(t * 0.2), 2.0 * cos(t * 0.5));
    vec3 lookat = vec3(0.0);
    vec3 fwd = normalize(lookat - ro);
    vec3 right = normalize(cross(vec3(0, 1, 0), fwd));
    vec3 up = cross(fwd, right);
    vec3 rd = normalize(fwd + centered.x * right + centered.y * up);
    
    float t_dist = 0.0;
    float trap = 1e10;
    float d = 0.0;
    vec3 p;
    
    for (int i = 0; i < 100; i++) {
        p = ro + rd * t_dist;
        d = map(p, c, trap);
        if (d < 0.001 || t_dist > 8.0) break;
        t_dist += d;
    }
    
    vec3 color = vec3(0.05, 0.05, 0.1);
    if (t_dist < 8.0) {
        vec3 norm = getNormal(p, c);
        vec3 lightDir = normalize(vec3(1.0, 1.0, 1.0));
        float diff = max(0.1, dot(norm, lightDir));
        
        vec3 baseCol = 0.5 + 0.5 * sin(vec3(0.0, 2.0, 4.0) + trap * 2.0);
        color = baseCol * diff;
        
        vec3 ref = reflect(lightDir, norm);
        float spec = pow(max(0.0, dot(ref, rd)), 16.0);
        color += vec3(spec);
    }
    
    color *= intensity;
    return vec4(color, alpha);
}
