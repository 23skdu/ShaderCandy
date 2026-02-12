# ShaderCandy Master Project Plan & Roadmap

## 🚀 Overview

ShaderCandy is a cross-platform (macOS/Linux) screensaver engine delivering high-performance procedural visuals through native GPU APIs (Metal/OpenGL). This document outlines the comprehensive implementation plan for Phase 4 (Expansion & Distribution) and Phase 5 (Advanced Tech).

---

## 📊 Codebase Analysis Summary

### Architecture Overview

```
ShaderCandy/
├── shaders/                    # Metal/GLSL shader sources
│   ├── base/                   # Core utilities (noise, SDFs, color)
│   ├── effects/                # Individual visual effects
│   └── system/                 # Debug/overlay shaders
├── src/
│   ├── core/                   # Platform-independent C++ logic
│   │   ├── UniformBuffer.h/cpp # Uniform data management
│   │   ├── ShaderManager.h/cpp # Shader lifecycle management
│   │   ├── PerformanceMonitor.h/cpp # FPS/metrics tracking
│   │   ├── MathUtils.h         # SIMD-accelerated math (NEON/AVX2)
│   │   ├── MultiDisplayManager.h # Multi-monitor coordination
│   │   └── ShaderInterop.h     # CPU-GPU shared structures
│   ├── metal/                  # macOS Metal backend
│   │   ├── MetalRenderer.h/cpp # Unified rendering pipeline
│   │   ├── MetalPipelineCache.h/cpp # Pipeline state caching
│   │   ├── MetalResourcePool.h/cpp # Dynamic resource management
│   │   ├── ShaderCompiler.h/cpp # Metal shader compilation
│   │   └── MTLPerformanceReporter.h/cpp # GPU timing/bandwidth
│   ├── audio/                  # Audio reactive system
│   │   ├── AudioInput.h/mm     # FFT-based audio analysis
│   │   └── SoundscapeGenerator.h/mm # Generative audio
│   ├── config/                 # Configuration management
│   │   └── ConfigurationManager.h # Settings/presets
│   └── platform/
│       ├── macos/              # macOS-specific code
│       │   ├── ShaderCandyView.h/mm # ScreenSaverView adapter
│       │   ├── MacOSMetalViewAdapter.mm # Metal view wrapper
│       │   └── StandaloneAppDelegate.h # Standalone app skeleton
│       └── linux/              # X11/OpenGL implementation
├── tests/                      # Unit/integration tests
│   ├── TestFramework.h/cpp     # Test infrastructure
│   ├── MathAndCoreTests.cpp    # Math/core functionality
│   ├── PropertyUniformTests.mm # Uniform mapping tests
│   └── MetalCompilationTests.mm # Shader compilation tests
├── docs/                       # Documentation
└── CMakeLists.txt              # CMake build configuration
```

### Key Technologies

| Layer | Technology | Purpose |
|-------|------------|---------|
| **macOS Rendering** | Metal API | GPU-accelerated rendering |
| **Linux Rendering** | OpenGL 3.3+ | GPU-accelerated rendering |
| **Audio** | AVFoundation/AVAudioEngine | Real-time audio analysis and synthesis |
| **Build** | CMake 3.20+ | Cross-platform build system |
| **Tests** | Custom C++ framework | Unit/integration testing |
| **SIMD** | ARM NEON / AVX2 | CPU-side vector optimizations |

### Current Feature Set

- ✅ Unified Metal Renderer architecture
- ✅ Shader hot-reloading with file watching
- ✅ Multi-monitor synchronization
- ✅ Interactive particle systems (GPU compute)
- ✅ Audio reactivity (FFT analysis)
- ✅ Bloom post-processing pipeline
- ✅ Configuration UI with sliders
- ✅ Smooth shader transitions (alpha cross-fade)
- ✅ Performance auto-scaling

### Existing Test Coverage

| Test Suite | Coverage |
|------------|----------|
| Math & SIMD Tests | Vector ops, NEON/AVX2 multiplications, color conversion |
| Core Functionality | UniformBuffer, PerformanceMonitor |
| Property Uniforms | Speed, Intensity, Gravity property mapping |
| Shader Discovery | Available shader enumeration |
| Metal Compilation | Shader compilation verification |

---

## 🎯 Implementation Roadmap: 15-Part Plan

### Phase 4: Expansion & Distribution

#### Part 1: Standalone App Player - Core Infrastructure
**Objective**: Create a companion macOS application for windowed previewing

| Aspect | Details |
|--------|---------|
| **Files Added** | `src/platform/macos/StandaloneAppDelegate.mm`, `src/platform/macos/StandaloneAppWindowController.h/mm` |
| **Files Modified** | `CMakeLists.txt`, `src/platform/macos/StandaloneAppDelegate.h` |
| **Dependencies** | MetalKit, AppKit, Foundation |

**Implementation Tasks**:
1. Implement `StandaloneAppDelegate.mm` with full application lifecycle
2. Create `StandaloneAppWindowController` for window management
3. Implement window resize handling with viewport update
4. Add menu bar with shader selection, settings
5. Integrate `MetalRenderer` for windowed rendering
6. Handle application termination and cleanup

