//
//  ShaderMetadata.h
//  ShaderCandy
//
//  Parses shader metadata comments for per-shader settings
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ShaderMetadata : NSObject

@property(nonatomic, copy) NSString *shaderName;
@property(nonatomic, copy) NSDictionary<NSString *, NSArray *> *params;

+ (instancetype)metadataFromShaderName:(NSString *)name source:(NSString *)source;
- (nullable NSArray *)paramsForKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END