# Neural Effects Guide

## Overview

ShaderCandy integrates CoreML neural style transfer to apply artistic styles to your shaders in real-time. This feature transforms your procedural graphics into works of art inspired by famous painters and artistic movements.

## Features

- **10 Built-in Styles**: Van Gogh, Monet, Picasso, Hokusai, Mondrian, Cyberpunk, Oil Painting, Watercolor, Sketch, Vintage
- **Real-time Processing**: GPU-accelerated style transfer using Metal and CoreML
- **Adjustable Strength**: Control the intensity of the artistic effect (0.0 - 1.0)
- **Model Hot-swapping**: Switch between styles without restarting
- **Custom Models**: Import your own CoreML style transfer models

## Architecture

### Components

| Component | Purpose |
|-----------|---------|
| `NeuralStyleEngine` | Singleton coordinator for all neural operations |
| `StyleTransferModel` | Individual style model wrapper |
| `neural_style_blend.metal` | Metal compute shaders for blending and post-processing |

### Data Flow

```
Shader Output (Metal Texture)
    ↓
Preprocessing (resize/normalize)
    ↓
CoreML Style Transfer Model
    ↓
Post-processing (color adjustments)
    ↓
Blend with Original (based on strength)
    ↓
Final Output
```

## Built-in Styles

### Art Styles

| Style | Description | Best For |
|-------|-------------|----------|
| **Starry Night** | Van Gogh's swirling patterns | Abstract, space scenes |
| **Monet** | Impressionist brush strokes | Nature, fluid effects |
| **Picasso** | Cubist fragmentation | Geometric patterns |
| **Hokusai** | Japanese woodblock print style | Landscapes, waves |
| **Oil Painting** | Classical oil texture | Realistic scenes |
| **Watercolor** | Soft, flowing washes | Gentle effects |
| **Sketch** | Pencil drawing style | High-contrast scenes |

### Modern Styles

| Style | Description | Best For |
|-------|-------------|----------|
| **Cyberpunk** | Neon, futuristic aesthetic | Tech, urban scenes |
| **Mondrian** | Primary colors, geometric | Abstract, patterns |
| **Vintage** | Film grain, aged look | Retro effects |

## Usage

### Basic Usage

```objc
// Apply style in your view controller
#import "NeuralStyleEngine.h"

// Initialize
NeuralStyleEngine *engine = [NeuralStyleEngine sharedEngine];
[engine initializeWithDevice:device error:nil];

// Load a style
[engine loadStyleNamed:@"starry_night" error:nil];

// Apply to current frame
id<MTLTexture> styledTexture = [engine applyStyle:inputTexture
                                    commandBuffer:commandBuffer];
```

### Adjusting Strength

```objc
// Set global strength (0.0 = original, 1.0 = full style)
engine.styleStrength = 0.7;

// Or apply with specific strength for one frame
id<MTLTexture> styled = [engine applyStyle:inputTexture
                             commandBuffer:commandBuffer
                                    strength:0.7];
```

### Listing Available Styles

```objc
NSArray<NSString *> *styles = [engine availableStyles];
for (NSString *styleName in styles) {
    NSLog(@"Available style: %@", styleName);
}
```

## Custom Models

### Importing Your Own Models

1. Train a style transfer model using PyTorch, TensorFlow, or Create ML
2. Convert to CoreML format (`.mlmodel`)
3. Place in the app bundle's `Styles` directory or user styles folder

```swift
// Example: Loading custom model
let modelURL = Bundle.main.url(forResource: "my_style", withExtension: "mlmodelc")
let model = StyleTransferModel(name: "My Style", modelURL: modelURL)
try? model.load()
```

### Model Requirements

| Requirement | Specification |
|-------------|---------------|
| Input | 512x512 RGB image |
| Output | 512x512 RGB image |
| Format | CoreML (`.mlmodel` or compiled `.mlmodelc`) |
| Compute | GPU-supported (Metal Performance Shaders) |

## Performance

### Optimization Tips

1. **Resolution Scaling**: Run style transfer at lower resolution for better performance
2. **Frame Skipping**: Apply style every Nth frame for animated content
3. **Prewarming**: Call `[engine prewarmModel]` before first use
4. **Background Loading**: Load models on background thread

### Performance Metrics

| Hardware | Resolution | FPS |
|----------|------------|-----|
| Apple M1/M2 | 512x512 | 30-60 |
| Apple M1/M2 | 1024x1024 | 15-30 |
| Intel Mac | 512x512 | 10-20 |

## Integration with Shaders

### Combining with Effects

```metal
// In your shader, output to intermediate texture
fragment float4 myShader(...) {
    float4 color = computeEffect(...);
    return color;
}

// Then apply neural style in renderer
id<MTLTexture> effectOutput = [renderer renderEffect];
id<MTLTexture> styledOutput = [neuralEngine applyStyle:effectOutput
                                         commandBuffer:commandBuffer];
```

### Audio Reactivity

```objc
// Make style strength react to audio
float audioLevel = audioAnalyzer.bassLevel;
engine.styleStrength = 0.5 + audioLevel * 0.5; // 0.5 - 1.0 range
```

## Troubleshooting

### Common Issues

**Issue**: Model fails to load
- **Solution**: Verify model format is CoreML and compiled with target macOS version

**Issue**: Slow performance
- **Solution**: Reduce input resolution or use quantized model (FP16)

**Issue**: Memory warnings
- **Solution**: Unload unused models with `[engine unloadCurrentModel]`

### Debug Mode

```objc
// Enable verbose logging
engine.debugMode = YES;
```

## API Reference

### NeuralStyleEngine

```objc
@interface NeuralStyleEngine : NSObject
+ (instancetype)sharedEngine;
- (BOOL)initializeWithDevice:(id<MTLDevice>)device error:(NSError **)error;
- (BOOL)loadStyleNamed:(NSString *)styleName error:(NSError **)error;
- (id<MTLTexture>)applyStyle:(id<MTLTexture>)input commandBuffer:(id<MTLCommandBuffer>)buffer;
@property(nonatomic, assign) float styleStrength;
@property(nonatomic, strong, readonly) NSArray<NSString *> *availableStyles;
@end
```

### StyleTransferModel

```objc
@interface StyleTransferModel : NSObject
- (instancetype)initWithName:(NSString *)name modelURL:(NSURL *)url;
- (BOOL)loadWithError:(NSError **)error;
- (void)unload;
- (id<MTLTexture>)transferStyle:(id<MTLTexture>)input
                  commandBuffer:(id<MTLCommandBuffer>)buffer
                         strength:(float)strength;
@property(nonatomic, copy, readonly) NSString *styleName;
@property(nonatomic, copy, readonly) NSString *displayName;
@property(nonatomic, assign, readonly) BOOL isLoaded;
@end
```

## Future Enhancements

- [ ] Style interpolation (morph between styles)
- [ ] Multi-style blending
- [ ] Temporal consistency for video
- [ ] Style strength automation
- [ ] User-trained styles from photos
