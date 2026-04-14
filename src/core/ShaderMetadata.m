//
//  ShaderMetadata.m
//  ShaderCandy
//
//  Parses shader metadata comments for per-shader settings
//

#import "ShaderMetadata.h"

@implementation ShaderMetadata

+ (instancetype)metadataFromShaderName:(NSString *)name source:(NSString *)source {
    ShaderMetadata *meta = [[ShaderMetadata alloc] init];
    meta.shaderName = name;
    meta.params = [NSMutableDictionary dictionary];

    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:@"@param\\s+(\\w+)\\s+(\\w+)\\s+([\\d.]+)\\s+([\\d.]+)"
        options:0
        error:nil];

    [regex enumerateMatchesInString:source
               options:0
                 range:NSMakeRange(0, source.length)
            usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        if (result.numberOfRanges >= 5) {
            NSString *type = [source substringWithRange:[result rangeAtIndex:1]];
            NSString *key = [source substringWithRange:[result rangeAtIndex:2]];
            NSString *min = [source substringWithRange:[result rangeAtIndex:3]];
            NSString *max = [source substringWithRange:[result rangeAtIndex:4]];

            ((NSMutableDictionary *)meta.params)[key] = @{
                @"type": type,
                @"min": @([min floatValue]),
                @"max": @([max floatValue])
            };
        }
    }];

    return meta;
}

- (nullable NSArray *)paramsForKey:(NSString *)key {
    return self.params[key];
}

@end