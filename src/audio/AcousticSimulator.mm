//
//  AcousticSimulator.mm
//  ShaderCandy
//
//  Ray-traced acoustic simulation implementation
//

#import "AcousticSimulator.h"

@interface AcousticSimulator ()

@property(nonatomic, strong, nullable) id<MTLDevice> device;
@property(nonatomic, strong, nullable) id<MTLCommandQueue> commandQueue;
@property(nonatomic, strong, nullable) id<MTLComputePipelineState> rayTracePipeline;
@property(nonatomic, strong, nullable) id<MTLTexture> acousticFieldTexture;
@property(nonatomic, strong, nullable) id<MTLTexture> sceneGeometryTexture;
@property(nonatomic, assign) simd_float3 audioSourcePosition;
@property(nonatomic, assign) simd_float3 listenerPosition;
@property(nonatomic, assign) float sourceFrequency;
@property(nonatomic, assign) BOOL isInitialized;
@property(nonatomic, strong, nullable) id<MTLBuffer> rayBuffer;
@property(nonatomic, strong, nullable) id<MTLBuffer> reflectionBuffer;

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
    
    // Compile the audio ray-tracing compute pipeline
    id<MTLLibrary> library = [device newDefaultLibrary];
    if (!library) {
        if (error) {
            *error = [NSError errorWithDomain:@"AcousticSimulator"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to create Metal default library"}];
        }
        return NO;
    }
    
    id<MTLFunction> traceFunction = [library newFunctionWithName:@"traceAudioRays"];
    if (!traceFunction) {
        if (error) {
            *error = [NSError errorWithDomain:@"AcousticSimulator"
                                         code:-2
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to find traceAudioRays kernel function"}];
        }
        return NO;
    }
    
    NSError *pipelineError = nil;
    _rayTracePipeline = [device newComputePipelineStateWithFunction:traceFunction
                                                            error:&pipelineError];
    if (pipelineError) {
        if (error) *error = pipelineError;
        return NO;
    }
    
    // Create ray buffers
    NSUInteger rayCount = 1024;
    _rayBuffer = [device newBufferWithLength:rayCount * sizeof(simd_float4) * 2
                                      options:MTLResourceStorageModeShared];
    _reflectionBuffer = [device newBufferWithLength:rayCount * _maxReflections * sizeof(float)
                                             options:MTLResourceStorageModeShared];
    
    _isInitialized = YES;
    return YES;
}

- (void)shutdown {
    _rayBuffer = nil;
    _reflectionBuffer = nil;
    _acousticFieldTexture = nil;
    _sceneGeometryTexture = nil;
    _rayTracePipeline = nil;
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
    
    // Create or reuse acoustic field texture
    if (!_acousticFieldTexture) {
        MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR32Float
                                                                                          width:256
                                                                                         height:256
                                                                                      mipmapped:NO];
        desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
        _acousticFieldTexture = [_device newTextureWithDescriptor:desc];
    }
    
    // Run simulation
    [self simulateReflections];
    
    return _acousticFieldTexture;
}

- (float)getEnergyAtPosition:(simd_float3)position {
    // Calculate distance from source
    float distance = simd_length(position - _audioSourcePosition);
    
    // Inverse square law with absorption
    float energy = 1.0 / (1.0 + distance * distance * (1.0 - _absorption));
    
    // Apply room size limit
    if (distance > _roomSize) {
        energy *= exp(-(distance - _roomSize) * 0.5);
    }
    
    return energy;
}

- (float)getImpulseResponseAtPosition:(simd_float3)position time:(float)time {
    float distance = simd_length(position - _audioSourcePosition);
    float speedOfSound = 343.0; // m/s
    float travelTime = distance / speedOfSound;
    
    // Simple impulse response (direct sound + reflections)
    float impulse = 0.0;
    
    // Direct sound
    if (fabs(time - travelTime) < 0.001) {
        impulse = 1.0 * pow(1.0 - _absorption, distance / _roomSize);
    }
    
    // Early reflections
    for (int i = 1; i <= _maxReflections; i++) {
        float reflectionTime = travelTime + i * 0.01;
        if (fabs(time - reflectionTime) < 0.001) {
            impulse += pow(_absorption, i) * 0.5 / i;
        }
    }
    
    return impulse;
}

- (void)simulateReflections {
    if (!_rayTracePipeline) return;
    
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
    
    [encoder setComputePipelineState:_rayTracePipeline];
    [encoder setTexture:_acousticFieldTexture atIndex:0];
    [encoder setTexture:_sceneGeometryTexture atIndex:1];
    [encoder setBuffer:_rayBuffer offset:0 atIndex:0];
    [encoder setBuffer:_reflectionBuffer offset:0 atIndex:1];
    
    // Set simulation parameters
    float params[8] = {
        _audioSourcePosition.x, _audioSourcePosition.y, _audioSourcePosition.z,
        _sourceFrequency,
        _absorption, _scattering, (float)_maxReflections, _roomSize
    };
    [encoder setBytes:params length:sizeof(params) atIndex:2];
    
    MTLSize threadGroupSize = MTLSizeMake(16, 16, 1);
    MTLSize threadGroups = MTLSizeMake(16, 16, 1);
    
    [encoder dispatchThreadgroups:threadGroups threadsPerThreadgroup:threadGroupSize];
    [encoder endEncoding];
    
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
}

- (void)updateSimulation:(float)deltaTime {
    // Update dynamic aspects of simulation
    // This could include moving sources, time-varying absorption, etc.
}

@end