**New Classes**:
```objc
@interface StandaloneAppWindowController : NSWindowController
@property(nonatomic, strong) MTKView *metalView;
@property(nonatomic, strong) MetalRenderer *renderer;
- (void)selectShader:(NSString *)shaderName;
- (void)showPreferences;
@end
```

**Unit Tests**:
```cpp
// tests/StandaloneAppTests.mm
class StandaloneAppTests : public TestSuite {
    TestResult testWindowCreation();
    TestResult testShaderSelection();
    TestResult testViewportResize();
    TestResult testRendererInitialization();
};
```

**Documentation**:
- `docs/STANDALONE_APP_GUIDE.md`: Installation and usage
- `docs/API_REFERENCE.md`: Public API documentation

---

#### Part 2: Standalone App Player - UI Integration
**Objective**: Complete UI system for the standalone player

| Aspect | Details |
|--------|---------|
| **Files Added** | `src/platform/macos/PreferencesWindowController.h/mm`, `src/platform/macos/ShadersListViewController.h/mm` |
| **Files Modified** | `src/platform/macos/StandaloneAppDelegate.h` |

**Implementation Tasks**:
1. Create shader catalog with preview thumbnails
2. Implement parameter adjustment panel (speed, intensity, gravity)
3. Add real-time FPS/metrics display
4. Implement shader transition controls
5. Add audio toggle and configuration
6. Create keyboard shortcuts for common actions

**New Classes**:
```objc
@interface PreferencesWindowController : NSWindowController
@property(nonatomic, assign) int targetFPS;
@property(nonatomic, assign) float audioSensitivity;
@property(nonatomic, assign) BOOL enableHDR;
@end

@interface ShadersListViewController : NSViewController
@property(nonatomic, strong) NSArray<NSString *> *shaders;
- (void)onShaderSelected:(NSString *)shaderName;
@end
```

**Unit Tests**:
```cpp
// tests/UITests.mm
class UITests : public TestSuite {
    TestResult testShaderListPopulated();
    TestResult testPreferencesSerialization();
    TestResult testKeyboardShortcuts();
};
```

---

#### Part 3: Active Wallpaper Mode - Core Foundation
**Objective**: Enable ShaderCandy as a live desktop wallpaper on macOS

| Aspect | Details |
|--------|---------|
| **Files Added** | `src/platform/macos/WallpaperEngine.h/mm`, `src/platform/macos/DesktopView.h/mm` |
| **Files Modified** | `CMakeLists.txt`, `src/metal/MetalRenderer.h` |

**Implementation Tasks**:
1. Research macOS Wallpaper APIs (Desktop Pictures folder, CGWindow)
2. Create `WallpaperEngine` class for wallpaper management
3. Implement multi-desktop awareness using `NSWorkspace`
4. Handle screen sleep/wake events
5. Create `DesktopView` - a borderless `MTKView` for wallpaper rendering
6. Implement proper z-ordering to stay behind desktop icons
7. Add credential helper for writing to `/Library/Desktop Pictures`

**New Classes**:
```objc
@interface WallpaperEngine : NSObject
+ (instancetype)sharedEngine;
- (BOOL)setWallpaperForDesktop:(NSInteger)desktopIndex
                     withShader:(NSString *)shaderName;
- (BOOL)setWallpaperForAllDesktops:(NSString *)shaderName;
- (void)clearWallpaper;
@property(nonatomic, assign) BOOL isActive;
@end
```

**System Integration**:
- Use `NSWorkspace` for desktop enumeration
- Monitor `NSWorkspaceScreensDidWakeNotification` and `NSWorkspaceScreensDidSleepNotification`
- Use `CGWindowList` for proper window layering

**Unit Tests**:
```cpp
// tests/WallpaperTests.mm
class WallpaperTests : public TestSuite {
    TestResult testWallpaperEngineSingleton();
    TestResult testMultiDesktopAwareness();
    TestResult testSleepWakeHandling();
};
```

**Documentation**:
- `docs/WALLPAPER_MODE_GUIDE.md`: Setup and troubleshooting

---

#### Part 4: Active Wallpaper Mode - Multi-Monitor & Space Support
**Objective**: Full multi-monitor and Spaces support for wallpaper mode

| Aspect | Details |
|--------|---------|
| **Files Added** | `src/platform/macos/WallpaperSpaceManager.h/mm` |
| **Files Modified** | `src/platform/macos/WallpaperEngine.h/mm` |

**Implementation Tasks**:
1. Implement per-Space wallpaper assignments
2. Handle Space transitions smoothly
3. Add multi-monitor wallpaper support (different shader per display)
4. Implement wallpaper preview in System Preferences
5. Add "Change interval" for automatic shader rotation
6. Integrate with macOS Screen Saver preferences

**New Classes**:
```objc
@interface WallpaperSpaceManager : NSObject
- (void)assignShader:(NSString *)shaderName
            toSpaces:(NSArray<NSNumber *> *)spaceIdentifiers;
- (NSDictionary<NSString *, NSString *> *)currentAssignment;
@end
```

**Unit Tests**:
```cpp
// tests/WallpaperSpaceTests.mm
class WallpaperSpaceTests : public TestSuite {
    TestResult testSpaceEnumeration();
    TestResult testPerSpaceAssignment();
    TestResult testMultiMonitorWallpaper();
};
```

