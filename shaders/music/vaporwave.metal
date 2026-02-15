#include "ShaderInterop.h"
#include "../base/utils.metal"

// Vaporwave - Retro 80s/90s aesthetic with neon grids, sunsets, and floating retro tech

#include <metal_stdlib>
using namespace metal;

using namespace ShaderUtils;

// SDF for rounded box
float sdRoundBox(float3 p, float3 b, float r) {
    float3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

// SDF for cylinder
float sdCylinder(float3 p, float h, float r) {
    float2 d = abs(float2(length(p.xz), p.y)) - float2(r, h);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

// SDF for capsule
float sdCapsule(float3 p, float3 a, float3 b, float r) {
    float3 pa = p - a;
    float3 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

// Old Macintosh Classic computer
float sdMacintosh(float3 p) {
    float d = 1e10;
    
    // Main case (beige box)
    float3 caseP = p - float3(0.0, 0.0, 0.0);
    float caseBox = sdRoundBox(caseP, float3(0.35, 0.28, 0.25), 0.02);
    
    // Screen (dark inset)
    float3 screenP = p - float3(0.0, 0.05, 0.18);
    float screen = sdRoundBox(screenP, float3(0.22, 0.18, 0.01), 0.01);
    screen = max(screen, -(length((screenP.xy - float2(0.0, 0.0)) * float2(1.0, 0.75)) - 0.15));
    
    // Floppy drive slot
    float3 floppyP = p - float3(0.0, -0.15, 0.18);
    float floppy = sdRoundBox(floppyP, float3(0.15, 0.02, 0.01), 0.005);
    
    d = min(d, caseBox);
    d = max(d, -screen);
    d = max(d, -floppy);
    
    return d;
}

// Classic Mac Rainbow Logo
float sdMacRainbowLogo(float3 p) {
    float appleBody = length(p.xy - float2(0.0, -0.02)) - 0.12;
    appleBody = max(appleBody, -(length(p.xy - float2(0.0, 0.08)) - 0.06));
    appleBody = max(appleBody, abs(p.z) - 0.02);
    
    // Leaf
    float3 leafP = p - float3(0.0, 0.12, 0.0);
    leafP.xy = float2(leafP.x * 0.7 - leafP.y * 0.7, leafP.x * 0.7 + leafP.y * 0.7);
    float leaf = length(leafP.xy) - 0.04;
    leaf = max(leaf, abs(p.z) - 0.02);
    
    return min(appleBody, leaf);
}

// Windows logo (4 colored squares)
float sdWindowsLogo(float3 p) {
    float d = 1e10;
    float2 offsets[4] = {
        float2(-0.06, 0.06), float2(0.06, 0.06),
        float2(-0.06, -0.06), float2(0.06, -0.06)
    };
    
    for(int i = 0; i < 4; i++) {
        float3 squareP = p - float3(offsets[i].x, offsets[i].y, 0.0);
        squareP.x += sin(p.y * 5.0 + p.z * 3.0) * 0.02;
        float square = sdRoundBox(squareP, float3(0.05, 0.05, 0.01), 0.005);
        d = min(d, square);
    }
    return d;
}

// Greek/Roman bust statue
float sdGreekBust(float3 p) {
    float d = 1e10;
    
    // Base/pedestal
    float3 baseP = p - float3(0.0, -0.35, 0.0);
    float base = sdCylinder(baseP, 0.08, 0.2);
    
    // Shoulders/chest
    float3 chestP = p - float3(0.0, -0.15, 0.0);
    float chest = sdRoundBox(chestP, float3(0.25, 0.15, 0.15), 0.05);
    
    // Neck
    float3 neckP = p - float3(0.0, 0.05, 0.0);
    float neck = sdCylinder(neckP, 0.08, 0.06);
    
    // Head (oval)
    float3 headP = p - float3(0.0, 0.22, 0.02);
    float head = length(headP * float3(1.0, 1.3, 1.0)) - 0.14;
    
    // Hair (curly top)
    float hair = 0.0;
    for(int i = 0; i < 8; i++) {
        float fi = float(i);
        float angle = fi * 0.785;
        float3 curlP = p - float3(cos(angle) * 0.12, 0.35 + sin(fi * 2.0) * 0.02, sin(angle) * 0.1);
        float curl = length(curlP) - 0.04;
        hair = max(hair, -curl);
    }
    head = max(head, hair);
    
    d = min(base, chest);
    d = min(d, neck);
    d = min(d, head);
    
    return d;
}

// VHS cassette tape
float sdVHS(float3 p) {
    float3 caseP = p - float3(0.0, 0.0, 0.0);
    float caseBox = sdRoundBox(caseP, float3(0.4, 0.25, 0.06), 0.01);
    
    float3 labelP = p - float3(0.0, 0.05, 0.04);
    float label = sdRoundBox(labelP, float3(0.3, 0.15, 0.01), 0.005);
    
    float d = caseBox;
    d = max(d, -label);
    return d;
}

// Palm tree silhouette
float sdPalmTree(float3 p) {
    // Trunk (curved)
    float3 trunkCurve = float3(sin(p.y * 2.0) * 0.1, 0.0, 0.0);
    float3 trunkP = p - trunkCurve;
    trunkP.y -= 0.5;
    float trunk = sdCapsule(trunkP, float3(0.0, -0.5, 0.0), float3(0.0, 0.5, 0.0), 0.04);
    
    // Leaves (fronds)
    float leaves = 1e10;
    for(int i = 0; i < 7; i++) {
        float fi = float(i);
        float angle = fi * 0.9 + 0.2;
        float3 leafStart = float3(0.0, 0.5, 0.0);
        float3 leafEnd = leafStart + float3(cos(angle) * 0.4, sin(angle * 0.5) * 0.1, sin(angle) * 0.3);
        float leaf = sdCapsule(p, leafStart, leafEnd, 0.015);
        leaves = min(leaves, leaf);
    }
    
    return min(trunk, leaves);
}

// Grid floor
float sdGridFloor(float3 p) {
    float2 grid = abs(fract(p.xz * 0.5) - 0.5) * 2.0;
    float line = min(grid.x, grid.y);
    line = smoothstep(0.05, 0.0, line);
    
    float floor_y = p.y + 1.0;
    float floor_plane = abs(floor_y);
    
    return floor_plane - line * 0.02;
}

// Sunset background
float3 getSunsetColor(float2 uv) {
    float3 topColor = float3(0.05, 0.02, 0.15);
    float3 midColor = float3(0.8, 0.3, 0.6);
    float3 bottomColor = float3(1.0, 0.7, 0.3);
    
    float t = uv.y;
    float3 col = mix(bottomColor, midColor, smoothstep(0.0, 0.4, t));
    col = mix(col, topColor, smoothstep(0.4, 1.0, t));
    
    return col;
}

// Scene mapping
float map(float3 p, float time, thread int& material) {
    float d = 1e10;
    material = 0;
    
    // Grid floor
    float floor_d = sdGridFloor(p);
    if(floor_d < d) {
        d = floor_d;
        material = 1;
    }
    
    // Floating Macintosh computers
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        float3 macPos = float3(
            sin(time * 0.3 + fi * 2.0) * 1.5,
            0.5 + cos(time * 0.2 + fi) * 0.3,
            -2.0 + fi * 1.5 + sin(time * 0.1 + fi) * 0.5
        );
        
        float3 macP = p - macPos;
        float rotAngle = time * 0.2 + fi;
        float2 rot = float2(
            macP.x * cos(rotAngle) - macP.z * sin(rotAngle),
            macP.x * sin(rotAngle) + macP.z * cos(rotAngle)
        );
        macP.x = rot.x;
        macP.z = rot.y;
        
        float mac = sdMacintosh(macP);
        if(mac < d) {
            d = mac;
            material = 2;
        }
    }
    
    // Floating Mac rainbow logos
    for(int i = 0; i < 4; i++) {
        float fi = float(i);
        float3 logoPos = float3(
            cos(time * 0.25 + fi * 1.5) * 2.0,
            0.8 + sin(time * 0.15 + fi * 2.0) * 0.4,
            -1.5 + fi * 0.8
        );
        
        float3 logoP = p - logoPos;
        float rotAngle = time * 0.3 + fi * 0.5;
        float2 rot = float2(
            logoP.x * cos(rotAngle) - logoP.y * sin(rotAngle),
            logoP.x * sin(rotAngle) + logoP.y * cos(rotAngle)
        );
        logoP.x = rot.x;
        logoP.y = rot.y;
        
        float logo = sdMacRainbowLogo(logoP);
        if(logo < d) {
            d = logo;
            material = 3;
        }
    }
    
    // Floating Windows logos
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        float3 winPos = float3(
            sin(time * 0.2 + fi * 2.5) * 1.8,
            -0.2 + cos(time * 0.25 + fi * 1.8) * 0.3,
            -1.0 + fi * 1.2
        );
        
        float3 winP = p - winPos;
        float rotAngle = time * 0.15 + fi;
        float2 rot = float2(
            winP.x * cos(rotAngle) - winP.z * sin(rotAngle),
            winP.x * sin(rotAngle) + winP.z * cos(rotAngle)
        );
        winP.x = rot.x;
        winP.z = rot.y;
        
        float win = sdWindowsLogo(winP);
        if(win < d) {
            d = win;
            material = 4;
        }
    }
    
    // Floating Greek busts
    for(int i = 0; i < 3; i++) {
        float fi = float(i);
        float3 bustPos = float3(
            cos(time * 0.18 + fi * 2.1) * 2.2,
            0.3 + sin(time * 0.22 + fi * 1.5) * 0.25,
            -2.5 + fi * 1.3
        );
        
        float3 bustP = p - bustPos;
        float rotAngle = time * 0.1 + fi * 0.8;
        float2 rot = float2(
            bustP.x * cos(rotAngle) - bustP.z * sin(rotAngle),
            bustP.x * sin(rotAngle) + bustP.z * cos(rotAngle)
        );
        bustP.x = rot.x;
        bustP.z = rot.y;
        
        float bust = sdGreekBust(bustP);
        if(bust < d) {
            d = bust;
            material = 5;
        }
    }
    
    // Floating VHS tapes
    for(int i = 0; i < 2; i++) {
        float fi = float(i);
        float3 vhsPos = float3(
            sin(time * 0.35 + fi * 3.0) * 1.2,
            -0.5 + cos(time * 0.28 + fi * 2.2) * 0.2,
            -0.8 + fi * 0.6
        );
        
        float3 vhsP = p - vhsPos;
        float rotAngle = time * 0.4 + fi;
        float2 rot = float2(
            vhsP.x * cos(rotAngle) - vhsP.y * sin(rotAngle),
            vhsP.x * sin(rotAngle) + vhsP.y * cos(rotAngle)
        );
        vhsP.x = rot.x;
        vhsP.y = rot.y;
        
        float vhs = sdVHS(vhsP);
        if(vhs < d) {
            d = vhs;
            material = 6;
        }
    }
    
    // Palm trees on floor
    for(int i = 0; i < 4; i++) {
        float fi = float(i);
        float3 palmPos = float3(
            -3.0 + fi * 2.0 + sin(time * 0.05 + fi) * 0.5,
            -1.0,
            -4.0 + fi * 0.3
        );
        
        float3 palmP = p - palmPos;
        float palm = sdPalmTree(palmP);
        if(palm < d) {
            d = palm;
            material = 7;
        }
    }
    
    return d;
}

// Calculate normal
float3 calcNormal(float3 p, float time) {
    int mat;
    float2 e = float2(0.001, 0.0);
    return normalize(float3(
        map(p + e.xyy, time, mat) - map(p - e.xyy, time, mat),
        map(p + e.yxy, time, mat) - map(p - e.yxy, time, mat),
        map(p + e.yyx, time, mat) - map(p - e.yyx, time, mat)
    ));
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Uniforms& u [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float t = u.time * u.speed * 0.2;
    
    // Camera setup
    float3 ro = float3(0.0, 0.5 + sin(t * 0.1) * 0.2, 3.0);
    float3 lookAt = float3(0.0, 0.0, -1.0);
    float3 forward = normalize(lookAt - ro);
    float3 right = normalize(cross(float3(0.0, 1.0, 0.0), forward));
    float3 up = cross(forward, right);
    
    float2 p = (uv - 0.5) * 2.0;
    p.x *= u.resolution.x / u.resolution.y;
    
    float3 rd = normalize(forward + p.x * right + p.y * up);
    
    // Background
    float3 col = getSunsetColor(uv);
    
    // Add grid glow to background
    float2 gridUV = p;
    gridUV.y += 0.5;
    float2 gridP = float2(gridUV.x * 4.0, gridUV.y * 2.0 + t * 2.0);
    float2 grid = abs(fract(gridP / 0.1 - 0.5) - 0.5) * 0.1;
    float g = min(grid.x, grid.y);
    g = smoothstep(0.02, 0.0, g);
    float gridFade = smoothstep(1.5, -0.5, p.y);
    g *= gridFade;
    col = mix(col, float3(0.0, 0.8, 1.0), g * 0.5);
    
    // Raymarch
    float d = 0.0;
    float td = 0.0;
    int material = 0;
    float3 p3 = ro;
    
    for(int i = 0; i < 100; i++) {
        p3 = ro + rd * td;
        d = map(p3, t, material);
        
        if(d < 0.001 || td > 20.0) break;
        td += d * 0.7;
    }
    
    if(td < 20.0) {
        float3 n = calcNormal(p3, t);
        float3 lightPos = float3(5.0, 10.0, 5.0);
        float3 toLight = normalize(lightPos - p3);
        
        float diff = max(dot(n, toLight), 0.0);
        float spec = pow(max(dot(reflect(-toLight, n), -rd), 0.0), 32.0);
        
        // Material colors
        float3 objColor = float3(0.5);
        float emissive = 0.0;
        
        if(material == 1) {
            objColor = float3(0.0, 0.9, 1.0);
            emissive = 0.3;
        } else if(material == 2) {
            objColor = float3(0.9, 0.85, 0.75);
            if(p3.z > 0.1 && abs(p3.y - 0.05) < 0.15 && abs(p3.x) < 0.2) {
                objColor = float3(0.2, 0.3, 0.5);
                emissive = 0.5;
            }
        } else if(material == 3) {
            float angle = atan2(p3.y, p3.x) + t;
            float3 rainbow[6] = {
                float3(1.0, 0.0, 0.0), float3(1.0, 0.5, 0.0),
                float3(1.0, 1.0, 0.0), float3(0.0, 1.0, 0.0),
                float3(0.0, 0.5, 1.0), float3(0.5, 0.0, 1.0)
            };
            int idx = int(fract(angle / 6.28) * 6.0) % 6;
            objColor = rainbow[idx];
            emissive = 0.4;
        } else if(material == 4) {
            float2 uv_win = fract(p3.xy * 10.0 + 0.5);
            if(uv_win.x < 0.5 && uv_win.y > 0.5) objColor = float3(1.0, 0.4, 0.0);
            else if(uv_win.x > 0.5 && uv_win.y > 0.5) objColor = float3(0.0, 0.8, 0.0);
            else if(uv_win.x < 0.5 && uv_win.y < 0.5) objColor = float3(0.0, 0.4, 1.0);
            else objColor = float3(1.0, 0.8, 0.0);
            emissive = 0.3;
        } else if(material == 5) {
            objColor = float3(0.95, 0.93, 0.9);
            float noise_val = snoise(p3 * 5.0);
            objColor *= 0.9 + 0.1 * noise_val;
        } else if(material == 6) {
            objColor = float3(0.1);
            if(abs(p3.y - 0.05) < 0.15 && abs(p3.x) < 0.3) {
                objColor = float3(0.9, 0.9, 0.8);
            }
        } else if(material == 7) {
            objColor = float3(0.0);
        }
        
        col = objColor * (diff + 0.2);
        col += float3(1.0) * spec * 0.5;
        col += objColor * emissive;
        
        // Fog
        float fog = 1.0 - exp(-td * 0.15);
        col = mix(col, getSunsetColor(uv), fog * 0.5);
    }
    
    // Scanlines
    float scanline = sin(uv.y * u.resolution.y * 1.5) * 0.03;
    col -= scanline;
    
    // Vignette
    float vignette = 1.0 - length(uv - 0.5) * 0.8;
    col *= vignette;
    
    col *= u.intensity;
    return float4(col, 1.0);
}
