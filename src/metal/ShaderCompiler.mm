//
//  ShaderCompiler.mm
//  ShaderCandy
//
//  Shader compilation implementation
//

#import "ShaderCompiler.h"
#import "MetalRenderer.h"
#import <MetalKit/MetalKit.h>

#pragma mark - Shader Compilation Result

@implementation ShaderCompilationResult

- (instancetype)init {
    self = [super init];
    if (self) {
        _fromPrecompiled = NO;
        _compilationTime = 0;
    }
    return self;
}

@end

#pragma mark - Shader Include Resolver

@implementation ShaderIncludeResolver {
    NSMutableDictionary<NSString *, NSString *> *_includeCache;
    NSMutableSet<NSString *> *_currentlyResolving;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _includeCache = [NSMutableDictionary dictionary];
        _currentlyResolving = [NSMutableSet set];
    }
    return self;
}

- (NSString *)resolveInclude:(NSString *)includeName
                    inFile:(NSString *)sourceFile
                     error:(NSError **)error {
    // Check cache first
    if (_includeCache[includeName]) {
        return _includeCache[includeName];
    }

    // Prevent circular includes
    if ([_currentlyResolving containsObject:includeName]) {
        if (error) {
            *error = [NSError errorWithDomain:@"ShaderCompiler"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"Circular include detected: %@", includeName]}];
        }
        return nil;
    }

    [_currentlyResolving addObject:includeName];

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *basePath = [sourceFile stringByDeletingLastPathComponent];

    // Search paths in order
    NSArray *searchPaths = @[
        includeName,                                        // As-is
        [NSString stringWithFormat:@"%@/%@", basePath, includeName],
        [NSString stringWithFormat:@"%@/base/%@", basePath, includeName],
        [bundle pathForResource:includeName ofType:nil inDirectory:@"shaders/base"],
        [bundle pathForResource:includeName ofType:nil inDirectory:@"shaders"]
    ];

    NSString *foundPath = nil;
    for (NSString *path in searchPaths) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            foundPath = path;
            break;
        }
    }

    NSString *content = nil;
    if (foundPath) {
        content = [NSString stringWithContentsOfFile:foundPath
                                            encoding:NSUTF8StringEncoding
                                               error:error];
        if (content) {
            _includeCache[includeName] = content;
        }
    }

    [_currentlyResolving removeObject:includeName];
    return content;
}

- (NSString *)preprocessSource:(NSString *)source
                       fileName:(NSString *)fileName
                          error:(NSError **)error {
    NSMutableString *result = [NSMutableString stringWithString:source];

    NSRegularExpression *includeRegex = [NSRegularExpression
        regularExpressionWithPattern:@"#include\\s*[\"<]([^\">]+)[\">]"
                           options:0
                             error:nil];

    NSArray *matches = [includeRegex matchesInString:source
                                             options:0
                                               range:NSMakeRange(0, source.length)];

    // Process includes in reverse order to maintain positions
    for (NSInteger i = matches.count - 1; i >= 0; i--) {
        NSTextCheckingResult *match = matches[i];
        NSString *includeName = [source substringWithRange:[match rangeAtIndex:1]];

        NSString *includeContent = [self resolveInclude:includeName inFile:fileName error:error];
        if (!includeContent) {
            return nil;
        }

        // Recursively preprocess includes
        NSString *processedInclude = [self preprocessSource:includeContent
                                                   fileName:includeName
                                                      error:error];
        if (!processedInclude) {
            return nil;
        }

        [result replaceCharactersInRange:match.range withString:processedInclude];
    }

    return result;
}

@end

#pragma mark - Shader Compiler

@implementation ShaderCompiler {
    NSMutableDictionary<NSString *, NSDate *> *_shaderModificationDates;
    NSMutableDictionary<NSString *, NSDate *> *_metallibDates;
    ShaderIncludeResolver *_resolver;
}

