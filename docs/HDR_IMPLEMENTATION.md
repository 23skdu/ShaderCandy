# ShaderCandy HDR Implementation Guide

## Overview

ShaderCandy's HDR pipeline provides comprehensive high dynamic range rendering with 10-bit color depth support, EDR (Extended Dynamic Range), and multiple tone mapping operators.

## Features

- **10-bit Color**: RGBA16Float pixel format for wide color gamut
- **EDR Support**: Extended brightness up to 1600 nits on compatible displays
- **Multiple Tone Mappers**: ACES, Reinhard, Filmic, Hable
- **Dynamic Range Optimization**: Content-adaptive tone mapping
- **HDR Metadata**: HDR10 and Dolby Vision support

## Architecture

### Components

| Component | Purpose |
|-----------|---------|
| `HDRPipeline` | Main HDR rendering coordinator |
| `DynamicRangeOptimizer` | Scene analysis and adaptive tone mapping |
| `HDRMetadataGenerator` | HDR10/Dolby Vision metadata generation |

## Tone Mapping Operators

### ACES (Academy Color Encoding System)
- **Best for**: Cinema-quality output
- **Characteristics**: Smooth roll-off, preserves color
- **Use when**: Maximum quality required

### Reinhard
- **Best for**: General purpose
- **Characteristics**: Simple, effective
- **Use when**: Performance priority

### Filmic
- **Best for**: Photorealistic rendering
- **Characteristics**: Mimics film response
- **Use when**: Natural look desired

### Hable
- **Best for**: Games/real-time
- **Characteristics**: Shoulder control
- **Use when**: Art direction needed

## Color Spaces

### Supported Color Spaces

| Space | Gamut | Use Case |
|-------|-------|----------|
| Rec. 709 | Standard | SDR fallback |
| Rec. 2020 | Ultra-wide | HDR broadcast |
| P3-D65 | Wide | Apple displays |
| scRGB | Extended | Windows HDR |

## Dynamic Range Optimization

### Modes

```objc
typedef NS_ENUM(NSInteger, DynamicRangeMode) {
    DynamicRangeModeOff,        // No optimization
    DynamicRangeModeConservative, // Safe adjustments
    DynamicRangeModeAggressive,   // Maximum range
    DynamicRangeModeAuto          // Automatic based on content
};
```

### Parameters

| Parameter | Range | Description |
|-----------|-------|-------------|
| `kneePoint` | 0.0-1.0 | Shadow/midtone transition |
| `shoulderPoint` | 0.0-1.0 | Midtone/highlight transition |
| `shadowDetail` | 0.0-1.0 | Shadow lift amount |
| `highlightDetail` | 0.0-1.0 | Highlight recovery |

## Usage

### Basic HDR Setup

```objc
HDRPipeline *pipeline = [HDRPipeline sharedPipeline];
[pipeline initializeWithDevice:device error:nil];

// Enable HDR
pipeline.hdrEnabled = YES;
pipeline.maxBrightness = 1000.0; // nits
pipeline.toneMapping = ToneMappingOperatorACES;
```

### Dynamic Range Optimization

```objc
DynamicRangeOptimizer *optimizer = [[DynamicRangeOptimizer alloc] initWithDevice:device];
optimizer.mode = DynamicRangeModeAuto;
optimizer.shadowDetail = 0.6;
optimizer.highlightDetail = 0.4;

// Analyze frame
[optimizer analyzeSceneBrightness:hdrTexture commandBuffer:commandBuffer];
[optimizer applyOptimizationToTexture:hdrTexture commandBuffer:commandBuffer];
```

### HDR Metadata

```objc
HDRMetadataGenerator *metadata = [[HDRMetadataGenerator alloc] init];
metadata.displayMasteringMaxLuminance = 1000.0;
metadata.contentMaxLuminance = 800.0;

NSData *hdr10Data = [metadata generateHDR10Metadata];
```

## Performance

### Recommendations

1. **Use 10-bit only when needed**: SDR fallback for performance
2. **Pre-allocate HDR textures**: Avoid runtime allocation
3. **Tone map at reduced resolution**: Scale up after tone mapping
4. **Cache analysis results**: Reuse for sequential frames

### Benchmarks

| Hardware | Resolution | HDR Format | FPS |
|----------|------------|------------|-----|
| Apple M2 | 1080p | RGBA16Float | 120 |
| Apple M2 | 4K | RGBA16Float | 60 |
| Apple M1 | 4K | RGBA16Float | 45 |
| Intel | 1080p | RGBA16Float | 60 |

## Display Support

### HDR Displays

| Display Type | Max Brightness | EDR Support |
|--------------|----------------|-------------|
| Apple XDR | 1600 nits | Yes |
| Apple Pro Display | 1000 nits | Yes |
| OLED TVs | 800-1000 nits | Varies |
| LED Monitors | 400-600 nits | Limited |

### Automatic Detection

```objc
if ([pipeline detectHDRDisplay]) {
    pipeline.hdrEnabled = YES;
    pipeline.edrEnabled = YES;
    pipeline.maxBrightness = [pipeline currentEDRHeadroom] * 1000.0;
}
```

## Troubleshooting

### Banding
- **Cause**: Insufficient bit depth
- **Solution**: Ensure 16-bit textures

### Clipping
- **Cause**: Tone mapper parameters
- **Solution**: Adjust shoulder point

### Performance
- **Cause**: 10-bit overhead
- **Solution**: Use SDR for preview

## API Reference

### HDRPipeline

```objc
@interface HDRPipeline : NSObject
@property(nonatomic, assign) BOOL hdrEnabled;
@property(nonatomic, assign) float maxBrightness;
@property(nonatomic, assign) ToneMappingOperator toneMapping;
- (void)toneMapHDRTexture:(id<MTLTexture>)hdr toSDRTexture:(id<MTLTexture>)sdr
          commandBuffer:(id<MTLCommandBuffer>)commandBuffer;
@end
```

### DynamicRangeOptimizer

```objc
@interface DynamicRangeOptimizer : NSObject
@property(nonatomic, assign) DynamicRangeMode mode;
- (simd_float3)applyLocalToneMapping:(simd_float3)color localLuminance:(float)luminance;
@end
```