---

#### Part 5: Preset Export/Import - Data Model
**Objective**: JSON-based preset sharing system

| Aspect | Details |
|--------|---------|
| **Files Added** | `src/config/PresetManager.h/mm`, `src/config/PresetSerialization.h/mm` |
| **Files Modified** | `src/config/ConfigurationManager.h` |

**Implementation Tasks**:
1. Define preset JSON schema with schema versioning
2. Implement `PresetManager` for preset CRUD operations
3. Create `PresetSerialization` for JSON encode/decode
4. Handle parameter validation against shader constraints
5. Add preset metadata (author, description, tags, created date)
6. Implement preset dependency resolution
7. Add preset preview generation (screenshot)

**Preset JSON Schema**:
```json
{
  "version": "1.0",
  "name": "Cosmic Nebula",
  "author": "ShaderCandy User",
  "description": "A vibrant nebula effect with audio reactivity",
  "shader": "nebula",
  "created": "2024-01-15T12:00:00Z",
  "parameters": {
    "speed": 1.5,
    "intensity": 0.8,
    "gravity": 2.3
  },
  "globalSettings": {
    "targetFPS": 60,
    "enableAudio": true
  }
}
```

**New Classes**:
```cpp
namespace ShaderCandy {
namespace Config {

struct Preset {
    std::string name;
    std::string author;
    std::string description;
    std::string shaderName;
    std::map<std::string, ConfigValue> parameters;
    std::string createdDate;
    std::vector<std::string> tags;
};

class PresetManager {
public:
    bool savePreset(const Preset& preset, const std::string& path);
    std::optional<Preset> loadPreset(const std::string& path);
    std::vector<Preset> discoverPresets(const std::string& directory);
    bool exportPreset(const Preset& preset, const std::string& outputPath);
    std::vector<Preset> importPresets(const std::string& sourcePath);
};

}
}
```

**Unit Tests**:
```cpp
// tests/PresetTests.cpp
class PresetTests : public TestSuite {
    TestResult testPresetSerializationRoundTrip();
    TestResult testPresetValidation();
    TestResult testPresetDiscovery();
    TestResult testPresetDependencyResolution();
    TestResult testSchemaVersionMigration();
};
```

**Documentation**:
- `docs/PRESET_FORMAT_SPEC.md`: Technical specification
- `docs/PRESET_SHARING_GUIDE.md`: User guide for sharing presets

---

#### Part 6: Preset Export/Import - UI & Sharing
**Objective**: User interface for preset management and sharing

| Aspect | Details |
|--------|---------|
| **Files Added** | `src/platform/macos/PresetViewController.h/mm`, `src/platform/macos/PresetImportExportSheet.h/mm` |
| **Files Modified** | `src/platform/macos/StandaloneAppDelegate.h` |

**Implementation Tasks**:
1. Create `PresetViewController` for preset browser
2. Implement drag-and-drop preset import
3. Add preset preview with thumbnail generation
4. Implement preset category filtering
5. Add "Apply to current shader" functionality
6. Create share sheet for exporting to files/clipboard
7. Implement preset favorites and recently used

**New Classes**:
```objc
@interface PresetViewController : NSViewController
@property(nonatomic, strong) NSArray<Preset *> *presets;
@property(nonatomic, strong, nullable) Preset *selectedPreset;
- (void)refreshPresets;
- (void)applyPreset:(Preset *)preset;
@end

@interface PresetImportExportSheet : NSObject
- (void)showExportSheetForPreset:(Preset *)preset
                      completion:(void(^)(NSURL *outputURL))completion;
- (void)showImportSheetWithCompletion:(void(^)(Preset *preset))completion;
@end
```

**Unit Tests**:
```cpp
// tests/PresetUITests.mm
class PresetUITests : public TestSuite {
    TestResult testPresetBrowserPopulated();
    TestResult testDragDropImport();
    TestResult testShareSheetFunctionality();
    TestResult testPresetFiltering();
};
```

---

### Phase 5: Advanced Tech

#### Part 7: Neural Effects - CoreML Integration Foundation
**Objective**: Integrate CoreML for AI-powered style transfer effects

| Aspect | Details |
|--------|---------|
| **Files Added** | `src/neural/NeuralStyleEngine.h/mm`, `src/neural/StyleTransferModel.h/mm`, `src/neural/MLModelCompiler.h/mm` |
| **Files Modified** | `CMakeLists.txt`, `src/metal/MetalRenderer.h` |

**Implementation Tasks**:
1. Research and select/style transfer model architecture
2. Create `NeuralStyleEngine` class for CoreML coordination
3. Implement `StyleTransferModel` for model loading and inference
4. Create custom Metal compute kernels for style application
5. Optimize for real-time performance (model quantization)
6. Implement model hot-swapping
7. Add style strength parameter control

**Technical Approach**:
- Use Core ML for neural network inference
- Implement fast style transfer (single forward pass)
- Use quantized models (INT8) for performance
- Pipeline: Input → Style Transfer → Output texture