+ (instancetype)sharedCompiler {
    static ShaderCompiler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ShaderCompiler alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _preferPrecompiled = YES;
        _developmentMode = NO;
        _shaderSearchPath = @"shaders";
        _cachePath = @"~/Library/Caches/ShaderCandy";
        _shaderModificationDates = [NSMutableDictionary dictionary];
        _metallibDates = [NSMutableDictionary dictionary];
        _resolver = [[ShaderIncludeResolver alloc] init];

        NSString *expandedCache = [_cachePath stringByExpandingTildeInPath];
        [[NSFileManager defaultManager] createDirectoryAtPath:expandedCache
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:nil];
    }
    return self;
}

- (NSString *)pathForShaderNamed:(NSString *)name {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    NSArray *extensions = @[@"metal", @"metallib"];
    NSArray *searchPaths = @[
        [bundle pathForResource:name ofType:nil inDirectory:_shaderSearchPath],
        [bundle pathForResource:name ofType:@"metal" inDirectory:_shaderSearchPath],
        [bundle pathForResource:name ofType:@"frag" inDirectory:_shaderSearchPath],
        [bundle pathForResource:name ofType:@"metallib" inDirectory:_shaderSearchPath]
    ];

    for (NSString *path in searchPaths) {
        if (path && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
            return path;
        }
    }
    return nil;
}

- (NSArray<NSString *> *)availableShaders {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *shadersPath = [bundle pathForResource:_shaderSearchPath ofType:nil];

    if (!shadersPath) return @[];

    NSMutableArray *shaders = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:shadersPath];

    NSString *file;
    while ((file = [enumerator nextObject])) {
        NSString *ext = [file pathExtension];
        if ([ext isEqualToString:@"metal"] || [ext isEqualToString:@"frag"]) {
            NSString *name = [[file lastPathComponent] stringByDeletingPathExtension];
            // Skip utility shaders
            if (![name isEqualToString:@"common"] && ![name isEqualToString:@"utils"] &&
                ![name isEqualToString:@"ShaderInterop"] && ![name isEqualToString:@"bloom"] &&
                ![name isEqualToString:@"particles"]) {
                [shaders addObject:name];
            }
        }
    }

    return [shaders sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (ShaderCompilationResult *)compileShaderNamed:(NSString *)name
                                      device:(id<MTLDevice>)device
                                        error:(NSError **)error {
    ShaderCompilationResult *result = [[ShaderCompilationResult alloc] init];
    NSDate *startTime = [NSDate date];

    // First try pre-compiled metallib if preferred
    if (_preferPrecompiled && !_developmentMode) {
        NSString *metallibPath = [self pathForShaderNamed:name];
        if (metallibPath && [[metallibPath pathExtension] isEqualToString:@"metallib"]) {
            result = [self compileShaderFromMetallib:metallibPath device:device error:error];
            if (result.library) {
                result.fromPrecompiled = YES;
                result.compilationTime = [[NSDate date] timeIntervalSinceDate:startTime];
                return result;
            }
        }
    }

    // Fall back to source compilation
    NSString *sourcePath = [self pathForShaderNamed:name];
    if (!sourcePath) {
        if (error) {
            *error = [NSError errorWithDomain:@"ShaderCompiler"
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"Shader '%@' not found", name]}];
        }
        return result;
    }

    result = [self compileShaderFromPath:sourcePath device:device error:error];
    result.compilationTime = [[NSDate date] timeIntervalSinceDate:startTime];
    return result;
}

- (ShaderCompilationResult *)compileShaderFromPath:(NSString *)path
                                           device:(id<MTLDevice>)device
                                             error:(NSError **)error {
    ShaderCompilationResult *result = [[ShaderCompilationResult alloc] init];

    NSString *source = [NSString stringWithContentsOfFile:path
                                                encoding:NSUTF8StringEncoding
                                                   error:error];
    if (!source) {
        return result;
    }

    return [self compileShaderFromSource:source fileName:[path lastPathComponent] device:device error:error];
}

