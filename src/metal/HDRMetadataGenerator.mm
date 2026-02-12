//
//  HDRMetadataGenerator.mm
//  ShaderCandy
//
//  HDR metadata generation implementation
//

#import "HDRMetadataGenerator.h"

// SMPTE ST 2086 Mastering Display Metadata
struct HDR10Metadata {
    uint16_t displayPrimaryRX;
    uint16_t displayPrimaryRY;
    uint16_t displayPrimaryGX;
    uint16_t displayPrimaryGY;
    uint16_t displayPrimaryBX;
    uint16_t displayPrimaryBY;
    uint16_t whitePointX;
    uint16_t whitePointY;
    uint16_t maxDisplayMasteringLuminance;
    uint16_t minDisplayMasteringLuminance;
    uint16_t maxContentLightLevel;
    uint16_t maxFrameAverageLightLevel;
};

@implementation HDRMetadataGenerator {
    float _masteringPrimaries[3][2];
    float _whitePoint[2];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Default to D65 white point and Rec. 2020 primaries
        _displayMasteringMinLuminance = 0.005;
        _displayMasteringMaxLuminance = 1000.0;
        _contentMaxFrameAvgLuminance = 400.0;
        _contentMaxLuminance = 1000.0;
        _targetSystemDisplayMaxLuminance = 1000.0;

        // D65 white point
        _whitePoint[0] = 0.3127;
        _whitePoint[1] = 0.3290;

        // Rec. 2020 primaries
        _masteringPrimaries[0][0] = 0.708;  // R x
        _masteringPrimaries[0][1] = 0.292;  // R y
        _masteringPrimaries[1][0] = 0.170;  // G x
        _masteringPrimaries[1][1] = 0.797;  // G y
        _masteringPrimaries[2][0] = 0.131;  // B x
        _masteringPrimaries[2][1] = 0.046;  // B y
    }
    return self;
}

- (NSData *)generateHDR10Metadata {
    struct HDR10Metadata metadata;

    // Convert to SMPTE ST 2086 format (0.00002 precision)
    metadata.displayPrimaryRX = (uint16_t)(_masteringPrimaries[0][0] * 50000);
    metadata.displayPrimaryRY = (uint16_t)(_masteringPrimaries[0][1] * 50000);
    metadata.displayPrimaryGX = (uint16_t)(_masteringPrimaries[1][0] * 50000);
    metadata.displayPrimaryGY = (uint16_t)(_masteringPrimaries[1][1] * 50000);
    metadata.displayPrimaryBX = (uint16_t)(_masteringPrimaries[2][0] * 50000);
    metadata.displayPrimaryBY = (uint16_t)(_masteringPrimaries[2][1] * 50000);
    metadata.whitePointX = (uint16_t)(_whitePoint[0] * 50000);
    metadata.whitePointY = (uint16_t)(_whitePoint[1] * 50000);

    // Luminance in 0.0001 cd/m2 units
    metadata.maxDisplayMasteringLuminance = (uint16_t)(_displayMasteringMaxLuminance);
    metadata.minDisplayMasteringLuminance = (uint16_t)(_displayMasteringMinLuminance * 10000);

    // Content light level in cd/m2
    metadata.maxContentLightLevel = (uint16_t)_contentMaxLuminance;
    metadata.maxFrameAverageLightLevel = (uint16_t)_contentMaxFrameAvgLuminance;

    return [NSData dataWithBytes:&metadata length:sizeof(metadata)];
}

- (NSData *)generateDolbyVisionMetadata {
    // Dolby Vision uses similar metadata with additional levels
    NSMutableData *data = [NSMutableData data];

    // Header
    uint8_t header[4] = {0x00, 0x00, 0x00, 0x01};
    [data appendBytes:header length:4];

    // Add HDR10 base metadata
    NSData *hdr10Data = [self generateHDR10Metadata];
    [data appendData:hdr10Data];

    // Dolby Vision specific: Profile 5 or 8
    uint8_t dvProfile = 8;
    [data appendBytes:&dvProfile length:1];

    // Level
    uint8_t dvLevel = 6;
    [data appendBytes:&dvLevel length:1];

    // RPU (Reference Processing Unit) flag
    uint8_t rpuPresent = 1;
    [data appendBytes:&rpuPresent length:1];

    return data;
}

- (NSData *)generateHLGMetadata {
    // HLG (Hybrid Log-Gamma) metadata is simpler
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];

    metadata[@"transfer_function"] = @"HLG";
    metadata[@"reference_white_level"] = @203;
    metadata[@"reference_black_level"] = @0;
    metadata[@"display_gamma"] = @1.2;

    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:metadata options:0 error:&error];

    return jsonData ?: [NSData data];
}

- (void)setMasteringDisplayColorVolumeWithPrimaries:(const float *)primaries whitePoint:(const float *)whitePoint {
    if (primaries) {
        for (int i = 0; i < 3; i++) {
            _masteringPrimaries[i][0] = primaries[i * 2];
            _masteringPrimaries[i][1] = primaries[i * 2 + 1];
        }
    }

    if (whitePoint) {
        _whitePoint[0] = whitePoint[0];
        _whitePoint[1] = whitePoint[1];
    }
}

- (NSDictionary *)metadataAsDictionary {
    return @{
        @"displayMasteringMinLuminance": @(_displayMasteringMinLuminance),
        @"displayMasteringMaxLuminance": @(_displayMasteringMaxLuminance),
        @"contentMaxFrameAvgLuminance": @(_contentMaxFrameAvgLuminance),
        @"contentMaxLuminance": @(_contentMaxLuminance),
        @"targetSystemDisplayMaxLuminance": @(_targetSystemDisplayMaxLuminance),
        @"masteringPrimaries": @[
            @[@(_masteringPrimaries[0][0]), @(_masteringPrimaries[0][1])],
            @[@(_masteringPrimaries[1][0]), @(_masteringPrimaries[1][1])],
            @[@(_masteringPrimaries[2][0]), @(_masteringPrimaries[2][1])]
        ],
        @"whitePoint": @[@(_whitePoint[0]), @(_whitePoint[1])]
    };
}

@end