**New Classes**:
```objc
@interface NeuralStyleEngine : NSObject
@property(nonatomic, strong, nullable) id<MTLDevice> device;
@property(nonatomic, strong, nullable) id<MTLCommandQueue> commandQueue;
@property(nonatomic, strong) StyleTransferModel *currentModel;
@property(nonatomic, assign) float styleStrength;

- (BOOL)loadModelAtPath:(NSURL *)modelURL error:(NSError **)error;
- (id<MTLTexture>)applyStyle:(id<MTLTexture>)inputTexture
                   commandBuffer:(id<MTLCommandBuffer>)commandBuffer;
- (NSArray<NSString *> *)availableStyles;
@end
```

**Metal Shader Additions**:
```metal
// shaders/neural/style_transfer.metal
#include <metal_stdlib>
using namespace metal;

kernel void applyStyleTransfer(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    texture2d<float, access::sample> styleMap [[texture(2)]],
    constant float &strength [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    // Fast style transfer using lookup texture
    float4 color = input.read(gid);
    float2 uv = float2(color.rg);
    float4 styleColor = styleMap.sample(nearestSampler, uv);
    output.write(mix(color, styleColor, strength), gid);
}
```

**Unit Tests**:
```cpp
// tests/NeuralStyleTests.mm
class NeuralStyleTests : public TestSuite {
    TestResult testModelLoading();
    TestResult testStyleTransferInference();
    TestResult testStyleStrengthVariation();
    TestResult testModelHotSwap();
    TestResult testPerformanceMetrics();
};
```

**Documentation**:
- `docs/NEURAL_EFFECTS_GUIDE.md`: Setup and model management
- `docs/COREML_INTEGRATION.md`: Technical integration details

---

#### Part 8: Neural Effects - Style Library & Real-Time Processing
**Objective**: Complete neural style system with pre-trained style library

| Aspect | Details |
|--------|---------|
| **Files Added** | `src/neural/StyleLibrary.h/mm`, `src/neural/StylePresetManager.h/mm` |
| **Files Modified** | `src/neural/NeuralStyleEngine.h/mm` |

**Implementation Tasks**:
1. Create bundled style library with 10+ pre-trained styles
2. Implement `StyleLibrary` for managing available styles
3. Add dynamic style blending between multiple styles
4. Implement style animation (smooth transitions)
5. Optimize style application pipeline for 60fps
6. Add style randomizer for variety
7. Implement style suggestion based on current shader

**Pre-trained Styles**:
- Van Gogh Starry Night
- Monet Water Lilies
- Picasso Blue Period
- Hokusai Waves
- Mondrian Primary
- Cyberpunk Neon
- Oil Painting
- Watercolor
- Sketch/Pencil
- Vintage Film

**New Classes**:
```objc
@interface StyleLibrary : NSObject
+ (instancetype)sharedLibrary;
- (NSArray<StylePreset *> *)allStyles;
- (NSArray<StylePreset *> *)stylesForCategory:(NSString *)category;
- (NSURL *)pathForStyle:(NSString *)styleName;
- (void)downloadAdditionalStyle:(NSString *)styleName;
@end

@interface StylePreset : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *category;
@property(nonatomic, strong) NSURL *modelURL;
@property(nonatomic, assign) float recommendedStrength;
@property(nonatomic, strong, nullable) NSImage *previewImage;
@end
```

**Unit Tests**:
```cpp
// tests/StyleLibraryTests.mm
class StyleLibraryTests : public TestSuite {
    TestResult testBundledStylesAvailable();
    TestResult testStyleCategoryFiltering();
    TestResult testStyleBlending();
    TestResult testStyleAnimationSmoothness();
};
```

---

#### Part 9: Ray-Traced Audio - Acoustic Simulation Foundation
**Objective**: Physics-based acoustic simulation using compute shaders

| Aspect | Details |
|--------|---------|
| **Files Added** | `src/audio/AcousticSimulator.h/mm`, `src/audio/RayAudioEngine.h/mm`, `src/audio/AudioRayTracingKernels.metal` |
| **Files Modified** | `CMakeLists.txt`, `src/audio/SoundscapeGenerator.h` |

**Implementation Tasks**:
1. Research acoustic wave propagation simulation
2. Create `AcousticSimulator` class for audio ray tracing
3. Implement audio ray marching in Metal compute shaders
4. Add material absorption coefficients for acoustic properties
5. Implement 3D acoustic field visualization
6. Add spatial audio output (binaural rendering)
7. Integrate with `SoundscapeGenerator` for generative audio

**Technical Approach**:
- Ray tracing for sound propagation in virtual space
- Material absorption (soft/hard surfaces reflect/absorb differently)
- Doppler effect for moving audio sources
- HRTF (Head-Related Transfer Function) for spatial audio

**Metal Compute Shader**:
```metal
// shaders/audio/audio_ray_tracing.metal
#include <metal_stdlib>
using namespace metal;

struct AudioRay {
    float3 origin;
    float3 direction;
    float energy;
    float frequency;
    float time;
};

struct AcousticMaterial {
    float absorptionCoeff;
    float scatteringCoeff;
    float3 color;
};

kernel void traceAudioRays(
    device AudioRay *rays [[buffer(0)]],
    device AcousticMaterial *materials [[buffer(1)]],
    texture2d<float, access::read> sceneMap [[texture(0)]],
    texture2d<float, access::write> acousticField [[texture(1)]],
    constant float3 &sourcePosition [[buffer(2)]],
    constant float &time [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]])
{
    // Ray marching for audio propagation
    // Compute reflections, absorption, and energy decay
}
```

