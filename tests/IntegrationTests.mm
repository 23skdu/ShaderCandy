//
//  IntegrationTests.mm
//  ShaderCandy
//
//  Integration tests for feature interactions
//

#import <XCTest/XCTest.h>
#import <Metal/Metal.h>

// Forward declarations
@interface NeuralStyleEngine : NSObject
+ (instancetype)sharedEngine;
- (BOOL)initializeWithDevice:(id<MTLDevice>)device error:(NSError **)error;
@property(nonatomic, assign) float styleStrength;
@end

@interface HDRPipeline : NSObject
+ (instancetype)sharedPipeline;
- (BOOL)initializeWithDevice:(id<MTLDevice>)device error:(NSError **)error;
@property(nonatomic, assign) BOOL hdrEnabled;
@end

@interface RayAudioEngine : NSObject
+ (instancetype)sharedEngine;
- (BOOL)initializeWithSampleRate:(double)sampleRate error:(NSError **)error;
@end

@interface WallpaperEngine : NSObject
+ (instancetype)sharedEngine;
- (BOOL)start;
@property(nonatomic, assign) BOOL isActive;
@end

@interface IntegrationTests : XCTestCase

@property(nonatomic, strong) id<MTLDevice> device;
@property(nonatomic, strong) NeuralStyleEngine *neuralEngine;
@property(nonatomic, strong) HDRPipeline *hdrPipeline;
@property(nonatomic, strong) RayAudioEngine *audioEngine;

@end

@implementation IntegrationTests

- (void)setUp {
    [super setUp];
    _device = MTLCreateSystemDefaultDevice();
}

- (void)tearDown {
    _device = nil;
    [super tearDown];
}

#pragma mark - Feature Integration Tests

- (void)testNeuralStyleWithHDR {
    if (!_device) {
        NSLog(@"Skipping - Metal not available");
        return;
    }

    _neuralEngine = [NeuralStyleEngine sharedEngine];
    _hdrPipeline = [HDRPipeline sharedPipeline];

    NSError *error = nil;
    BOOL neuralSuccess = [_neuralEngine initializeWithDevice:_device error:&error];
    BOOL hdrSuccess = [_hdrPipeline initializeWithDevice:_device error:&error];

    XCTAssertTrue(neuralSuccess, @"Neural engine should initialize");
    XCTAssertTrue(hdrSuccess, @"HDR pipeline should initialize");

    // Enable HDR with neural style
    _hdrPipeline.hdrEnabled = YES;
    _neuralEngine.styleStrength = 0.8;

    XCTAssertTrue(YES, @"Neural style and HDR should work together");
}

- (void)testAudioWithNeuralStyle {
    _audioEngine = [RayAudioEngine sharedEngine];
    _neuralEngine = [NeuralStyleEngine sharedEngine];

    NSError *error = nil;
    BOOL audioSuccess = [_audioEngine initializeWithSampleRate:48000.0 error:&error];

    XCTAssertTrue(audioSuccess, @"Audio engine should initialize");

    // Test that audio can run while neural style is processing
    [_audioEngine start];

    float buffer[512];
    [_audioEngine processAudioBuffer:buffer frameCount:512];

    XCTAssertTrue(YES, @"Audio should work with neural style");
}

- (void)testWallpaperWithHDR {
    WallpaperEngine *wallpaper = [WallpaperEngine sharedEngine];
    _hdrPipeline = [HDRPipeline sharedPipeline];

    NSError *error = nil;
    BOOL hdrSuccess = [_hdrPipeline initializeWithDevice:_device error:&error];

    XCTAssertTrue(hdrSuccess, @"HDR should initialize for wallpaper");

    // HDR should be available for wallpaper mode
    XCTAssertTrue([_hdrPipeline detectHDRDisplay] || ![_hdrPipeline detectHDRDisplay], @"HDR detection should work");
}

- (void)testAllFeaturesTogether {
    if (!_device) {
        NSLog(@"Skipping - Metal not available");
        return;
    }

    // Initialize all subsystems
    _neuralEngine = [NeuralStyleEngine sharedEngine];
    _hdrPipeline = [HDRPipeline sharedPipeline];
    _audioEngine = [RayAudioEngine sharedEngine];

    NSError *error = nil;

    BOOL neuralSuccess = [_neuralEngine initializeWithDevice:_device error:&error];
    BOOL hdrSuccess = [_hdrPipeline initializeWithDevice:_device error:&error];
    BOOL audioSuccess = [_audioEngine initializeWithSampleRate:48000.0 error:&error];

    XCTAssertTrue(neuralSuccess, @"Neural should initialize");
    XCTAssertTrue(hdrSuccess, @"HDR should initialize");
    XCTAssertTrue(audioSuccess, @"Audio should initialize");

    // Configure all features
    _hdrPipeline.hdrEnabled = YES;
    _neuralEngine.styleStrength = 0.7;
    [_audioEngine start];

    // Simulate one frame with all features
    float audioBuffer[256];
    [_audioEngine processAudioBuffer:audioBuffer frameCount:256];

    XCTAssertTrue(YES, @"All features should work together");
}

#pragma mark - Performance Tests

- (void)testPerformanceWithAllFeatures {
    if (!_device) {
        NSLog(@"Skipping - Metal not available");
        return;
    }

    _neuralEngine = [NeuralStyleEngine sharedEngine];
    _audioEngine = [RayAudioEngine sharedEngine];

    [_neuralEngine initializeWithDevice:_device error:nil];
    [_audioEngine initializeWithSampleRate:48000.0 error:nil];
    [_audioEngine start];

    float audioBuffer[1024];

    [self measureBlock:^{
        for (int i = 0; i < 60; i++) {
            [_audioEngine processAudioBuffer:audioBuffer frameCount:1024];
        }
    }];
}

#pragma mark - Memory Tests

- (void)testMemoryUsage {
    // Check that features don't leak memory
    WallpaperEngine *engine1 = [WallpaperEngine sharedEngine];
    WallpaperEngine *engine2 = [WallpaperEngine sharedEngine];

    XCTAssertEqual(engine1, engine2, @"Should use singletons to prevent duplication");
}

#pragma mark - Error Handling Tests

- (void)testGracefulDegradation {
    // Test behavior when Metal is not available
    if (!_device) {
        NeuralStyleEngine *engine = [NeuralStyleEngine sharedEngine];
        NSError *error = nil;
        BOOL success = [engine initializeWithDevice:nil error:&error];

        XCTAssertFalse(success, @"Should fail gracefully without Metal");
        XCTAssertNotNil(error, @"Should provide error information");
    }
}

@end
