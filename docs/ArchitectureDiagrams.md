# ShaderCandy Architecture Diagrams

This document contains visual architectural specifications of key systems in ShaderCandy.

---

## 1. Rendering Pipelines

### macOS Metal Advanced Rendering Flow
Shows the full frame lifecycle on macOS including Dynamic Variable Rate Shading (VRS), Compute-Based Bloom, and HDR Tone Mapping:

```mermaid
flowchart TD
    A[ScreenSaverView / Standalone Window / Wallpaper] --> B[MTKView]
    B --> C[MetalRenderer.draw]
    C --> D{VRS Supported?}
    D -->|Yes| E["Create MTLRasterizationRateMap\n(Dynamic Peripheral Downscaling)"]
    D -->|No| F[Standard Full-Rate Target]
    E --> G[Setup RenderPassDescriptor]
    F --> G

    G --> H[Encode Main Scene Pass]
    H --> I[Shader Render Pipeline State]
    I --> J[Draw Full-Screen Quad / March Rays]
    J --> K[HDR Offscreen Texture: RGBA16Float]

    K --> L{Bloom Enabled?}
    L -->|Yes| M["Dispatch Compute Bloom Kernel\n(16x16 Threadgroup Shared Memory)"]
    L -->|No| N[Skip Bloom]
    M --> O[Blended HDR Texture]
    N --> O

    O --> P[Encode Tone Mapping Pass]
    P --> Q["Tone Map (ACES / Filmic / Reinhard / Hable)"]
    Q --> R["Drawable Present (EDR Headroom to 1600 nits)"]
```

### Linux OpenGL Rendering Flow
Shows X11 / Wayland surface binding and OpenGL 3.3+ frame execution:

```mermaid
flowchart TD
    A[X11 Window / Wayland Layer Surface] --> B[EGL / GLX Context]
    B --> C[GLRenderer.render]
    C --> D[Bind Framebuffer Object]
    D --> E[ShaderManager.getActiveProgram]
    E --> F[Uniform Upload via UniformBuffer]
    F --> G[Draw Full-Screen Quad]
    G --> H[Fragment Shader Execution]
    H --> I[HDR Tone Mapping Pass]
    I --> J[Swap Buffers / Present Surface]

    subgraph "GLSL Compilation & Program Cache"
        K[Shader Source .frag] --> L[Unified Include Resolver]
        L --> M[GLSL Compilation]
        M --> N[Program Object Link]
        N --> O[GL Pipeline Cache]
    end

    E -.-> O
```

---

## 2. Multi-Display Virtual Canvas & Spanning System

The `MultiDisplayManager` coordinates display geometry, virtual-to-physical coordinate transformations, and headless offscreen rendering across heterogeneous monitor setups:

```mermaid
flowchart TD
    subgraph "Display Enumeration"
        OS["OS Display Subsystem\n(NSScreen / XRandR / wl_output)"] --> MDM[MultiDisplayManager]
        MDM --> DList["std::vector<DisplayInfo>\n(Positions, Resolutions, ScaleFactors)"]
    end

    subgraph "Virtual Canvas Geometry"
        DList --> BB["Compute Bounding Box\n(minX, minY, maxX, maxY)"]
        BB --> VW["Virtual Canvas Width: max(1, maxX - minX)"]
        BB --> VH["Virtual Canvas Height: max(1, maxY - minY)"]
        VW & VH --> AR["Virtual Aspect Ratio: VW / VH"]
    end

    subgraph "Coordinate Mapping Modes"
        MDM --> SM{SpanMode}
        SM -->|Single| S1["One Shader on Primary Display"]
        SM -->|SpanAll| S2["Stretched Across All Displays\n(virtualToDisplay & displayToVirtual)"]
        SM -->|Clone| S3["Identical Frame Broadcast to All Outputs"]
        SM -->|Independent| S4["Per-Display Unique Shader & Parameter Assignment"]
    end

    subgraph "Headless / Offscreen Renderer"
        MDM --> HR[HeadlessRenderer]
        HR --> FBO[Offscreen Target FBO / Texture]
        FBO --> PBO[Pixel Buffer Readback]
        PBO --> CB[Progress & Frame Callback]
    end
```

---

## 3. Dynamic VRS & Compute-Based Bloom Pipeline

Illustrates how Apple Silicon hardware features (Tile Memory and Variable Rate Shading) optimize fragment workload:

```mermaid
flowchart LR
    subgraph "1. Rate Map Generation"
        PM[PerformanceMonitor] --> VRS["VRS Tier Selector\n(M1+: 1/2, 1/4 Peripheral Rates)"]
        VRS --> RMD["MTLRasterizationRateMapDescriptor"]
        RMD --> RMap["MTLRasterizationRateMap Alloc"]
    end

    subgraph "2. Primary Render Pass"
        RMap --> RP["MTLRenderPassDescriptor\n.rasterizationRateMap = RMap"]
        RP --> FS["Fragment Shader / Raymarcher\n(Coarser Shading in Periphery)"]
        FS --> OutTex["HDR Render Target\n(RGBA16Float)"]
    end

    subgraph "3. Tile Compute Bloom"
        OutTex --> CS["Compute Command Encoder"]
        CS --> TG["16x16 Threadgroup Tile Memory\n(Zero Intermediate Fullscreen Quads)"]
        TG --> Bright["Bright Pass Threshold"]
        Bright --> Blur["Two-Pass Separable Gaussian Blur"]
        Blur --> BloomTex["Final Bloom Texture"]
    end

    subgraph "4. Composite & Present"
        OutTex & BloomTex --> Comp["Composite & Tone Map Pass"]
        Comp --> BackBuffer["MTKView Current Drawable"]
    end
```

---

## 4. Audio Processing & MPS Spatial Audio Pipeline

### FFT Audio Reactivity System
Translates raw microphone or system audio input into spectral energy bands and beat uniforms:

```mermaid
flowchart TD
    A[Microphone / System Audio Input] --> B["Audio Input Subsystem\n(AVFoundation / ALSA)"]
    B --> C[Circular Sample Buffer]
    C --> D[Hann Window Function]
    D --> E["FFT Spectrum Analysis\n(vDSP / FFTW3)"]
    E --> F[Magnitude Spectrum: 256 / 1024 Bins]

    F --> G[Bass Band: 20-250 Hz]
    F --> H[Mid Band: 250-4000 Hz]
    F --> I[Treble Band: 4000-16000 Hz]

    G --> J[Energy History Buffer]
    J --> K["Spectral Flux Beat Detection\n(Threshold > Variance * Sensitivity)"]

    G & H & I & K --> U["UniformBuffer Audio Uniforms\n(bass, mid, treble, beat, audioData[256])"]
    U --> S[Shader Access in Fragment Stage]
```

### Metal Performance Shaders (MPS) Spatial Audio Ray-Tracing
Hardware-accelerated acoustic room simulation for realistic spatial reflection and occlusion:

```mermaid
flowchart TD
    subgraph "Scene & Acoustic Geometry"
        RG["Room Geometry\n(Walls, Floors, Obstacles)"] --> VT["Vertex & Index Buffers"]
        VT --> AS["MTLAccelerationStructure\n(Bottom-Level Bounding Volume Hierarchy)"]
        AS --> BLAS["Built via MPSTriangleAccelerationStructure"]
    end

    subgraph "Ray Generation & Intersection"
        Src["Sound Source Position"] --> RGK["Ray Generation Kernel"]
        RGK --> RBuf["MPSRay Buffer\n(origin, direction, minDistance, maxDistance)"]
        RBuf --> Intersector["MPSRayIntersector.encodeIntersection"]
        BLAS --> Intersector
        Intersector --> IBuf["MPSIntersection Buffer\n(distance, primitiveIndex, coordinates)"]
    end

    subgraph "Acoustic Impulse Response"
        IBuf --> Material["Material Absorption Coefficients"]
        Material --> EarlyRefl["Calculate Early Reflections"]
        EarlyRefl --> Reverb["Synthesize B-Format Ambisonic IR"]
        Reverb --> Out["Spatial Audio Spatializer Output"]
    end
```

---

## 5. Neural Style Transfer System

GPU-accelerated CoreML style transfer pipeline running on Apple Neural Engine (ANE) and Metal:

```mermaid
flowchart TD
    A[Raw Shader Frame: MTLTexture] --> B[NeuralStyleEngine.applyStyle]
    B --> C["Preprocess Pass\n(Color Space Conversion & Resize to 512x512)"]
    C --> D["CVPixelBuffer Pool Allocation\n(Zero-Copy Shared Memory)"]

    subgraph "CoreML / Apple Neural Engine (ANE)"
        D --> ML["CoreML Model: StyleTransferModel\n(FP16 Quantized Weights)"]
        ML --> Inf["Model Inference on ANE / GPU"]
        Inf --> OutPB["Styled Output CVPixelBuffer"]
    end

    OutPB --> E["Postprocess Compute Pass\n(neural_style_blend.metal)"]
    E --> F["Alpha Blend with Original Shader Frame\n(Weighted by styleStrength)"]
    F --> G[Styled Output MTLTexture]

    subgraph "Model Management"
        M1[Starry Night] & M2[Monet] & M3[Picasso] & M4[Hokusai] & M5[Cyberpunk] --> Lib[Model Library]
        Lib --> Cache[Model Cache]
        Cache --> ML
    end
```

---

## 6. Unified ShaderManager & Hot-Reload Observer Pattern

The cross-platform `UnifiedShaderManager` provides centralized discovery, recursive include resolution, and hot reloading:

```mermaid
flowchart TD
    subgraph "Discovery & File System Watching"
        FS["File System: shaders/ (base, effects, music)"] --> Scan["UnifiedShaderManager.scanDirectory"]
        Scan --> Catalog["Shader Catalog Map\n(Name -> FilePath, LastWriteTime)"]
        Timer["Frame Loop / Render Tick"] --> Watch["UnifiedShaderManager.reloadShaders"]
        Catalog --> Watch
        Watch --> Mod{File Timestamp > LastWriteTime?}
    end

    subgraph "Compilation & Dependency Resolution"
        Mod -->|Yes| Read[Read Shader Source]
        Read --> Inc["Recursive #include Resolver\n(common.metal / common.glsl)"]
        Inc --> Comp{Compile Shader Source}
        Comp -->|Success| UpdCache["Update Pipeline State Cache"]
        Comp -->|Failure| Rollback["Log Error & Rollback to Previous Valid State"]
    end

    subgraph "Observer Notification"
        UpdCache --> CB["Invoke shaderChangedCallback_"]
        CB --> Rend["Renderer Pipeline Invalidation"]
        CB --> UI["OSD Notification Update"]
    end
```

---

## 7. Uniform Buffer Data Flow

Double-buffered CPU-to-GPU data synchronization ensuring zero frame tearing:

```mermaid
flowchart TD
    A[Frame Start] --> B[UniformBuffer.update]

    subgraph "CPU State Aggregation"
        T[Time & DeltaTime] --> Agg[Aggregate Uniform Struct]
        Res[Resolution & Aspect Ratio] --> Agg
        M[Mouse & Interaction State] --> Agg
        Acoustic[Audio Bands & FFT Spectrum] --> Agg
        OSD[Dynamic Parameters: Speed, Intensity] --> Agg
    end

    Agg --> C["Copy to Active Ring Buffer Slot\n(Frame N % 2)"]

    subgraph "GPU Memory Strategy"
        C --> B0["Buffer Slot 0 (MTLStorageModeShared / GL UBO)"]
        C --> B1["Buffer Slot 1 (MTLStorageModeShared / GL UBO)"]
    end

    B0 -.->|Frame Even| GPU[Shader Stage Access: buffer 0]
    B1 -.->|Frame Odd| GPU
```

---

## 8. Test Framework & Regression Architecture

Comprehensive test suite integrating unit validation, coverage expansion, and compilation regression checks:

```mermaid
flowchart TD
    subgraph "Test Suite Runner (shadercandy-test)"
        Main[tests/main.cpp] --> Reg[Test Registry]
        Reg --> S1["Math & SIMD Tests\n(AVX2 / NEON / Scalar)"]
        Reg --> S2["Logic & Uniform Tests\n(Alignment, Presets, Math)"]
        Reg --> S3["Shader Compilation Tests\n(52+ Fragment Shaders)"]
        Reg --> S4["Renderer Feature Tests\n(Resolution, Thermal, MultiDisplay)"]
        Reg --> S5["Coverage Expansion Tests\n(Core Modules 99% Coverage)"]
        Reg --> S6["Shader Regression Detector\n(Compile-Time Benchmark Threshold: 20%)"]
    end

    S1 & S2 & S3 & S4 & S5 & S6 --> Runner[TestSuite.run]
    Runner --> Results["std::vector<TestResult>"]
    Results --> Format["Console Summary & Exit Code Report"]
```

---

## 9. Project Directory Layout

```mermaid
graph TD
    Root[ShaderCandy Repository] --> Shaders[shaders/]
    Root --> Src[src/]
    Root --> Tests[tests/]
    Root --> Docs[docs/]
    Root --> Install[install/]

    Shaders --> SBase["base/ (common.metal, common.glsl, utils)"]
    Shaders --> SEffects["effects/ (raymarching, fractals, visual effects)"]
    Shaders --> SMusic["music/ (audio-reactive genre shaders)"]

    Src --> Core["core/ (ShaderManager, MultiDisplay, Uniforms, Performance)"]
    Src --> Metal["metal/ (MetalRenderer, PipelineCache, HeapManager)"]
    Src --> GL["gl/ (GLRenderer, GLShaderCompiler)"]
    Src --> Platform["platform/ (macos, linux x11/wayland)"]
    Src --> Audio["audio/ (AudioInput, AcousticSimulator)"]
    Src --> Neural["neural/ (NeuralStyleEngine, StyleModel)"]
    Src --> Config["config/ (ConfigurationManager, Presets)"]

    Docs --> D1["nextsteps.md (Active Roadmap)"]
    Docs --> D2["ShaderCandyMasterPlan.md (Architecture Master)"]
    Docs --> D3["ArchitectureDiagrams.md (This Document)"]
    Docs --> D4["ApplicationModesGuide.md (User Guide)"]
    Docs --> D5["ShaderAuthoringGuide.md (Developer Guide)"]
    Docs --> D6["LinuxFeatures.md (Linux Platform)"]
    Docs --> D7["HdrImplementation.md (HDR Specification)"]
    Docs --> D8["NeuralEffectsGuide.md (CoreML System)"]
    Docs --> D9["shaders.md (110+ Shader Catalog)"]
```