**New Classes**:
```objc
@interface AcousticSimulator : NSObject
@property(nonatomic, assign) int maxReflections;
@property(nonatomic, assign) float roomSize;
@property(nonatomic, assign) float absorption;
@property(nonatomic, assign) BOOL enableDoppler;

- (void)setSceneGeometry:(id<MTLTexture>)geometryTexture;
- (void)setAudioSource:(float3)position frequency:(float)hz;
- (id<MTLTexture>)renderAcousticField;
- (float)getEnergyAtPosition:(float3)position;
@end

@interface RayAudioEngine : NSObject
- (void)startWithSampleRate:(double)sampleRate;
- (void)processAudioBuffer:(float *)buffer frameCount:(NSUInteger)count;
- (void)setListenerPosition:(float3)position;
- (void)setSourcePosition:(float3)sourceIndex frequency:(float)freq;
@end
```

**Unit Tests**:
```cpp
// tests/AcousticSimulationTests.mm
class AcousticSimulationTests : public TestSuite {
    TestResult testRayGeneration();
    TestResult testReflectionCounting();
    TestResult testAbsorptionCalculation();
    TestResult testDopplerEffect();
    TestResult testSpatialAudioOutput();
};
```

**Documentation**:
- `docs/RAY_TRACED_AUDIO.md`: Technical specification
- `docs/ACOUSTIC_SIMULATION.md`: User guide for spatial audio

---

#### Part 10: Ray-Traced Audio - Generative Integration
**Objective**: Integrate ray-traced audio with generative soundscapes

| Aspect | Details |
|--------|---------|
| **Files Added** | `src/audio/SpatialSoundscapeGenerator.h/mm`, `src/audio/AcousticMaterialLibrary.h/mm` |
| **Files Modified** | `src/audio/SoundscapeGenerator.h`, `src/audio/RayAudioEngine.h/mm` |

**Implementation Tasks**:
1. Create `SpatialSoundscapeGenerator` combining generative audio with spatial positioning
2. Implement `AcousticMaterialLibrary` with physical material properties
3. Add room acoustics simulation (reverb, echo)
4. Implement dynamic source movement synced to visuals
5. Add binaural rendering for headphone output
6. Create audio-reactive ray visualization
7. Optimize for real-time performance

**Acoustic Materials**:
| Material | Absorption | Scattering |
|----------|------------|------------|
| Concrete | 0.02 | 0.1 |
| Glass | 0.05 | 0.3 |
| Fabric | 0.6 | 0.5 |
| Wood | 0.1 | 0.2 |
| Water | 0.02 | 0.05 |

**New Classes**:
```objc
@interface AcousticMaterialLibrary : NSObject
+ (instancetype)sharedLibrary;
- (AcousticMaterial)materialNamed:(NSString *)name;
- (void)registerMaterial:(AcousticMaterial)material withName:(NSString *)name;
@end

@interface SpatialSoundscapeGenerator : NSObject
@property(nonatomic, assign) BOOL binauralEnabled;
@property(nonatomic, assign) float reverbIntensity;
@property(nonatomic, assign) float roomSize;

- (void)setVisualComplexity:(float)complexity;
- (void)updateSourcePositionsFromVisuals;
- (float *)renderStereoOutputWithFrameCount:(NSUInteger)frameCount;
@end
```

**Unit Tests**:
```cpp
// tests/SpatialAudioTests.mm
class SpatialAudioTests : public TestSuite {
    TestResult testSpatialSourcePositioning();
    TestResult testBinauralRendering();
    TestResult testRoomAcoustics();
    TestResult testVisualAudioSync();
    TestResult testMaterialAbsorption();
};
```

---

#### Part 11: HDR Mastery - Pipeline Foundation
**Objective**: Implement 10-bit color and Extended Dynamic Range (EDR) support

| Aspect | Details |
|--------|---------|
| **Files Added** | `src/metal/HDRPipeline.h/mm`, `src/metal/ColorSpaceManager.h/mm`, `shaders/base/hdr_functions.metal` |
| **Files Modified** | `src/metal/MetalRenderer.h`, `src/core/ShaderInterop.h` |

**Implementation Tasks**:
1. Add HDR pixel format support (`MTLPixelFormatRGBA16Float`)
2. Implement `ColorSpaceManager` for color space transformations
3. Create HDR pipeline state with high-bit-depth render passes
4. Implement tone mapping operators (ACES, Reinhard, Filmic)
5. Add EDR brightness management using `CAMetalLayer`
6. Implement HDR metadata (HDR10, Dolby Vision)
7. Add automatic HDR detection and fallback

**Color Space Support**:
- Rec. 709 (SDR)
- Rec. 2020 (HDR)
- P3-D65 (Wide Color Gamut)
- scRGB (Extended range)