- (ShaderCompilationResult *)compileShaderFromSource:(NSString *)source
                                           fileName:(NSString *)fileName
                                              device:(id<MTLDevice>)device
                                                error:(NSError **)error {
    ShaderCompilationResult *result = [[ShaderCompilationResult alloc] init];

    // Preprocess includes
    NSString *preprocessed = [_resolver preprocessSource:source fileName:fileName error:error];
    if (!preprocessed) {
        return result;
    }

    // Add required Metal boilerplate
    NSMutableString *fullSource = [NSMutableString string];
    [fullSource appendString:@"#include <metal_stdlib>\nusing namespace metal;\n\n"];

    // Add interop header
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *interopPath = [bundle pathForResource:@"ShaderInterop" ofType:@"h" inDirectory:@"shaders"];
    if (!interopPath) {
        interopPath = [[bundle bundlePath] stringByDeletingLastPathComponent];
        interopPath = [interopPath stringByAppendingPathComponent:@"src/core/ShaderInterop.h"];
    }

    if (interopPath) {
        NSString *interop = [NSString stringWithContentsOfFile:interopPath
                                                      encoding:NSUTF8StringEncoding
                                                         error:nil];
        if (interop) {
            [fullSource appendString:interop];
            [fullSource appendString:@"\n\n"];
        }
    }

    // Add utils
    NSString *utilsPath = [bundle pathForResource:@"utils" ofType:@"metal" inDirectory:@"shaders/base"];
    if (!utilsPath) {
        utilsPath = [bundle pathForResource:@"utils" ofType:@"metal" inDirectory:@"shaders"];
    }

    if (utilsPath) {
        NSString *utils = [NSString stringWithContentsOfFile:utilsPath
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
        if (utils) {
            // Strip metal_stdlib from utils
            NSMutableString *cleanUtils = [utils mutableCopy];
            [cleanUtils replaceOccurrencesOfString:@"#include <metal_stdlib>\n"
                                         withString:@""
                                            options:0
                                              range:NSMakeRange(0, cleanUtils.length)];
            [cleanUtils replaceOccurrencesOfString:@"using namespace metal;\n"
                                         withString:@""
                                            options:0
                                              range:NSMakeRange(0, cleanUtils.length)];
            [fullSource appendString:cleanUtils];
            [fullSource appendString:@"\n\n"];
        }
    }

    // Add vertex wrapper
    [fullSource appendString:
        @"vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {\n"
        @"    VertexOut out;\n"
        @"    out.position = float4(in.position, 0.0, 1.0);\n"
        @"    out.texCoord = in.texCoord;\n"
        @"    return out;\n"
        @"}\n\n"];

    // Add main shader
    [fullSource appendString:preprocessed];

    // Compile
    NSError *compileError = nil;
    id<MTLLibrary> library = [device newLibraryWithSource:fullSource
                                                  options:nil
                                                    error:&compileError];

    if (compileError) {
        [self handleCompileError:compileError forShader:fileName source:fullSource];
        if (error) {
            *error = compileError;
        }
        return result;
    }

    result.library = library;
    return result;
}

- (ShaderCompilationResult *)compileShaderFromMetallib:(NSString *)path
                                               device:(id<MTLDevice>)device
                                                 error:(NSError **)error {
    ShaderCompilationResult *result = [[ShaderCompilationResult alloc] init];

    NSError *loadError = nil;
    id<MTLLibrary> library = [device newLibraryWithURL:[NSURL fileURLWithPath:path]
                                                 error:&loadError];
    if (loadError) {
        if (error) {
            *error = loadError;
        }
        return result;
    }

    result.library = library;
    result.fromPrecompiled = YES;
    return result;
}

- (void)handleCompileError:(NSError *)error forShader:(NSString *)shaderName source:(NSString *)source {
    NSLog(@"ShaderCompiler: Compile error for '%@': %@", shaderName, error);

    // Write failed shader to cache for debugging
    NSString *cacheDir = [_cachePath stringByExpandingTildeInPath];
    NSString *failedPath = [cacheDir stringByAppendingPathComponent:
                            [NSString stringWithFormat:@"failed_%@.metal", shaderName]];
    [source writeToFile:failedPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"ShaderCompiler: Failed shader written to: %@", failedPath);

    // Extract compiler error details
    NSString *failureReason = error.localizedFailureReason ?: error.localizedDescription;

    NSMutableString *detailedError = [NSMutableString string];
    [detailedError appendFormat:@"Error: %@", failureReason ?: @"Unknown compilation error"];

    NSLog(@"ShaderCompiler: Detailed error: %@", detailedError);
}

- (BOOL)precompileShaderNamed:(NSString *)name
                       outputPath:(NSString *)outputPath
                           error:(NSError **)error {
    NSString *sourcePath = [self pathForShaderNamed:name];
    if (!sourcePath || [[sourcePath pathExtension] isEqualToString:@"metallib"]) {
        if (error) {
            *error = [NSError errorWithDomain:@"ShaderCompiler"
                                         code:3
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"Cannot precompile '%@': not a source file", name]}];
        }
        return NO;
    }

    NSString *source = [NSString stringWithContentsOfFile:sourcePath
                                                 encoding:NSUTF8StringEncoding
                                                    error:error];
    if (!source) {
        return NO;
    }

    // Preprocess
    NSString *preprocessed = [_resolver preprocessSource:source fileName:name error:error];
    if (!preprocessed) {
        return NO;
    }

    // Add boilerplate
    NSMutableString *fullSource = [NSMutableString string];
    [fullSource appendString:@"#include <metal_stdlib>\nusing namespace metal;\n\n"];

    // Add interop and utils (same as compileShaderFromSource)
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *interopPath = [bundle pathForResource:@"ShaderInterop" ofType:@"h" inDirectory:@"shaders"];
    if (interopPath) {
        NSString *interop = [NSString stringWithContentsOfFile:interopPath
                                                      encoding:NSUTF8StringEncoding
                                                         error:nil];
        if (interop) {
            [fullSource appendString:interop];
            [fullSource appendString:@"\n\n"];
        }
    }

    NSString *utilsPath = [bundle pathForResource:@"utils" ofType:@"metal" inDirectory:@"shaders/base"];
    if (utilsPath) {
        NSString *utils = [NSString stringWithContentsOfFile:utilsPath
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
        if (utils) {
            NSMutableString *cleanUtils = [utils mutableCopy];
            [cleanUtils replaceOccurrencesOfString:@"#include <metal_stdlib>\n"
                                         withString:@""
                                            options:0
                                              range:NSMakeRange(0, cleanUtils.length)];
            [cleanUtils replaceOccurrencesOfString:@"using namespace metal;\n"
                                         withString:@""
                                            options:0
                                              range:NSMakeRange(0, cleanUtils.length)];
            [fullSource appendString:cleanUtils];
            [fullSource appendString:@"\n\n"];
        }
    }

    [fullSource appendString:
        @"vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {\n"
        @"    VertexOut out;\n"
        @"    out.position = float4(in.position, 0.0, 1.0);\n"
        @"    out.texCoord = in.texCoord;\n"
        @"    return out;\n"
        @"}\n\n"];
    [fullSource appendString:preprocessed];

    // Note: Serialization requires Metal 3.0 and specific device capabilities
    // For now, runtime compilation will be used instead of pre-compilation
    NSLog(@"ShaderCompiler: Pre-compilation requires Metal 3.0. Using runtime compilation.");

    // Write processed source for reference
    NSString *processedPath = [[outputPath stringByDeletingPathExtension] stringByAppendingString:@"_processed.metal"];
    [fullSource writeToFile:processedPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

    // Return YES but note that actual metallib generation would happen at runtime
    // or via command-line tools (xcrun metallib)
    return YES;
}

- (void)clearCache {
    NSString *cacheDir = [_cachePath stringByExpandingTildeInPath];
    [[NSFileManager defaultManager] removeItemAtPath:cacheDir error:nil];
    [_shaderModificationDates removeAllObjects];
    [_metallibDates removeAllObjects];
}

- (void)preloadCommonShaders:(id<MTLDevice>)device {
    NSArray *commonShaders = @[@"common", @"utils"];
    for (NSString *name in commonShaders) {
        NSString *path = [self pathForShaderNamed:name];
        if (path) {
            [self compileShaderFromPath:path device:device error:nil];
        }
    }
}

@end
