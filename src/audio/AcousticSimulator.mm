//
//  AcousticSimulator.mm
//  ShaderCandy
//
//  MPS-based ray-traced acoustic simulation
//

#import "AcousticSimulator.h"
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>

@interface AcousticSimulator ()

@property(nonatomic, strong, nullable) id<MTLDevice> device;
@property(nonatomic, strong, nullable) id<MTLCommandQueue> commandQueue;
@property(nonatomic, strong, nullable) MPSRayIntersector *rayIntersector;
@property(nonatomic, strong, nullable) MPSTriangleIndexBuffer *accelerationStructure;
@property(nonatomic, strong, nullable) id<MTLTexture> acousticFieldTexture;
@property(nonatomic, strong, nullable) id<MTLTexture> sceneGeometryTexture;
@property(nonatomic, assign) simd_float3 audioSourcePosition;
@property(nonatomic, assign) simd_float3 listenerPosition;
@property(nonatomic, assign) float sourceFrequency;
@property(nonatomic, assign) BOOL isInitialized;
@property(nonatomic, strong, nullable) id<MTLBuffer> rayBuffer;
@property(nonatomic, strong, nullable) id<MTLBuffer> intersectionBuffer;
@property(nonatomic, strong, nullable) id<MTLBuffer> triangleBuffer;
@property(nonatomic, strong, nullable) id<MTLBuffer> triangleMaskBuffer;

@end

@implementation AcousticSimulator

+ (instancetype)sharedSimulator {
    static AcousticSimulator *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[AcousticSimulator alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _maxReflections = 4;
        _roomSize = 10.0;
        _absorption = 0.3;
        _scattering = 0.1;
        _enableDoppler = YES;
        _binauralEnabled = YES;
        _audioSourcePosition = simd_make_float3(0, 0, 0);
        _listenerPosition = simd_make_float3(0, 0, 0);
        _sourceFrequency = 440.0;
    }
    return self;
}

- (BOOL)initializeWithDevice:(id<MTLDevice>)device error:(NSError **)error {
    if (_isInitialized) return YES;

    _device = device;
    _commandQueue = [device newCommandQueue];

    // Create MPS ray intersector for hardware-accelerated ray tracing
    _rayIntersector = [[MPSRayIntersector alloc] initWithDevice:device];
    _rayIntersector.rayDataType = MPSRayDataTypeOriginMinDistanceDirectionMaxDistance;
    _rayIntersector.intersectionDataType = MPSIntersectionDataTypeDistancePrimitiveIndex;
    _rayIntersector.maxQueryCount = 1024;

    // Create acceleration structure from scene geometry
    [self buildAccelerationStructure];

    // Create ray buffers (shared for CPU/GPU access)
    NSUInteger rayCount = 1024;
    _rayBuffer = [device newBufferWithLength:rayCount * sizeof(MPSRayOriginMinDistanceDirectionMaxDistance)
                                     options:MTLResourceStorageModeShared];
    _intersectionBuffer = [device newBufferWithLength:rayCount * sizeof(MPSIntersectionDistancePrimitiveIndex)
                                              options:MTLResourceStorageModeShared];

    _isInitialized = YES;
    return YES;
}

- (void)buildAccelerationStructure {
    // Build a simple room geometry (box) as triangle mesh for ray tracing
    // 12 triangles forming a unit cube centered at origin
    float s = _roomSize * 0.5;
    simd_float3 vertices[] = {
        // Floor (y = -s)
        simd_make_float3(-s, -s, -s), simd_make_float3(s, -s, -s), simd_make_float3(s, -s, s),
        simd_make_float3(-s, -s, -s), simd_make_float3(s, -s, s), simd_make_float3(-s, -s, s),
        // Ceiling (y = s)
        simd_make_float3(-s, s, -s), simd_make_float3(s, s, s), simd_make_float3(s, s, -s),
        simd_make_float3(-s, s, -s), simd_make_float3(-s, s, s), simd_make_float3(s, s, s),
        // Front wall (z = s)
        simd_make_float3(-s, -s, s), simd_make_float3(s, -s, s), simd_make_float3(s, s, s),
        simd_make_float3(-s, -s, s), simd_make_float3(s, s, s), simd_make_float3(-s, s, s),
        // Back wall (z = -s)
        simd_make_float3(-s, -s, -s), simd_make_float3(s, s, -s), simd_make_float3(s, -s, -s),
        simd_make_float3(-s, -s, -s), simd_make_float3(-s, s, -s), simd_make_float3(s, s, -s),
        // Left wall (x = -s)
        simd_make_float3(-s, -s, -s), simd_make_float3(-s, -s, s), simd_make_float3(-s, s, s),
        simd_make_float3(-s, -s, -s), simd_make_float3(-s, s, s), simd_make_float3(-s, s, -s),
        // Right wall (x = s)
        simd_make_float3(s, -s, -s), simd_make_float3(s, s, s), simd_make_float3(s, -s, s),
        simd_make_float3(s, -s, -s), simd_make_float3(s, s, -s), simd_make_float3(s, s, s),
    };

    NSUInteger vertexCount = sizeof(vertices) / sizeof(vertices[0]);
    _triangleBuffer = [_device newBufferWithBytes:vertices
                                           length:vertexCount * sizeof(simd_float3)
                                          options:MTLResourceStorageModeShared];

    // Build acceleration structure using MPSBVHBuilder
    MPSTriangleAccelerationStructure *accelDesc = [[MPSTriangleAccelerationStructure alloc] initWithDevice:_device];
    accelDesc.triangleCount = vertexCount / 3;
    accelDesc.vertexBuffer = _triangleBuffer;
    accelDesc.vertexStride = sizeof(simd_float3);
    accelDesc.usage = MPSAccelerationStructureUsageUsage;

    _accelerationStructure = (MPSTriangleIndexBuffer *)accelDesc;
}

