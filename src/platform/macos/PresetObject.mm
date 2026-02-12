//
//  PresetObject.mm
//  ShaderCandy
//
//  Objective-C wrapper for C++ Preset
//

#import "PresetObject.h"
#import "../../config/PresetManager.h"

using namespace ShaderCandy::Config;

@implementation PresetObject

- (instancetype)init {
    self = [super init];
    if (self) {
        _version = @"1.0";
        _name = @"";
        _shaderName = @"plasma";
        _parameters = @{};
        _globalSettings = @{};
        _tags = @[];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
        _createdDate = [formatter stringFromDate:[NSDate date]];
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name shader:(NSString *)shaderName {
    self = [self init];
    if (self) {
        _name = name ?: @"Untitled";
        _shaderName = shaderName ?: @"plasma";
    }
    return self;
}

- (instancetype)initWithCPPConfig:(void *)config {
    self = [self init];
    if (self && config) {
        Preset *preset = static_cast<Preset *>(config);
        _version = [NSString stringWithUTF8String:preset->version.c_str()];
        _name = [NSString stringWithUTF8String:preset->name.c_str()];
        _shaderName = [NSString stringWithUTF8String:preset->shaderName.c_str()];
        _author = preset->author.empty() ? nil : [NSString stringWithUTF8String:preset->author.c_str()];
        _presetDescription = preset->description.empty() ? nil : [NSString stringWithUTF8String:preset->description.c_str()];
        _category = preset->category.empty() ? nil : [NSString stringWithUTF8String:preset->category.c_str()];
        _createdDate = preset->createdDate.empty() ? nil : [NSString stringWithUTF8String:preset->createdDate.c_str()];
        _modifiedDate = preset->modifiedDate.empty() ? nil : [NSString stringWithUTF8String:preset->modifiedDate.c_str()];
        
        // Convert parameters
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        for (const auto& kv : preset->floatParameters) {
            params[[NSString stringWithUTF8String:kv.first.c_str()]] = @(kv.second);
        }
        for (const auto& kv : preset->intParameters) {
            params[[NSString stringWithUTF8String:kv.first.c_str()]] = @(kv.second);
        }
        for (const auto& kv : preset->boolParameters) {
            params[[NSString stringWithUTF8String:kv.first.c_str()]] = @(kv.second);
        }
        _parameters = params;
        
        // Convert tags
        NSMutableArray *tags = [NSMutableArray array];
        for (const auto& tag : preset->tags) {
            [tags addObject:[NSString stringWithUTF8String:tag.c_str()]];
        }
        _tags = tags;
    }
    return self;
}

- (void *)toCPPConfig {
    Preset *preset = new Preset();
    
    preset->version = [_version UTF8String] ?: "1.0";
    preset->name = [_name UTF8String] ?: "";
    preset->shaderName = [_shaderName UTF8String] ?: "plasma";
    preset->author = _author ? [_author UTF8String] : "";
    preset->description = _presetDescription ? [_presetDescription UTF8String] : "";
    preset->category = _category ? [_category UTF8String] : "";
    preset->createdDate = _createdDate ? [_createdDate UTF8String] : "";
    preset->modifiedDate = _modifiedDate ? [_modifiedDate UTF8String] : "";
    
    // Convert parameters back
    for (NSString *key in _parameters) {
        id value = _parameters[key];
        std::string cppKey = [key UTF8String];
        if ([value isKindOfClass:[NSNumber class]]) {
            NSNumber *num = value;
            if (strcmp(num.objCType, @encode(BOOL)) == 0) {
                preset->boolParameters[cppKey] = num.boolValue;
            } else if (strcmp(num.objCType, @encode(int)) == 0) {
                preset->intParameters[cppKey] = num.intValue;
            } else {
                preset->floatParameters[cppKey] = num.floatValue;
            }
        }
    }
    
    // Convert tags
    for (NSString *tag in _tags) {
        preset->tags.push_back([tag UTF8String]);
    }
    
    return preset;
}

- (void)dealloc {
    // Clean up if needed
}

@end
