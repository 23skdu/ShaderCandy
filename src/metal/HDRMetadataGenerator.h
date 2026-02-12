//
//  HDRMetadataGenerator.h
//  ShaderCandy
//
//  HDR10 and Dolby Vision metadata generation
//

#import <Foundation/Foundation.h>

@interface HDRMetadataGenerator : NSObject

@property(nonatomic, assign) float displayMasteringMinLuminance;
@property(nonatomic, assign) float displayMasteringMaxLuminance;
@property(nonatomic, assign) float contentMaxFrameAvgLuminance;
@property(nonatomic, assign) float contentMaxLuminance;
@property(nonatomic, assign) float targetSystemDisplayMaxLuminance;

- (instancetype)init;

- (NSData *)generateHDR10Metadata;
- (NSData *)generateDolbyVisionMetadata;
- (NSData *)generateHLGMetadata;

- (void)setMasteringDisplayColorVolumeWithPrimaries:(const float *)primaries whitePoint:(const float *)whitePoint;

- (NSDictionary *)metadataAsDictionary;

@end
