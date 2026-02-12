//
//  ShaderCompiler.h
//  ShaderCandy
//
//  Shader compilation with pre-compiled metallib support and error mapping
//

#pragma once

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

@class MetalRendererError;

@interface ShaderCompilationResult : NSObject

@property(nonatomic, strong, nullable) id<MTLLibrary> library;
@property(nonatomic, strong, nullable) MetalRendererError *error;
@property(nonatomic, assign) BOOL fromPrecompiled;
@property(nonatomic, assign) NSTimeInterval compilationTime;

@end

@interface ShaderIncludeResolver : NSObject

- (NSString *)resolveInclude:(NSString *)includeName
                    inFile:(NSString *)sourceFile
                     error:(NSError **)error;

- (NSString *)preprocessSource:(NSString *)source
                       fileName:(NSString *)fileName
                          error:(NSError **)error;

@end

@interface ShaderCompiler : NSObject

@property(nonatomic, assign) BOOL preferPrecompiled;
@property(nonatomic, assign) BOOL developmentMode;
@property(nonatomic, strong) NSString *shaderSearchPath;
@property(nonatomic, strong) NSString *cachePath;

+ (instancetype)sharedCompiler;

- (ShaderCompilationResult *)compileShaderNamed:(NSString *)name
                                      device:(id<MTLDevice>)device
                                        error:(NSError **)error;

- (ShaderCompilationResult *)compileShaderFromSource:(NSString *)source
                                           fileName:(NSString *)fileName
                                              device:(id<MTLDevice>)device
                                                error:(NSError **)error;

- (ShaderCompilationResult *)compileShaderFromPath:(NSString *)path
                                           device:(id<MTLDevice>)device
                                             error:(NSError **)error;

- (ShaderCompilationResult *)compileShaderFromMetallib:(NSString *)path
                                               device:(id<MTLDevice>)device
                                                 error:(NSError **)error;

- (BOOL)precompileShaderNamed:(NSString *)name
                       outputPath:(NSString *)outputPath
                           error:(NSError **)error;

- (NSArray<NSString *> *)availableShaders;

- (void)clearCache;

@end

NS_ASSUME_NONNULL_END
