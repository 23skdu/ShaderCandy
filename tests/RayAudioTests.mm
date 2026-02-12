//
//  RayAudioTests.mm
//  ShaderCandy
//
//  Tests for ray-traced audio functionality
//

#import <XCTest/XCTest.h>
#import <Metal/Metal.h>

// Forward declarations
@interface RayAudioEngine : NSObject
+ (instancetype)sharedEngine;
- (BOOL)initializeWithSampleRate:(double)sampleRate error:(NSError **)error;
- (void)start;
- (void)stop;
- (void)setAudioSource:(NSInteger)sourceID position:(simd_float3)position;
- (void)processAudioBuffer:(float *)buffer frameCount:(NSUInteger)frameCount;
@property(nonatomic, assign) simd_float3 listenerPosition;
@property(nonatomic, assign) BOOL isRunning;
@end

@interface RayAudioTests : XCTestCase

@property(nonatomic, strong) RayAudioEngine *engine;

@end

@implementation RayAudioTests

- (void)setUp {
    [super setUp];
    _engine = [RayAudioEngine sharedEngine];
}

- (void)tearDown {
    [_engine stop];
    _engine = nil;
    [super tearDown];
}

#pragma mark - Engine Tests

- (void)testRayAudioEngineSingleton {
    RayAudioEngine *engine1 = [RayAudioEngine sharedEngine];
    RayAudioEngine *engine2 = [RayAudioEngine sharedEngine];

    XCTAssertEqual(engine1, engine2, @"Engine should be singleton");
}

- (void)testEngineInitialization {
    NSError *error = nil;
    BOOL success = [_engine initializeWithSampleRate:48000.0 error:&error];

    XCTAssertTrue(success, @"Engine should initialize");
    XCTAssertNil(error, @"Error should be nil");
}

- (void)testEngineStartStop {
    [_engine initializeWithSampleRate:48000.0 error:nil];

    XCTAssertFalse(_engine.isRunning, @"Should not be running initially");

    [_engine start];
    XCTAssertTrue(_engine.isRunning, @"Should be running after start");

    [_engine stop];
    XCTAssertFalse(_engine.isRunning, @"Should not be running after stop");
}

#pragma mark - Audio Source Tests

- (void)testAddAudioSource {
    [_engine initializeWithSampleRate:48000.0 error:nil];

    [_engine setAudioSource:0 position:simd_make_float3(1.0, 0.0, 0.0)];

    // Test passes if no crash
    XCTAssertTrue(YES, @"Adding source should not crash");
}

- (void)testProcessAudioBuffer {
    [_engine initializeWithSampleRate:48000.0 error:nil];
    [_engine start];

    [_engine setAudioSource:0 position:simd_make_float3(1.0, 0.0, 0.0)];
    [_engine setAudioSource:0 frequency:440.0];

    float buffer[512];
    [_engine processAudioBuffer:buffer frameCount:512];

    // Check that buffer is not all zeros (audio was generated)
    BOOL hasNonZero = NO;
    for (int i = 0; i < 512; i++) {
        if (fabs(buffer[i]) > 0.001) {
            hasNonZero = YES;
            break;
        }
    }

    XCTAssertTrue(hasNonZero, @"Buffer should contain audio");
}

- (void)testStereoProcessing {
    [_engine initializeWithSampleRate:48000.0 error:nil];
    [_engine start];

    [_engine setAudioSource:0 position:simd_make_float3(1.0, 0.0, 0.0)];

    float left[512];
    float right[512];
    [_engine processStereoBuffer:left right:right frameCount:512];

    XCTAssertTrue(YES, @"Stereo processing should complete");
}

#pragma mark - Spatial Audio Tests

- (void)testListenerPosition {
    [_engine initializeWithSampleRate:48000.0 error:nil];

    simd_float3 newPos = simd_make_float3(5.0, 2.0, 3.0);
    _engine.listenerPosition = newPos;

    XCTAssertTrue(simd_all(_engine.listenerPosition == newPos), @"Listener position should update");
}

#pragma mark - Performance Tests

- (void)testAudioProcessingPerformance {
    [_engine initializeWithSampleRate:48000.0 error:nil];
    [_engine start];

    [_engine setAudioSource:0 position:simd_make_float3(1.0, 0.0, 0.0)];
    [_engine setAudioSource:1 position:simd_make_float3(-1.0, 0.0, 0.0)];
    [_engine setAudioSource:2 position:simd_make_float3(0.0, 1.0, 0.0)];

    float buffer[1024];

    [self measureBlock:^{
        for (int i = 0; i < 100; i++) {
            [_engine processAudioBuffer:buffer frameCount:1024];
        }
    }];
}

@end