**New Classes**:
```objc
@interface HDRPipeline : NSObject
@property(nonatomic, assign) BOOL hdrEnabled;
@property(nonatomic, assign) BOOL edrEnabled;
@property(nonatomic, assign) float maxBrightness; // nits (1000, 1600, etc.)
@property(nonatomic, assign) MTLToneMappingOperator toneMapping;

- (BOOL)initializeWithDevice:(id<MTLDevice>)device
                        error:(NSError **)error;
- (MTLRenderPassDescriptor *)createHDRPassDescriptor;
- (void)toneMapFrame:(id<MTLTexture>)hdrTexture
           toOutput:(id<MTLTexture>)sdrTexture;
@end

typedef NS_ENUM(NSInteger, MTLToneMappingOperator) {
    MTLToneMappingOperatorACES,
    MTLToneMappingOperatorReinhard,
    MTLToneMappingOperatorFilmic,
    MTLToneMappingOperatorHable,
};
```

**Metal Shader Additions**:
```metal
// shaders/base/hdr_functions.metal
#include <metal_stdlib>
using namespace metal;

// ACES tone mapping (cinema-grade)
float3 ACESFilm(float3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
}

// Rec.2020 to P3 conversion
float3 rec2020_to_p3(float3 color) {
    // Conversion matrix
    float3x3 m = float3x3(
        0.677, 0.130, 0.000,
        0.280, 0.710, 0.010,
        0.000, 0.160, 0.880
    );
    return m * color;
}
```

**Unit Tests**:
```cpp
// tests/HDRTests.mm
class HDRTests : public TestSuite {
    TestResult testHDRPixelFormatSupport();
    TestResult testToneMappingOperators();
    TestResult testColorSpaceConversion();
    TestResult testEDRBrightnessRange();
    TestResult testHDRMetadataGeneration();
    TestResult testAutomaticHDRDetection();
};
```

**Documentation**:
- `docs/HDR_IMPLEMENTATION.md`: Technical specification
- `docs/HDR_USER_GUIDE.md`: Display calibration guide

---

#### Part 12: HDR Mastery - Advanced Features
**Objective**: Complete HDR pipeline with advanced features

| Aspect | Details |
|--------|---------|
| **Files Added** | `src/metal/DynamicRangeOptimizer.h/mm`, `src/metal/HDRMetadataGenerator.h/mm` |
| **Files Modified** | `src/metal/HDRPipeline.h/mm` |

**Implementation Tasks**:
1. Implement dynamic range optimizer for content-adaptive tone mapping
2. Add HDR10 metadata generation with correct mastering levels
3. Implement local tone mapping for better detail preservation
4. Add automatic exposure adjustment based on scene brightness
5. Implement HDR-to-SDR simulation for legacy display compatibility
6. Add EDR peak brightness animation support
7. Optimize HDR performance for real-time rendering

**New Classes**:
```objc
@interface DynamicRangeOptimizer : NSObject
@property(nonatomic, assign) float sceneBrightness;
@property(nonatomic, assign) float targetNits;
@property(nonatomic, assign) float kneePoint;
@property(nonatomic, assign) float shoulderPoint;

- (void)analyzeSceneBrightness:(id<MTLTexture>)frame;
- (float3)applyLocalToneMapping:(float3)color
                    localLuminance:(float)luminance;
@end

@interface HDRMetadataGenerator : NSObject
@property(nonatomic, assign) float displayMasteringMinLuminance;
@property(nonatomic, assign) float displayMasteringMaxLuminance;
@property(nonatomic, assign) float contentMaxFrameAvgLuminance;

- (NSData *)generateHDR10Metadata;
- (NSData *)generateDolbyVisionMetadata;
@end
```

**Unit Tests**:
```cpp
// tests/AdvancedHDRTests.mm
class AdvancedHDRTests : public TestSuite {
    TestResult testDynamicRangeOptimization();
    TestResult testLocalToneMapping();
    TestResult testHDR10MetadataStructure();
    TestResult testExposureAdaptation();
    TestResult testHDRToSDRSimulation();
    TestResult testEDRAnimationPerformance();
};
```

---

#### Part 13: Build System & CI/CD Updates
**Objective**: Update build system for new features and improve CI/CD

| Aspect | Details |
|--------|---------|
| **Files Modified** | `CMakeLists.txt`, `.github/workflows/build.yml` |

**Implementation Tasks**:
1. Add new targets for standalone app and wallpaper engine
2. Configure code signing for standalone app (Apple Developer ID)
3. Add Core ML model compilation to build pipeline
4. Update shader compilation for new audio/neural shaders
5. Implement conditional builds (HDR optional for older macOS)
6. Add build-time shader validation
7. Update install scripts for new components

**CMake Changes**:
```cmake
# Standalone App
if(MACOS AND BUILD_STANDALONE_APP)
    add_executable(ShaderCandyPlayer
        src/platform/macos/StandaloneAppDelegate.mm
        src/platform/macos/StandaloneAppWindowController.mm
        src/platform/macos/PreferencesWindowController.mm
        src/platform/macos/ShadersListViewController.mm
    )
    target_link_libraries(ShaderCandyPlayer PRIVATE
        shadercandy_core
        shadercandy_metal
        shadercandy_audio
        "-framework Cocoa"
    )
endif()

# Neural Effects
if(MACOS AND BUILD_NEURAL_EFFECTS)
    find_library(COREML_FRAMEWORK CoreML REQUIRED)
    target_sources(shadercandy_metal PRIVATE
        src/neural/NeuralStyleEngine.mm
        src/neural/StyleTransferModel.mm
    )
    target_link_libraries(shadercandy_metal PRIVATE ${COREML_FRAMEWORK})
endif()
```

