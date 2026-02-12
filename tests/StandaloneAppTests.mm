//
//  StandaloneAppTests.mm
//  ShaderCandy
//
//  Unit tests for the standalone player application
//

#import <XCTest/XCTest.h>
#import "StandaloneAppDelegate.h"
#import "StandaloneAppWindowController.h"
#import "PreferencesWindowController.h"
#import "ShadersListViewController.h"
#import <Metal/Metal.h>
#import <Cocoa/Cocoa.h>

@interface StandaloneAppTests : XCTestCase

@property(nonatomic, strong) StandaloneAppDelegate *appDelegate;
@property(nonatomic, strong) StandaloneAppWindowController *windowController;

@end

@implementation StandaloneAppTests

- (void)setUp {
    [super setUp];
    
    // Create app delegate
    _appDelegate = [[StandaloneAppDelegate alloc] init];
    
    // Create window controller
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 800, 600)
                                                   styleMask:NSWindowStyleMaskTitled
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    _windowController = [[StandaloneAppWindowController alloc] initWithWindow:window];
}

- (void)tearDown {
    [super tearDown];
    
    _windowController = nil;
    _appDelegate = nil;
}

#pragma mark - Window Controller Tests

- (void)testWindowControllerInitialization {
    XCTAssertNotNil(_windowController, @"Window controller should be created");
    XCTAssertNotNil(_windowController.window, @"Window should be initialized");
}

- (void)testWindowControllerShaderList {
    // Test shader list initialization
    XCTAssertNotNil(_windowController.shadersListVC, @"Shaders list VC should be created");
    XCTAssertNotNil(_windowController.shaderListContainer, @"Shader list container should be created");
}

- (void)testWindowControllerMetrics {
    // Test metrics display
    XCTAssertFalse(_windowController.showingMetrics, @"Metrics should not be showing initially");
}

#pragma mark - Shader Management Tests

- (void)testShaderSelection {
    NSArray<NSString *> *testShaders = @[@"plasma", @"mandelbulb_3d", @"nebula"];
    
    _windowController.availableShaders = testShaders;
    
    XCTAssertEqual(_windowController.availableShaders.count, 3, @"Should have 3 shaders");
    
    // Test selection
    [_windowController selectShader:@"nebula"];
    XCTAssertEqualObjects(_windowController.currentShader, @"nebula", @"Should select nebula shader");
}

- (void)testShaderNavigation {
    NSArray<NSString *> *testShaders = @[@"shader1", @"shader2", @"shader3"];
    
    _windowController.availableShaders = testShaders;
    _windowController.currentShaderIndex = 0;
    
    // Test next
    [_windowController nextShader];
    XCTAssertEqual(_windowController.currentShaderIndex, 1, @"Should go to next shader");
    
    // Test previous
    [_windowController previousShader];
    XCTAssertEqual(_windowController.currentShaderIndex, 0, @"Should go to previous shader");
    
    // Test wrap-around
    _windowController.currentShaderIndex = 2;
    [_windowController nextShader];
    XCTAssertEqual(_windowController.currentShaderIndex, 0, @"Should wrap to first shader");
    
    _windowController.currentShaderIndex = 0;
    [_windowController previousShader];
    XCTAssertEqual(_windowController.currentShaderIndex, 2, @"Should wrap to last shader");
}

#pragma mark - App Delegate Tests

- (void)testAppDelegateInitialization {
    XCTAssertNotNil(_appDelegate, @"App delegate should be created");
    XCTAssertFalse(_appDelegate.isRunning, @"App should not be running initially");
}

- (void)testAppDelegateShaderDiscovery {
    [_appDelegate discoverAvailableShaders];
    
    XCTAssertTrue(_appDelegate.availableShaders.count > 0, @"Should discover at least one shader");
    
    // Check for known shaders
    NSSet<NSString *> *shaderSet = [NSSet setWithArray:_appDelegate.availableShaders];
    XCTAssertTrue([shaderSet containsObject:@"plasma"], @"Should contain plasma shader");
}

- (void)testAppDelegateShaderSwitching {
    [_appDelegate setCurrentShader:@"plasma"];
    XCTAssertEqualObjects(_appDelegate.currentShader, @"plasma", @"Should set current shader");
}

#pragma mark - Preferences Tests

- (void)testPreferencesInitialization {
    PreferencesWindowController *prefs = [[PreferencesWindowController alloc] init];
    
    XCTAssertEqual(prefs.targetFPS, 60, @"Default FPS should be 60");
    XCTAssertTrue(prefs.vsyncEnabled, @"VSync should be enabled by default");
    XCTAssertFalse(prefs.hdrEnabled, @"HDR should be disabled by default");
    XCTAssertFalse(prefs.audioEnabled, @"Audio should be disabled by default");
}

- (void)testPreferencesValues {
    PreferencesWindowController *prefs = [[PreferencesWindowController alloc] init];
    
    prefs.targetFPS = 30;
    XCTAssertEqual(prefs.targetFPS, 30, @"Should set FPS to 30");
    
    prefs.audioSensitivity = 2.0f;
    XCTAssertEqual(prefs.audioSensitivity, 2.0f, @"Should set audio sensitivity");
}

#pragma mark - Shaders List View Controller Tests

- (void)testShadersListVCInitialization {
    ShadersListViewController *vc = [[ShadersListViewController alloc] init];
    
    XCTAssertNotNil(vc, @"VC should be created");
    XCTAssertNotNil(vc.view, @"VC view should be created");
    XCTAssertNotNil(vc.tableView, @"Table view should be created");
}

- (void)testShadersListVCShaderData {
    ShadersListViewController *vc = [[ShadersListViewController alloc] init];
    
    NSArray<NSString *> *testShaders = @[@"shader1", @"shader2", @"shader3"];
    vc.shaders = testShaders;
    
    XCTAssertEqual(vc.shaders.count, 3, @"Should have 3 shaders");
    XCTAssertEqual(vc.filteredShaders.count, 3, @"Filtered shaders should match");
}

- (void)testShadersListVCSearch {
    ShadersListViewController *vc = [[ShadersListViewController alloc] init];
    
    NSArray<NSString *> *testShaders = @[@"plasma", @"mandelbulb", @"nebula"];
    vc.shaders = testShaders;
    
    // Search for "plasma"
    vc.filterText = @"plasma";
    [vc updateFilteredShaders];
    
    XCTAssertEqual(vc.filteredShaders.count, 1, @"Should filter to 1 shader");
    XCTAssertEqualObjects(vc.filteredShaders[0], @"plasma", @"Should find plasma");
    
    // Clear search
    vc.filterText = @"";
    [vc updateFilteredShaders];
    
    XCTAssertEqual(vc.filteredShaders.count, 3, @"Should show all shaders again");
}

#pragma mark - Renderer Integration Tests

- (void)testRendererInitialization {
    // Skip if Metal not available
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        NSLog(@"Metal not available, skipping renderer test");
        return;
    }
    
    // Create renderer
    NSError *error = nil;
    MetalRenderer *renderer = [MetalRenderer rendererWithDevice:device error:&error];
    
    XCTAssertNotNil(renderer, @"Renderer should be created");
    XCTAssertNil(error, @"Error should be nil");
}

#pragma mark - Performance Tests

- (void)testShaderSwitchingPerformance {
    NSArray<NSString *> *testShaders = @[@"shader1", @"shader2", @"shader3", @"shader4", @"shader5"];
    _windowController.availableShaders = testShaders;
    
    [self measureBlock:^{
        for (int i = 0; i < 100; i++) {
            [_windowController selectShaderAtIndex:i % 5];
        }
    }];
}

@end
