#include "base/common.glsl"

// calibration - SMPTE color bars for display calibration

vec3 smpte_bars(vec2 uv) {
    vec3 color = vec3(0.0);
    
    // Top 2/3: 75% intensity primary/secondary colors
    if (uv.y > 0.33) {
        int bar = int(uv.x * 7.0);
        if (bar == 0) color = vec3(0.75, 0.75, 0.75);       // Grey
        else if (bar == 1) color = vec3(0.75, 0.75, 0.0);  // Yellow
        else if (bar == 2) color = vec3(0.0, 0.75, 0.75);  // Cyan
        else if (bar == 3) color = vec3(0.0, 0.75, 0.0);  // Green
        else if (bar == 4) color = vec3(0.75, 0.0, 0.75); // Magenta
        else if (bar == 5) color = vec3(0.75, 0.0, 0.0);   // Red
        else if (bar == 6) color = vec3(0.0, 0.0, 0.75);  // Blue
    } 
    // Middle 1/12
    else if (uv.y > 0.25) {
        int bar = int(uv.x * 7.0);
        if (bar == 0) color = vec3(0.0, 0.0, 0.75);        // Blue
        else if (bar == 1) color = vec3(0.0, 0.0, 0.0);   // Black
        else if (bar == 2) color = vec3(0.75, 0.0, 0.75); // Magenta
        else if (bar == 3) color = vec3(0.0, 0.0, 0.0);   // Black
        else if (bar == 4) color = vec3(0.0, 0.75, 0.75); // Cyan
        else if (bar == 5) color = vec3(0.0, 0.0, 0.0);   // Black
        else if (bar == 6) color = vec3(0.75, 0.75, 0.75); // Grey
    }
    // Bottom 1/4: PLUGE and primary colors
    else {
        if (uv.x < 1.0/6.0) {
            color = vec3(0.0, 0.15, 0.3); // -I
        } else if (uv.x < 2.0/6.0) {
            color = vec3(1.0, 1.0, 1.0); // White
        } else if (uv.x < 3.0/6.0) {
            color = vec3(0.3, 0.0, 0.5); // +Q
        } else if (uv.x < 4.0/6.0) {
            float pluge = uv.x * 6.0 - 3.0;
            if (pluge < 0.33) color = vec3(0.0);
            else if (pluge < 0.66) color = vec3(0.03);
            else color = vec3(0.07);
        } else {
            color = vec3(0.1, 0.1, 0.1); // 7.5% Gray
        }
    }
    
    return color;
}

vec4 effect_main(vec2 centered, vec2 uv) {
    float t = time * speed;
    
    vec3 color = smpte_bars(uv);
    
    // Apply HDR brightness mapping if enabled
    if (intensity > 1.0) {
        color *= intensity;
    }
    
    return vec4(color, alpha);
}