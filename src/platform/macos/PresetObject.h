//
//  PresetObject.h
//  ShaderCandy
//
//  Objective-C wrapper for C++ Preset
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PresetObject : NSObject

@property(nonatomic, copy) NSString *version;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy, nullable) NSString *author;
@property(nonatomic, copy, nullable) NSString *presetDescription;
@property(nonatomic, copy) NSString *shaderName;
@property(nonatomic, strong) NSDictionary<NSString *, id> *parameters;
@property(nonatomic, strong) NSDictionary<NSString *, id> *globalSettings;
@property(nonatomic, copy) NSString *createdDate;
@property(nonatomic, copy, nullable) NSString *modifiedDate;
@property(nonatomic, copy, nullable) NSString *category;
@property(nonatomic, copy, nullable) NSString *filePath;
@property(nonatomic, strong) NSArray<NSString *> *tags;

- (instancetype)initWithName:(NSString *)name shader:(NSString *)shaderName;
- (instancetype)initWithCPPConfig:(void *)config;

- (void *)toCPPConfig;

@end

NS_ASSUME_NONNULL_END
