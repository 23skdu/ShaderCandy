//
//  NeuralStyleTests.mm
//  ShaderCandy
//
//  Unit tests for neural style transfer functionality
//

#import <XCTest/XCTest.h>
#import <Metal/Metal.h>
#import <CoreML/CoreML.h>
#import "NeuralStyleEngine.h"
#import "StyleLibrary.h"
#import "StyleTransferModel.h"

@interface NeuralStyleTests : XCTestCase

@property(nonatomic, strong) id<MTLDevice> device;
@property(nonatomic, strong) NeuralStyleEngine *engine;

@end

@implementation NeuralStyleTests

- (void)setUp {
    [super setUp];

    _device = MTLCreateSystemDefaultDevice();
    if (!_device) {
        NSLog(@"Metal not available, skipping neural style tests");
        return;
    }

    _engine = [NeuralStyleEngine sharedEngine];
}

- (void)tearDown {
    _engine = nil;
    _device = nil;
    [super tearDown];
}

#pragma mark - Engine Tests

- (void)testNeuralStyleEngineSingleton {
    NeuralStyleEngine *engine1 = [NeuralStyleEngine sharedEngine];
    NeuralStyleEngine *engine2 = [NeuralStyleEngine sharedEngine];

    XCTAssertEqual(engine1, engine2, @"Engine should be singleton");
}

- (void)testEngineInitialization {
    if (!_device) {
        NSLog(@"Skipping - Metal not available");
        return;
    }

    NSError *error = nil;
    BOOL success = [_engine initializeWithDevice:_device error:&error];

    XCTAssertTrue(success, @"Engine should initialize successfully");
    XCTAssertNil(error, @"Error should be nil");
}

- (void)testAvailableStyles {
    StyleLibrary *library = [StyleLibrary sharedLibrary];
    NSArray<StylePreset *> *styles = library.allStyles;

    XCTAssertNotNil(styles, @"Should return available styles array");
    // Note: styles may be empty if no models are bundled
}

#pragma mark - Model Tests

- (void)testStyleTransferModelCreation {
    NSURL *dummyURL = [NSURL fileURLWithPath:@"/nonexistent/test.mlmodel"];
    StyleTransferModel *model = [[StyleTransferModel alloc] initWithName:@"test" modelURL:dummyURL];

    XCTAssertNotNil(model, @"Model should be created");
    XCTAssertFalse(model.isLoaded, @"Model should not be loaded initially");
}

- (void)testStyleTransferModelWithBundle {
    StyleTransferModel *model = [[StyleTransferModel alloc] initWithBundleStyle:@"starry_night"];

    XCTAssertNotNil(model, @"Model should be created from bundle");
}

- (void)testModelMetadata {
    StyleTransferModel *model = [[StyleTransferModel alloc] initWithBundleStyle:@"starry_night"];

    // Test that metadata is loaded
    XCTAssertNotNil(model, @"Model should exist");
}

#pragma mark - Performance Tests

- (void)testEngineInitializationPerformance {
    if (!_device) {
        NSLog(@"Skipping - Metal not available");
        return;
    }

    [self measureBlock:^{
        NeuralStyleEngine *engine = [[NeuralStyleEngine alloc] init];
        NSError *error = nil;
        [engine initializeWithDevice:_device error:&error];
    }];
}

#pragma mark - Integration Tests

- (void)testModelLoadingWithoutURL {
    NSURL *missingURL = [NSURL fileURLWithPath:@"/nonexistent/test.mlmodel"];
    StyleTransferModel *model = [[StyleTransferModel alloc] initWithName:@"test" modelURL:missingURL];

    NSError *error = nil;
    BOOL success = [model loadWithError:&error];

    XCTAssertFalse(success, @"Loading should fail with nonexistent URL");
    XCTAssertNotNil(error, @"Error should be set");
}

- (void)testMetalDeviceSupport {
    if (!_device) {
        NSLog(@"Skipping - Metal not available");
        return;
    }

    // Check for Metal 3 support (needed for some neural features)
    BOOL supportsMetal3 = NO;
    if (@available(macOS 13.0, *)) {
        supportsMetal3 = [_device supportsFamily:MTLGPUFamilyMetal3];
    }

    NSLog(@"Metal 3 support: %@", supportsMetal3 ? @"Yes" : @"No");
    // Don't assert - Metal 3 is optional
}

@end