**CI/CD Updates**:
- Add neural effect compilation tests
- Add Core ML model validation
- Add performance regression tests
- Test HDR on HDR-capable CI runners

---

#### Part 14: Documentation & User Guides
**Objective**: Comprehensive documentation for all new features

| Document | Content |
|----------|---------|
| `docs/STANDALONE_APP_GUIDE.md` | Installation, usage, troubleshooting |
| `docs/WALLPAPER_MODE_GUIDE.md` | Setup, multi-monitor, Spaces |
| `docs/PRESET_SHARING_GUIDE.md` | Creating, importing, sharing presets |
| `docs/PRESET_FORMAT_SPEC.md` | Technical JSON schema reference |
| `docs/NEURAL_EFFECTS_GUIDE.md` | Style library, custom models |
| `docs/COREML_INTEGRATION.md` | Core ML technical details |
| `docs/RAY_TRACED_AUDIO.md` | Acoustic simulation technical guide |
| `docs/ACOUSTIC_SIMULATION.md` | Spatial audio user guide |
| `docs/HDR_USER_GUIDE.md` | Display calibration, HDR settings |
| `docs/HDR_IMPLEMENTATION.md` | Technical HDR pipeline docs |
| `docs/API_REFERENCE.md` | Complete public API documentation |

**Content Structure**:
1. Quick Start
2. Features Overview
3. Detailed Usage
4. Advanced Configuration
5. Troubleshooting
6. API Reference
7. Contributing Guidelines

---

#### Part 15: Integration Testing & Performance Validation
**Objective**: Comprehensive testing across all new features

| Test Category | Tests |
|---------------|-------|
| **Unit Tests** | All new classes with ≥80% coverage |
| **Integration Tests** | Feature interactions (e.g., HDR + Neural effects) |
| **Performance Tests** | Frame time validation on reference hardware |
| **Compatibility Tests** | macOS version compatibility (Ventura+) |
| **Metal Validation** | API usage verification |
| **Memory Tests** | Leak detection and memory pressure |
| **Stability Tests** | Long-duration stress testing |

**Performance Benchmarks**:
| Hardware | Feature | Target FPS |
|----------|---------|------------|
| Apple M2 | Neural Style Transfer | 30+ |
| Apple M2 | HDR + Ray Audio | 60 |
| Apple M2 | All features combined | 45 |
| Intel Mac | Neural Style Transfer | 20+ |
| Intel Mac | HDR + Ray Audio | 30+ |

**Test Files Added**:
```
tests/
├── StandaloneAppTests.mm
├── WallpaperTests.mm
├── WallpaperSpaceTests.mm
├── PresetTests.cpp
├── PresetUITests.mm
├── NeuralStyleTests.mm
├── StyleLibraryTests.mm
├── AcousticSimulationTests.mm
├── SpatialAudioTests.mm
├── HDRTests.mm
├── AdvancedHDRTests.mm
├── IntegrationTests.mm
└── PerformanceTests.mm
```

---

## 📅 Implementation Schedule

| Part | Feature | Estimated Duration | Dependencies |
|------|---------|-------------------|--------------|
| 1 | Standalone App - Core | 2 weeks | None |
| 2 | Standalone App - UI | 1 week | Part 1 |
| 3 | Wallpaper Mode - Core | 2 weeks | None |
| 4 | Wallpaper Mode - Multi-Monitor | 1 week | Part 3 |
| 5 | Presets - Data Model | 1 week | None |
| 6 | Presets - UI | 1 week | Part 5 |
| 7 | Neural Effects - CoreML | 2 weeks | None |
| 8 | Neural Effects - Style Library | 1 week | Part 7 |
| 9 | Ray-Traced Audio - Foundation | 2 weeks | None |
| 10 | Ray-Traced Audio - Integration | 1 week | Part 9 |
| 11 | HDR Mastery - Pipeline | 2 weeks | None |
| 12 | HDR Mastery - Advanced | 1 week | Part 11 |
| 13 | Build System Updates | 1 week | All parts |
| 14 | Documentation | Ongoing | All parts |
| 15 | Testing & Validation | 2 weeks | All parts |

**Total Estimated Duration**: 20 weeks (5 months)

---

## 🔧 Technical Dependencies

### New Framework Dependencies

| Framework | Parts | Purpose |
|-----------|-------|---------|
| **CoreML** | 7, 8 | Neural style transfer inference |
| **Vision** | 7, 8 | Image preprocessing for ML |
| **AVFoundation** | 9, 10 | Audio capture and rendering |
| **CoreAudio** | 9, 10 | Low-level audio processing |

### Third-Party Dependencies (None required)

The implementation relies entirely on native Apple frameworks and custom code, avoiding external dependencies for maintainability.

---

## ✅ Verification Checklist

### Before Release

