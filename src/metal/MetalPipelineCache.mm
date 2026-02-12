//
//  MetalPipelineCache.mm
//  ShaderCandy
//
//  Pipeline state caching implementation
//

#import "MetalPipelineCache.h"
#import "MetalRenderer.h"

#pragma mark - Metal Pipeline Cache

@implementation MetalPipelineCache {
    NSMutableDictionary<NSString *, id<MTLRenderPipelineState>> *_renderPipelineCache;
    NSMutableDictionary<NSString *, id<MTLRenderPipelineState>> *_simPipelineCache;
    NSMutableDictionary<NSString *, id<MTLComputePipelineState>> *_computePipelineCache;
    NSMutableDictionary<NSString *, id<MTLRenderPipelineState>> *_particlePipelineCache;
    NSMutableDictionary<NSString *, NSData *> *_diskCache;
    NSString *_diskCachePath;
    dispatch_queue_t _cacheQueue;
}

+ (instancetype)sharedCache {
    static MetalPipelineCache *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MetalPipelineCache alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _enableDiskCache = YES;
        _enableAsyncCompilation = NO;
        _cachePath = @"~/Library/Caches/ShaderCandy/pipelines";
        _cacheQueue = dispatch_queue_create("com.shadercandy.pipelinecache", DISPATCH_QUEUE_SERIAL);

        _renderPipelineCache = [NSMutableDictionary dictionary];
        _simPipelineCache = [NSMutableDictionary dictionary];
        _computePipelineCache = [NSMutableDictionary dictionary];
        _particlePipelineCache = [NSMutableDictionary dictionary];
        _diskCache = [NSMutableDictionary dictionary];

        // Setup disk cache directory
        _diskCachePath = [_cachePath stringByExpandingTildeInPath];
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:_diskCachePath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];

        if (error) {
            NSLog(@"MetalPipelineCache: Failed to create cache directory: %@", error);
            _enableDiskCache = NO;
        }

        // Load disk cache
        [self loadDiskCache];

        // Note: Memory pressure monitoring on macOS would require IOKit
        // For now, manual cache control via clearAllCaches() is supported
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleMemoryWarning {
    NSLog(@"MetalPipelineCache: Memory warning, clearing memory cache");
    [self clearMemoryCache];
}

- (void)loadDiskCache {
    if (!_enableDiskCache) return;

    NSError *error = nil;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_diskCachePath
                                                                         error:&error];
    if (error) return;

    for (NSString *file in files) {
        if ([file hasSuffix:@".plist"]) {
            NSString *path = [_diskCachePath stringByAppendingPathComponent:file];
            NSDictionary *data = [NSDictionary dictionaryWithContentsOfFile:path];
            if (data) {
                NSString *shaderName = [file stringByDeletingPathExtension];
                _diskCache[shaderName] = data[@"pipelineData"];
            }
        }
    }

    NSLog(@"MetalPipelineCache: Loaded %lu pipeline states from disk", (unsigned long)_diskCache.count);
}

