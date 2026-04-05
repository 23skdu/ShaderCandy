//
//  MetalPipelineCache.h
//  ShaderCandy
//
//  Pipeline state caching with in-memory and on-disk persistence
//

#pragma once

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

@class MetalPipelineState;

@interface MetalPipelineCache : NSObject

@property(nonatomic, assign) BOOL enableDiskCache;
@property(nonatomic, assign) BOOL enableAsyncCompilation;
@property(nonatomic, strong) NSString *cachePath;

+ (instancetype)sharedCache;

- (nullable MetalPipelineState *)
    pipelineForShader:(NSString *)shaderName
               device:(id<MTLDevice>)device
              library:(id<MTLLibrary>)library
           descriptor:(MTLRenderPipelineDescriptor *)descriptor
                error:(NSError **)error;

- (nullable MetalPipelineState *)computePipelineForShader:(NSString *)shaderName
                                                   device:(id<MTLDevice>)device
                                                 function:
                                                     (id<MTLFunction>)function
                                                    error:(NSError **)error;

- (void)prewarmPipelinesForShaders:(NSArray<NSString *> *)shaders
                            device:(id<MTLDevice>)device
                         libraries:(NSDictionary<NSString *, id<MTLLibrary>> *)
                                       libraries;

- (void)invalidateCacheForShader:(NSString *)shaderName;

- (void)clearAllCaches;

- (NSUInteger)cacheSize;

@end

NS_ASSUME_NONNULL_END
