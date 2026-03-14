# Next Steps / Improvement Plan for ShaderCandy

## Top Priorities

### Branchless Programming Optimizations (COMPLETED)

1. **GPU Family Detection in MetalRenderer (src/metal/MetalRenderer.mm:71-101)** ✅
   - Replaced if-else chain with branchless ternary operators
   - **Benefit**: Eliminates branch misprediction penalties on GPU detection hot path

2. **Shader Branch Elimination in art_deco.metal** ✅
   - Replaced if-else for coloring with branchless `mix()` function
   - **Benefit**: Eliminates GPU shader branch divergence

3. **Texture Dimension Selection (src/metal/MetalRenderer.mm:461-469)** ✅
   - Replaced if-else chain with branchless ternary operators
   - **Benefit**: Cleaner code with predictable performance

### Shader Fixes (COMPLETED)

1. **capman.metal** ✅ - Fixed program scope variable error by adding `constant` qualifier
2. **raymarch_sculpture.metal** ✅ - Fixed missing SDF function calls by inlining operations
3. **GLSL Test Path Issues** ✅ - Fixed vertex.glsl and common.glsl path resolution

### ZeroCopy Memory Optimization Opportunities

4. **Uniform Buffer Management (src/metal/MetalRenderer.mm:660-662)**
   - Current: Triple-buffered uniform buffer with MTLResourceStorageModeShared
   - **ZeroCopy Opportunity**: Use MTLBuffer with CPU-visible memory for frame data
   - **Optimization**: Map buffer memory directly for CPU writes, eliminate intermediate copies
   - **Benefit**: Reduces memory bandwidth by eliminating CPU→GPU buffer copies

5. **Shader Source Loading (src/metal/MetalRenderer.mm:863-873)**
   - Current: Reads shader files to NSString, prepends headers, then compiles
   - **ZeroCopy Opportunity**: Pre-compile shader libraries at build time
   - **Optimization**: Bundle compiled .metallib files instead of .metal source
   - **Benefit**: Eliminates runtime shader parsing and string concatenation overhead

6. **Particle Buffer Management (src/metal/MetalRenderer.mm:684-706)**
   - Current: Creates separate buffers for particleBufferA/B with MTLResourceStorageModeShared
   - **ZeroCopy Opportunity**: Use MTLBuffer's map/unmap for direct CPU access
   - **Optimization**: Reuse buffers with persistent mapping instead of recreating
   - **Benefit**: Eliminates per-frame buffer allocation overhead

### Memory Access Pattern Optimizations

7. **Audio Data Processing (src/audio/AudioInput.mm:227-260)**
   - Multiple conditional checks for beat detection
   - **Optimization**: Use SIMD operations for bulk energy calculations
   - **Benefit**: Process multiple frequency bands simultaneously

8. **Texture Size Calculations (src/metal/MetalRenderer.mm:728-744)**
   - Multiple if-else checks for resolution scaling
   - **Optimization**: Use max() and min() functions instead of branches
   - **Benefit**: Eliminates branch divergence in texture creation

### Build-time Optimizations

9. **Shader Compilation Pipeline**
   - Current: Runtime compilation from .metal source with header injection
   - **ZeroCopy Opportunity**: Use Metal Performance Shaders (MPS) precompiled kernels
   - **Optimization**: Pre-bake shader variants for common effects (bloom, blur, etc.)
   - **Benefit**: Reduces first-frame shader compilation hitches

10. **GPU Resource Binding**
    - Current: Per-frame uniform buffer binding
    - **Optimization**: Use argument buffers and indirect command encoding
    - **Benefit**: Reduces CPU overhead for resource binding

## Immediate Branchless/ZeroCopy Actions

- [x] Implement GPU family detection using bitmask approach - COMPLETED
- [x] Replace shader if-else branches with mix/step functions - COMPLETED
- [ ] Convert shader source loading to precompiled metallib bundles - NEXT
- [ ] Use MTLBuffer mapping for uniform buffers instead of shared storage - TODO
- [ ] Implement SIMD-based audio energy calculations - TODO
- [ ] Add precompiled shader variants for common effects - TODO