- (void)saveToDiskCache:(NSString *)shaderName data:(NSData *)data {
    if (!_enableDiskCache) return;

    dispatch_async(_cacheQueue, ^{
        NSString *path = [self->_diskCachePath stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%@.plist", shaderName]];
        NSDictionary *plist = @{@"pipelineData": data};
        [plist writeToFile:path atomically:YES];

        self->_diskCache[shaderName] = data;
    });
}

- (NSString *)cacheKeyForShader:(NSString *)shaderName
                    descriptor:(MTLRenderPipelineDescriptor *)descriptor {
    // Create a hash based on descriptor properties
    NSMutableString *key = [NSMutableString stringWithString:shaderName];
    [key appendFormat:@"_vfn_%@", descriptor.vertexFunction.name ?: @"nil"];
    [key appendFormat:@"_ffn_%@", descriptor.fragmentFunction.name ?: @"nil"];
    [key appendFormat:@"_fmt_%lu", (unsigned long)descriptor.colorAttachments[0].pixelFormat];
    [key appendFormat:@"_blend_%d", descriptor.colorAttachments[0].blendingEnabled];

    return key;
}

- (nullable MetalPipelineState *)pipelineForShader:(NSString *)shaderName
                                         device:(id<MTLDevice>)device
                                      library:(id<MTLLibrary>)library
                                   descriptor:(MTLRenderPipelineDescriptor *)descriptor
                                           error:(NSError **)error {
    MetalPipelineState *state = [[MetalPipelineState alloc] initWithShaderName:shaderName];

    NSString *key = [self cacheKeyForShader:shaderName descriptor:descriptor];

    // Check memory cache first
    if (_renderPipelineCache[key]) {
        state.renderPipeline = _renderPipelineCache[key];
    } else if (_diskCache[key]) {
        // Try disk cache - this is complex with Metal
        // For now, fall back to compilation
    }

    // Compile if not cached
    if (!state.renderPipeline) {
        NSError *compileError = nil;
        state.renderPipeline = [device newRenderPipelineStateWithDescriptor:descriptor
                                                                  error:&compileError];
        if (compileError) {
            if (error) *error = compileError;
            return nil;
        }

        // Cache in memory
        _renderPipelineCache[key] = state.renderPipeline;
    }

    // Check for simulation pipeline
    id<MTLFunction> simFunc = [library newFunctionWithName:@"fragment_sim"];
    if (simFunc) {
        NSString *simKey = [key stringByAppendingString:@"_sim"];
        if (!_simPipelineCache[simKey]) {
            descriptor.fragmentFunction = simFunc;
            descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA32Float;
            NSError *simError = nil;
            id<MTLRenderPipelineState> simPipeline = [device newRenderPipelineStateWithDescriptor:descriptor
                                                                                         error:&simError];
            if (!simError && simPipeline) {
                _simPipelineCache[simKey] = simPipeline;
                state.simulationPipeline = simPipeline;
            }
        } else {
            state.simulationPipeline = _simPipelineCache[simKey];
        }
    }

    // Check for particle pipelines
    id<MTLFunction> computeFunc = [library newFunctionWithName:@"compute_particles"];
    if (computeFunc) {
        NSString *computeKey = [key stringByAppendingString:@"_compute"];
        if (!_computePipelineCache[computeKey]) {
            NSError *computeError = nil;
            id<MTLComputePipelineState> computePipeline = [device newComputePipelineStateWithFunction:computeFunc
                                                                                             error:&computeError];
            if (!computeError && computePipeline) {
                _computePipelineCache[computeKey] = computePipeline;
                state.computePipeline = computePipeline;
            }
        } else {
            state.computePipeline = _computePipelineCache[computeKey];
        }

        // Particle render pipeline
        id<MTLFunction> vFunc = [library newFunctionWithName:@"vertex_particles"];
        id<MTLFunction> fFunc = [library newFunctionWithName:@"fragment_particles"];
        if (vFunc && fFunc) {
            NSString *particleKey = [key stringByAppendingString:@"_particle"];
            if (!_particlePipelineCache[particleKey]) {
                MTLRenderPipelineDescriptor *pDesc = [[MTLRenderPipelineDescriptor alloc] init];
                pDesc.vertexFunction = vFunc;
                pDesc.fragmentFunction = fFunc;
                pDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
                pDesc.colorAttachments[0].blendingEnabled = YES;

                NSError *pError = nil;
                id<MTLRenderPipelineState> particlePipeline = [device newRenderPipelineStateWithDescriptor:pDesc
                                                                                                   error:&pError];
                if (!pError && particlePipeline) {
                    _particlePipelineCache[particleKey] = particlePipeline;
                    state.particleRenderPipeline = particlePipeline;
                }
            } else {
                state.particleRenderPipeline = _particlePipelineCache[particleKey];
            }
        }
    }

    return state;
}

- (nullable MetalPipelineState *)computePipelineForShader:(NSString *)shaderName
                                                  device:(id<MTLDevice>)device
                                               function:(id<MTLFunction>)function
                                                    error:(NSError **)error {
    MetalPipelineState *state = [[MetalPipelineState alloc] initWithShaderName:shaderName];

    NSString *key = [NSString stringWithFormat:@"%@_compute_%@", shaderName, function.name];

    if (_computePipelineCache[key]) {
        state.computePipeline = _computePipelineCache[key];
    } else {
        NSError *compileError = nil;
        state.computePipeline = [device newComputePipelineStateWithFunction:function
                                                                  error:&compileError];
        if (compileError) {
            if (error) *error = compileError;
            return nil;
        }
        _computePipelineCache[key] = state.computePipeline;
    }

    return state;
}

- (void)prewarmPipelinesForShaders:(NSArray<NSString *> *)shaders
                           device:(id<MTLDevice>)device
                        libraries:(NSDictionary<NSString *, id<MTLLibrary>> *)libraries {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSString *shaderName in shaders) {
            id<MTLLibrary> library = libraries[shaderName];
            if (!library) continue;

            // Create minimal descriptor for pre-warming
            MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
            desc.vertexFunction = [library newFunctionWithName:@"vertex_main"];
            desc.fragmentFunction = [library newFunctionWithName:@"fragment_main"];
            desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

            NSError *error = nil;
            [self pipelineForShader:shaderName device:device library:library descriptor:desc error:&error];
            if (error) {
                NSLog(@"MetalPipelineCache: Failed to prewarm %@: %@", shaderName, error);
            }
        }

        NSLog(@"MetalPipelineCache: Pre-warmed %lu pipelines", (unsigned long)shaders.count);
    });
}