- (void)shutdown {
    _rayBuffer = nil;
    _intersectionBuffer = nil;
    _triangleBuffer = nil;
    _triangleMaskBuffer = nil;
    _acousticFieldTexture = nil;
    _sceneGeometryTexture = nil;
    _rayIntersector = nil;
    _accelerationStructure = nil;
    _commandQueue = nil;
    _device = nil;
    _isInitialized = NO;
}

- (void)setSceneGeometry:(id<MTLTexture>)geometryTexture {
    _sceneGeometryTexture = geometryTexture;
}

- (void)setAudioSource:(simd_float3)position frequency:(float)hz {
    _audioSourcePosition = position;
    _sourceFrequency = hz;
}

- (void)setListenerPosition:(simd_float3)position {
    _listenerPosition = position;
}

- (id<MTLTexture>)renderAcousticField {
    if (!_isInitialized) return nil;

    if (!_acousticFieldTexture) {
        MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR32Float
                                                                                           width:256
                                                                                          height:256
                                                                                       mipmapped:NO];
        desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
        _acousticFieldTexture = [_device newTextureWithDescriptor:desc];
    }

    [self simulateReflections];

    return _acousticFieldTexture;
}

- (float)getEnergyAtPosition:(simd_float3)position {
    float distance = simd_length(position - _audioSourcePosition);
    float energy = 1.0 / (1.0 + distance * distance * (1.0 - _absorption));

    if (distance > _roomSize) {
        energy *= exp(-(distance - _roomSize) * 0.5);
    }

    return energy;
}

- (float)getImpulseResponseAtPosition:(simd_float3)position time:(float)time {
    float distance = simd_length(position - _audioSourcePosition);
    float speedOfSound = 343.0;
    float travelTime = distance / speedOfSound;

    float impulse = 0.0;

    if (fabs(time - travelTime) < 0.001) {
        impulse = 1.0 * pow(1.0 - _absorption, distance / _roomSize);
    }

    for (int i = 1; i <= _maxReflections; i++) {
        float reflectionTime = travelTime + i * 0.01;
        if (fabs(time - reflectionTime) < 0.001) {
            impulse += pow(_absorption, i) * 0.5 / i;
        }
    }

    return impulse;
}

- (void)simulateReflections {
    if (!_rayIntersector || !_accelerationStructure) return;

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

    NSUInteger rayCount = 1024;
    MPSRayOriginMinDistanceDirectionMaxDistance *rays = _rayBuffer.contents;

    // Generate rays from audio source in all directions
    for (NSUInteger i = 0; i < rayCount; i++) {
        float theta = (float)i / (float)rayCount * 2.0 * M_PI;
        float phi = acosf(1.0f - 2.0f * (float)i / (float)rayCount);

        simd_float3 direction = simd_make_float3(
            sinf(phi) * cosf(theta),
            sinf(phi) * sinf(theta),
            cosf(phi)
        );

        rays[i].origin = _audioSourcePosition;
        rays[i].minDistance = 0.001;
        rays[i].direction = direction;
        rays[i].maxDistance = _roomSize * 2.0;
    }

    // Encode MPS ray intersection
    [_rayIntersector encodeIntersectionToCommandBuffer:commandBuffer
                                         rayBufferType:MPSRayBufferTypeFlat
                                           rayBuffer:_rayBuffer
                                        rayBufferOffset:0
                                   intersectionBuffer:_intersectionBuffer
                              intersectionBufferOffset:0
                                             rayCount:rayCount
                            accelerationStructure:_accelerationStructure];

    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];

    // Process intersections and accumulate acoustic energy
    MPSIntersectionDistancePrimitiveIndex *intersections = _intersectionBuffer.contents;

    for (NSUInteger i = 0; i < rayCount; i++) {
        float distance = intersections[i].distance;
        if (distance > 0 && distance < _roomSize * 2.0) {
            // Calculate absorption along ray path
            float absorptionFactor = pow(1.0 - _absorption, distance / _roomSize);

            // Map intersection to acoustic field texture
            simd_float3 hitPoint = _audioSourcePosition +
                simd_make_float3(
                    rays[i].direction.x * distance,
                    rays[i].direction.y * distance,
                    rays[i].direction.z * distance
                );

            // Write energy to acoustic field (simplified 2D projection)
            int texX = (int)((hitPoint.x / _roomSize + 0.5) * 255);
            int texY = (int)((hitPoint.z / _roomSize + 0.5) * 255);
            texX = MAX(0, MIN(255, texX));
            texY = MAX(0, MIN(255, texY));

            float energy = absorptionFactor * _sourceFrequency / 440.0;
            uint32_t pixel = texY * 256 + texX;
            float *texData = (float *)[_acousticFieldTexture contents];
            if (texData) {
                texData[pixel] += energy;
            }
        }
    }
}

- (void)updateSimulation:(float)deltaTime {
    // Update dynamic aspects of simulation
}

@end
