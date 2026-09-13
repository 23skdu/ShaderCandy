//
//  NeuralStyleEngine.h
//  ShaderCandy
//
//  CoreML neural style transfer engine
//

#import <CoreML/CoreML.h>
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

@interface NeuralStyleEngine : NSObject

@property(nonatomic, strong, readonly, nullable) id<MTLDevice> device;
@property(nonatomic, strong, readonly, nullable) id<MTLCommandQueue>
    commandQueue;
@property(nonatomic, strong, readonly, nullable) MLModel *currentModel;
@property(nonatomic, assign) float styleStrength;
@property(nonatomic, assign) BOOL useANEAcceleration;
@property(nonatomic, assign) BOOL useFP16Precision;

+ (instancetype)sharedEngine;

- (BOOL)initializeWithDevice:(id<MTLDevice>)device error:(NSError **)error;
- (void)shutdown;

- (BOOL)loadModelAtPath:(NSURL *)modelURL error:(NSError **)error;
- (BOOL)loadStyleNamed:(NSString *)styleName error:(NSError **)error;
- (BOOL)validateFP16ModelOptimization:(NSURL *)modelURL;
- (nullable CVPixelBufferRef)createOptimizedPixelBufferWithWidth:(size_t)width height:(size_t)height;

- (nullable id<MTLTexture>)applyStyle:(id<MTLTexture>)inputTexture
                        commandBuffer:(id<MTLCommandBuffer>)commandBuffer;

- (nullable id<MTLTexture>)applyStyle:(id<MTLTexture>)inputTexture
                        commandBuffer:(id<MTLCommandBuffer>)commandBuffer
                             strength:(float)strength;

- (void)prewarmModel;
- (void)unloadCurrentModel;

@end

NS_ASSUME_NONNULL_END