- (void)invalidateCacheForShader:(NSString *)shaderName {
    NSArray *keysToRemove = @[];
    for (NSString *key in _renderPipelineCache.allKeys) {
        if ([key hasPrefix:shaderName]) {
            keysToRemove = [keysToRemove arrayByAddingObject:key];
        }
    }
    [_renderPipelineCache removeObjectsForKeys:keysToRemove];

    keysToRemove = @[];
    for (NSString *key in _simPipelineCache.allKeys) {
        if ([key hasPrefix:shaderName]) {
            keysToRemove = [keysToRemove arrayByAddingObject:key];
        }
    }
    [_simPipelineCache removeObjectsForKeys:keysToRemove];

    keysToRemove = @[];
    for (NSString *key in _computePipelineCache.allKeys) {
        if ([key hasPrefix:shaderName]) {
            keysToRemove = [keysToRemove arrayByAddingObject:key];
        }
    }
    [_computePipelineCache removeObjectsForKeys:keysToRemove];

    keysToRemove = @[];
    for (NSString *key in _particlePipelineCache.allKeys) {
        if ([key hasPrefix:shaderName]) {
            keysToRemove = [keysToRemove arrayByAddingObject:key];
        }
    }
    [_particlePipelineCache removeObjectsForKeys:keysToRemove];

    // Remove from disk cache
    NSString *diskPath = [_diskCachePath stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%@.plist", shaderName]];
    [[NSFileManager defaultManager] removeItemAtPath:diskPath error:nil];
    [_diskCache removeObjectForKey:shaderName];

    NSLog(@"MetalPipelineCache: Invalidated cache for %@", shaderName);
}

- (void)clearAllCaches {
    [self clearMemoryCache];
    [self clearDiskCache];
}

- (void)clearMemoryCache {
    [_renderPipelineCache removeAllObjects];
    [_simPipelineCache removeAllObjects];
    [_computePipelineCache removeAllObjects];
    [_particlePipelineCache removeAllObjects];
    NSLog(@"MetalPipelineCache: Cleared memory cache");
}

- (void)clearDiskCache {
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:_diskCachePath error:&error];
    [[NSFileManager defaultManager] createDirectoryAtPath:_diskCachePath
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:&error];
    [_diskCache removeAllObjects];
    NSLog(@"MetalPipelineCache: Cleared disk cache");
}

- (NSUInteger)cacheSize {
    NSUInteger count = _renderPipelineCache.count + _simPipelineCache.count +
                       _computePipelineCache.count + _particlePipelineCache.count;
    return count;
}

@end