## Top Priorities (Existing)

### Shader Validation ✅ COMPLETED
1. Implemented automated shader testing suite that verifies all Metal shaders compile and link correctly
2. All 112 Metal shaders compile successfully
3. All 6 GLSL tests now pass (fixed path issues)
4. Total: 146 tests passing, 0 failing

### Metal Performance Optimization
4. Profile shader execution using Xcode Instruments to identify bottlenecks
5. Optimize compute shaders for particle systems and simulation passes
6. Implement adaptive quality settings based on GPU tier and thermal state

### Cross-Platform Parity Enhancement
7. Ensure all Metal shaders have equivalent GLSL implementations for Linux
8. Create automated shader translation verification between Metal and GLSL
9. Standardize shader interface uniforms and buffers across platforms

### Enhanced Error Handling and Reporting
10. Improve shader compilation error reporting with line numbers and context
11. Add fallback mechanisms for failed shaders (graceful degradation)
12. Implement shader hot-reload failure recovery mechanisms

### Resource Management Improvements
13. Optimize texture pooling and memory allocation patterns
14. Implement smarter texture resolution scaling for Retina/4K+ displays
15. Add memory usage tracking and alerts for resource exhaustion

### Advanced Rendering Features
16. Implement ray tracing acceleration where supported (Metal Performance Shaders)
17. Add support for variable rate shading and mesh shaders on Apple Silicon
18. Implement temporal anti-aliasing and motion blur effects

### Audio-Visual Synchronization
19. Enhance audio-reactive shader uniforms with better FFT data
20. Implement beat detection and audio onset triggering for visual effects
21. Add support for spatial audio effects in shaders

### User Experience and Configuration
22. Create shader preview gallery with thumbnails and descriptions
23. Implement user-configurable shader parameters via UI
24. Add shader sequencing and transition customization options

### Documentation and Knowledge Sharing
25. Create comprehensive shader authoring guide with best practices
26. Document shared shader library functions and utilities
27. Add tutorial examples for creating new visual effects

### Build System and Deployment
28. Optimize build times through better dependency tracking
29. Create universal binaries for Apple Silicon and Intel Macs
30. Implement code signing and notarization for distribution

## Shader Verification Strategy

To ensure all shaders work in both screensaver and standalone app:

1. **Automated Shader Testing**
   - Create test target that instantiates MetalRenderer and calls `testAllShaders` method
   - Verify each shader loads without compilation errors
   - Test shader execution with minimal render pass to validate pipeline state creation
   - **Status**: ✅ All 146 tests passing (0 failed)

2. **Context-Specific Validation**
   - Screensaver context: Test within ScreenSaverView lifecycle
   - Standalone app context: Test within NSWindow/NSViewController lifecycle
   - Verify resource loading paths work correctly in both bundle contexts

3. **Regression Prevention**
   - Add shader tests to CI/CD pipeline
   - Create baseline shader performance metrics
   - Implement shader hash tracking to detect unintended changes

## Immediate Actions - ALL COMPLETED ✅

- [x] Fix capman.metal shader (constant address space issue) - COMPLETED
- [x] Fix raymarch_sculpture.metal shader (missing SDF functions) - COMPLETED  
- [x] Optimize art_deco.metal with branchless mixing - COMPLETED
- [x] Optimize GPU family detection in MetalRenderer - COMPLETED
- [x] Fix GLSL test failures (vertex.glsl/common.glsl path issues) - COMPLETED
- [x] Add branchless and ZeroCopy optimizations to docs/nextsteps.md - COMPLETED

## Next Actions (Future Work)

- [ ] Implement ZeroCopy uniform buffer management
- [ ] Convert shader loading to precompiled metallib bundles
- [ ] Implement SIMD-based audio energy calculations
- [ ] Profile top 10 most complex shaders for performance bottlenecks

---
*Last updated: 2026-03-14*