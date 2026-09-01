//
//  MetalPipelineCache.mm
//  ShaderCandy
//
//  Pipeline state caching with MTLBinaryArchive-based disk persistence
//

#import "MetalPipelineCache.h"
#import "MetalRenderer.h"

#pragma mark - Metal Pipeline Cache

@implementation MetalPipelineCache {
    NSMutableDictionary<NSString *, id<MTLRenderPipelineState>> *_renderPipelineCache;
    NSMutableDictionary<NSString *, id<MTLRenderPipelineState>> *_simPipelineCache;
    NSMutableDictionary<NSString *, id<MTLComputePipelineState>> *_computePipelineCache;
    NSMutableDictionary<NSString *, id<MTLRenderPipelineState>> *_particlePipelineCache;
    id<MTLBinaryArchive> _binaryArchive;
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

        // Setup disk cache directory
        _diskCachePath = [_cachePath stringByExpandingTildeInPath];
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:_diskCachePath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];

        if (error) {
#ifdef DEBUG
            NSLog(@"MetalPipelineCache: Failed to create cache directory: %@", error);
#endif
            _enableDiskCache = NO;
        }
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleMemoryWarning {
#ifdef DEBUG
    NSLog(@"MetalPipelineCache: Memory warning, clearing memory cache");
#endif
    [self clearMemoryCache];
}

#pragma mark - Binary Archive Management

- (nullable id<MTLBinaryArchive>)archiveForDevice:(id<MTLDevice>)device {
    if (_binaryArchive) return _binaryArchive;
    if (!_enableDiskCache) return nil;

    NSString *archivePath = [_diskCachePath stringByAppendingPathComponent:@"pipeline_archive.metallib"];
    NSURL *archiveURL = [NSURL fileURLWithPath:archivePath];

    NSError *error = nil;
    MTLBinaryArchiveDescriptor *desc = [[MTLBinaryArchiveDescriptor alloc] init];
    desc.url = archiveURL;

    // Try to load existing archive
    _binaryArchive = [device newBinaryArchiveWithDescriptor:desc error:&error];
    if (error) {
#ifdef DEBUG
        NSLog(@"MetalPipelineCache: Could not load binary archive: %@", error);
#endif
        // Create a fresh archive
        error = nil;
        _binaryArchive = [device newBinaryArchiveWithDescriptor:desc error:&error];
        if (error) {
#ifdef DEBUG
            NSLog(@"MetalPipelineCache: Could not create binary archive: %@", error);
#endif
            return nil;
        }
    }

    return _binaryArchive;
}

- (void)serializeArchive {
    if (!_binaryArchive || !_enableDiskCache) return;

    NSString *archivePath = [_diskCachePath stringByAppendingPathComponent:@"pipeline_archive.metallib"];
    NSURL *archiveURL = [NSURL fileURLWithPath:archivePath];

    NSError *error = nil;
    [_binaryArchive serializeToURL:archiveURL error:&error];
    if (error) {
#ifdef DEBUG
        NSLog(@"MetalPipelineCache: Failed to serialize archive: %@", error);
#endif
    }
}

#pragma mark - Cache Key

- (NSString *)cacheKeyForShader:(NSString *)shaderName
                    descriptor:(MTLRenderPipelineDescriptor *)descriptor {
    NSMutableString *key = [NSMutableString stringWithString:shaderName];
    [key appendFormat:@"_vfn_%@", descriptor.vertexFunction.name ?: @"nil"];
    [key appendFormat:@"_ffn_%@", descriptor.fragmentFunction.name ?: @"nil"];
    [key appendFormat:@"_fmt_%lu", (unsigned long)descriptor.colorAttachments[0].pixelFormat];
    [key appendFormat:@"_blend_%d", descriptor.colorAttachments[0].blendingEnabled];
    return key;
}

#pragma mark - Pipeline Retrieval