- [ ] All unit tests pass (≥90% coverage)
- [ ] Integration tests pass
- [ ] Performance benchmarks met
- [ ] Memory leak checks passed
- [ ] Metal validation passed
- [ ] Documentation complete
- [ ] User guides reviewed
- [ ] Build system verified
- [ ] Code signing configured
- [ ] Installer tested

### Feature-Specific

- [ ] Standalone app launches without crashes
- [ ] Wallpaper mode persists across reboots
- [ ] Presets import/export correctly
- [ ] Neural styles render in real-time
- [ ] Ray-traced audio is spatialized
- [ ] HDR displays correctly on supported hardware
- [ ] All features work together

---

## 📝 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Current | Phase 1-3 complete (Core features) |
| 1.1.0 | This plan | Phase 4-5 complete (All 6 new features) |

---

## 🎯 Success Criteria

1. **User Experience**: All features work seamlessly with intuitive UI
2. **Performance**: Maintain 60fps on Apple M2 with all features enabled
3. **Quality**: No crashes, memory leaks, or visual artifacts
4. **Compatibility**: Support macOS Ventura and Sonoma
5. **Documentation**: Complete guides for all user skill levels
6. **Extensibility**: Clean architecture for future feature additions

---

## 📋 Feature Implementation Checklist

### Phase 4: Expansion & Distribution

- [ ] **Part 1: Standalone App Player - Core Infrastructure**
  - [ ] Implement StandaloneAppDelegate.mm
  - [ ] Create StandaloneAppWindowController
  - [ ] Integrate MetalRenderer for windowed rendering
  - [ ] Add unit tests
  - [ ] Write documentation

- [ ] **Part 2: Standalone App Player - UI Integration**
  - [ ] Create shader catalog with previews
  - [ ] Implement parameter adjustment panel
  - [ ] Add real-time FPS display
  - [ ] Create keyboard shortcuts
  - [ ] Add unit tests

- [ ] **Part 3: Active Wallpaper Mode - Core Foundation**
  - [ ] Create WallpaperEngine class
  - [ ] Implement DesktopView
  - [ ] Handle screen sleep/wake
  - [ ] Add multi-desktop awareness
  - [ ] Add unit tests

- [ ] **Part 4: Active Wallpaper Mode - Multi-Monitor & Space Support**
  - [ ] Implement per-Space assignments
  - [ ] Add multi-monitor support
  - [ ] Create wallpaper preview
  - [ ] Add automatic shader rotation
  - [ ] Add unit tests

- [ ] **Part 5: Preset Export/Import - Data Model**
  - [ ] Define JSON schema
  - [ ] Implement PresetManager
  - [ ] Create PresetSerialization
  - [ ] Add metadata support
  - [ ] Add unit tests

- [ ] **Part 6: Preset Export/Import - UI & Sharing**
  - [ ] Create PresetViewController
  - [ ] Implement drag-and-drop import
  - [ ] Add share sheet
  - [ ] Create favorites system
  - [ ] Add unit tests

### Phase 5: Advanced Tech

- [ ] **Part 7: Neural Effects - CoreML Integration Foundation**
  - [ ] Create NeuralStyleEngine
  - [ ] Implement StyleTransferModel
  - [ ] Add Metal compute kernels
  - [ ] Optimize for real-time
  - [ ] Add unit tests

- [ ] **Part 8: Neural Effects - Style Library & Real-Time Processing**
  - [ ] Create bundled style library
  - [ ] Implement style blending
  - [ ] Add style animation
  - [ ] Create style randomizer
  - [ ] Add unit tests

- [ ] **Part 9: Ray-Traced Audio - Acoustic Simulation Foundation**
  - [ ] Create AcousticSimulator
  - [ ] Implement audio ray tracing
  - [ ] Add material absorption
  - [ ] Implement spatial audio
  - [ ] Add unit tests

- [ ] **Part 10: Ray-Traced Audio - Generative Integration**
  - [ ] Create SpatialSoundscapeGenerator
  - [ ] Implement AcousticMaterialLibrary
  - [ ] Add room acoustics
  - [ ] Create binaural rendering
  - [ ] Add unit tests

- [ ] **Part 11: HDR Mastery - Pipeline Foundation**
  - [ ] Create HDRPipeline
  - [ ] Implement ColorSpaceManager
  - [ ] Add tone mapping operators
  - [ ] Implement EDR support
  - [ ] Add unit tests

- [ ] **Part 12: HDR Mastery - Advanced Features**
  - [ ] Implement dynamic range optimizer
  - [ ] Add HDR10 metadata generation
  - [ ] Implement local tone mapping
  - [ ] Add HDR-to-SDR simulation
  - [ ] Add unit tests

- [ ] **Part 13: Build System & CI/CD Updates**
  - [ ] Update CMakeLists.txt
  - [ ] Add new build targets
  - [ ] Configure code signing
  - [ ] Update CI/CD pipeline

- [ ] **Part 14: Documentation & User Guides**
  - [ ] Write all user guides
  - [ ] Create API reference
  - [ ] Add troubleshooting guides

- [ ] **Part 15: Integration Testing & Performance Validation**
  - [ ] Run all unit tests
  - [ ] Run integration tests
  - [ ] Validate performance benchmarks
  - [ ] Conduct stability testing
