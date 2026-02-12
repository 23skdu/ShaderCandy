//
//  audio_ray_tracing.metal
//  ShaderCandy
//
//  Compute shaders for audio ray tracing
//

#include <metal_stdlib>
using namespace metal;

struct AudioRay {
    float3 origin;
    float3 direction;
    float energy;
    float frequency;
    float time;
    int reflectionCount;
};

struct AcousticMaterial {
    float absorptionCoeff;
    float scatteringCoeff;
    float3 color;
};

struct AudioSource {
    float3 position;
    float frequency;
    float gain;
    float phase;
    int isActive;
};

// Generate audio rays from source
kernel void generateAudioRays(
    device AudioRay *rays [[buffer(0)]],
    constant AudioSource *sources [[buffer(1)]],
    constant int &sourceCount [[buffer(2)]],
    constant int &raysPerSource [[buffer(3)]],
    constant float &time [[buffer(4)]],
    uint2 gid [[thread_position_in_grid]]
)
{
    uint rayIndex = gid.x;
    uint totalRays = sourceCount * raysPerSource;

    if (rayIndex >= totalRays) return;

    uint sourceIndex = rayIndex / raysPerSource;
    uint rayInSource = rayIndex % raysPerSource;

    if (sourceIndex >= (uint)sourceCount) return;

    AudioSource source = sources[sourceIndex];
    if (!source.isActive) return;

    // Generate ray direction (spherical distribution)
    float phi = (float)rayInSource / (float)raysPerSource * 2.0 * M_PI_F;
    float theta = (float)(rayInSource % 16) / 16.0 * M_PI_F;

    float3 direction;
    direction.x = sin(theta) * cos(phi);
    direction.y = sin(theta) * sin(phi);
    direction.z = cos(theta);

    AudioRay ray;
    ray.origin = source.position;
    ray.direction = direction;
    ray.energy = source.gain;
    ray.frequency = source.frequency;
    ray.time = time;
    ray.reflectionCount = 0;

    rays[rayIndex] = ray;
}

// Trace rays through scene
kernel void traceAudioRays(
    device AudioRay *rays [[buffer(0)]],
    device const AcousticMaterial *materials [[buffer(1)]],
    texture2d<float, access::read> sceneMap [[texture(0)]],
    texture2d<float, access::write> acousticField [[texture(1)]],
    constant float3 &listenerPosition [[buffer(2)]],
    constant float &roomSize [[buffer(3)]],
    constant int &maxReflections [[buffer(4)]],
    uint2 gid [[thread_position_in_grid]]
)
{
    uint rayIndex = gid.x;
    if (rayIndex >= acousticField.get_width() * acousticField.get_height()) return;

    AudioRay ray = rays[rayIndex];

    // Simple ray marching
    float3 pos = ray.origin;
    float3 dir = ray.direction;
    float energy = ray.energy;

    for (int step = 0; step < 100; step++) {
        // March forward
        pos += dir * 0.1;

        // Check if reached listener
        float distToListener = length(pos - listenerPosition);
        if (distToListener < 0.5) {
            // Write to acoustic field
            uint2 fieldPos = uint2(rayIndex % acousticField.get_width(), rayIndex / acousticField.get_width());
            float current = acousticField.read(fieldPos).r;
            acousticField.write(float4(current + energy, 0, 0, 1), fieldPos);
            break;
        }

        // Check bounds
        if (length(pos) > roomSize) {
            break;
        }

        // Sample scene for collision (simplified)
        float2 uv = float2(pos.x / roomSize + 0.5, pos.z / roomSize + 0.5);
        float4 sceneSample = sceneMap.sample(sampler(filter::linear), uv);

        if (sceneSample.r > 0.5) {
            // Hit surface - reflect
            float absorption = 0.3;
            energy *= (1.0 - absorption);

            // Simple reflection
            dir = reflect(dir, float3(0, 1, 0));

            ray.reflectionCount++;
            if (ray.reflectionCount >= maxReflections) {
                break;
            }
        }
    }

    rays[rayIndex] = ray;
}

// Apply impulse response convolution
kernel void applyImpulseResponse(
    device float *inputBuffer [[buffer(0)]],
    device float *outputBuffer [[buffer(1)]],
    device const float *impulseResponse [[buffer(2)]],
    constant int &bufferSize [[buffer(3)]],
    constant int &irLength [[buffer(4)]],
    uint gid [[thread_position_in_grid]]
{
    if (gid >= (uint)bufferSize) return;

    float sum = 0.0;
    for (int i = 0; i < irLength; i++) {
        int idx = gid - i;
        if (idx >= 0) {
            sum += inputBuffer[idx] * impulseResponse[i];
        }
    }

    outputBuffer[gid] = sum;
}

// Generate binaural audio (HRTF)
kernel void applyBinauralHRTF(
    device float *monoInput [[buffer(0)]],
    device float *leftOutput [[buffer(1)]],
    device float *rightOutput [[buffer(2)]],
    device const float *hrtfLeft [[buffer(3)]],
    device const float *hrtfRight [[buffer(4)]],
    constant int &bufferSize [[buffer(5)]],
    constant int &hrtfLength [[buffer(6)]],
    constant float &azimuth [[buffer(7)]],
    constant float &elevation [[buffer(8)]],
    uint gid [[thread_position_in_grid]]
)
{
    if (gid >= (uint)bufferSize) return;

    float leftSum = 0.0;
    float rightSum = 0.0;

    for (int i = 0; i < hrtfLength; i++) {
        int idx = gid - i;
        if (idx >= 0) {
            leftSum += monoInput[idx] * hrtfLeft[i];
            rightSum += monoInput[idx] * hrtfRight[i];
        }
    }

    leftOutput[gid] = leftSum;
    rightOutput[gid] = rightSum;
}
