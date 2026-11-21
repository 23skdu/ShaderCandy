#include "base/common.glsl"

// SMPTE Calibration - Renders 8-bar 75% SMPTE color bars for HDR/SDR calibration

vec4 effect_main(vec2 centered, vec2 uv) {
    float x = uv.x;
    float y = uv.y;

    vec3 color = vec3(0.0);

    // 75% SMPTE color bars (8 vertical bars, each 1/8 of width)
    if (x < 0.125) {
        // White - 75%
        color = vec3(0.75);
    } else if (x < 0.25) {
        // Yellow
        color = vec3(0.75, 0.75, 0.0);
    } else if (x < 0.375) {
        // Cyan
        color = vec3(0.0, 0.75, 0.75);
    } else if (x < 0.5) {
        // Green
        color = vec3(0.0, 0.75, 0.0);
    } else if (x < 0.625) {
        // Magenta
        color = vec3(0.75, 0.0, 0.75);
    } else if (x < 0.75) {
        // Red
        color = vec3(0.75, 0.0, 0.0);
    } else if (x < 0.875) {
        // Blue
        color = vec3(0.0, 0.0, 0.75);
    } else {
        // Black - 75%
        color = vec3(0.075);
    }

    // Bottom 5% - black gradient
    if (y < 0.05) {
        color *= 0.1 * y / 0.05;
    }

    // Apply intensity scaling (corresponds to peakBrightness / 1000.0 in HDR)
    color *= intensity;

    return vec4(color, alpha);
}