- (nullable MetalPipelineState *)pipelineForShader:(NSString *)shaderName
                                          device:(id<MTLDevice>)device
                                       library:(id<MTLLibrary>)library
                                    descriptor:(MTLRenderPipelineDescriptor *)descriptor
                                            error:(NSError **)error {
    MetalPipelineState *state = [[MetalPipelineState alloc] initWithShaderName:shaderName];
    NSString *key = [self cacheKeyForShader:shaderName descriptor:descriptor];

    // 1. Check in-memory cache
    if (_renderPipelineCache[key]) {
        state.renderPipeline = _renderPipelineCache[key];
    }

    // 2. Try binary archive (persistent cache)
    if (!state.renderPipeline && _enableDiskCache) {
        id<MTLBinaryArchive> archive = [self archiveForDevice:device];
        if (archive) {
            NSError *archiveError = nil;
            MTLBinaryArchiveDescriptor *archiveDesc = [[MTLBinaryArchiveDescriptor alloc] init];
            archiveDesc.url = [NSURL fileURLWithPath:[_diskCachePath stringByAppendingPathComponent:@"pipeline_archive.metallib"]];

            id<MTLBinaryArchive> loadedArchive = [device newBinaryArchiveWithDescriptor:archiveDesc error:&archiveError];
            if (!archiveError && loadedArchive) {
                NSError *pipelineError = nil;
                state.renderPipeline = [loadedArchive renderPipelineStateWithDescriptor:descriptor error:&pipelineError];
                if (pipelineError) {
#ifdef DEBUG
                    NSLog(@"MetalPipelineCache: Binary archive miss for %@: %@", shaderName, pipelineError);
#endif
                } else {
#ifdef DEBUG
                    NSLog(@"MetalPipelineCache: Restored %@ from binary archive", shaderName);
#endif
                }
            }
        }
    }

    // 3. Compile from source
    if (!state.renderPipeline) {
        NSError *compileError = nil;
        state.renderPipeline = [device newRenderPipelineStateWithDescriptor:descriptor
                                                                   error:&compileError];
        if (compileError) {
            if (error) *error = compileError;
            return nil;
        }

        // Add to binary archive for future persistence
        if (_enableDiskCache) {
            id<MTLBinaryArchive> archive = [self archiveForDevice:device];
            if (archive) {
                NSError *addError = nil;
                [archive addRenderPipelineStateWithDescriptor:descriptor error:&addError];
                if (addError) {
#ifdef DEBUG
                    NSLog(@"MetalPipelineCache: Failed to add to archive: %@", addError);
#endif
                }
                // Serialize periodically (every 10 pipelines)
                if ((_renderPipelineCache.count + _computePipelineCache.count) % 10 == 0) {
                    [self serializeArchive];
                }
            }
        }

        _renderPipelineCache[key] = state.renderPipeline;
    }

    // 4. Check for simulation pipeline
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

    // 5. Check for particle pipelines
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

            MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
            desc.vertexFunction = [library newFunctionWithName:@"vertex_main"];
            desc.fragmentFunction = [library newFunctionWithName:@"fragment_main"];
            desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

            NSError *error = nil;
            [self pipelineForShader:shaderName device:device library:library descriptor:desc error:&error];
            if (error) {
#ifdef DEBUG
                NSLog(@"MetalPipelineCache: Failed to prewarm %@: %@", shaderName, error);
#endif
            }
        }

        // Serialize archive after pre-warming
        [self serializeArchive];

#ifdef DEBUG
        NSLog(@"MetalPipelineCache: Pre-warmed %lu pipelines", (unsigned long)shaders.count);
#endif
    });
}

#pragma mark - Cache Invalidation

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

    // Invalidate and recreate binary archive
    _binaryArchive = nil;
    NSString *archivePath = [_diskCachePath stringByAppendingPathComponent:@"pipeline_archive.metallib"];
    [[NSFileManager defaultManager] removeItemAtPath:archivePath error:nil];

#ifdef DEBUG
    NSLog(@"MetalPipelineCache: Invalidated cache for %@", shaderName);
#endif
}

#pragma mark - Cache Management

- (void)clearAllCaches {
    [self clearMemoryCache];
    [self clearDiskCache];
}

- (void)clearMemoryCache {
    [_renderPipelineCache removeAllObjects];
    [_simPipelineCache removeAllObjects];
    [_computePipelineCache removeAllObjects];
    [_particlePipelineCache removeAllObjects];
    _binaryArchive = nil;
#ifdef DEBUG
    NSLog(@"MetalPipelineCache: Cleared memory cache");
#endif
}

- (void)clearDiskCache {
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:_diskCachePath error:&error];
    [[NSFileManager defaultManager] createDirectoryAtPath:_diskCachePath
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:&error];
    _binaryArchive = nil;
#ifdef DEBUG
    NSLog(@"MetalPipelineCache: Cleared disk cache");
#endif
}

- (NSUInteger)cacheSize {
    NSUInteger count = _renderPipelineCache.count + _simPipelineCache.count +
                       _computePipelineCache.count + _particlePipelineCache.count;
    return count;
}

@end
