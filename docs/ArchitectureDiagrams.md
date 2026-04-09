# ShaderCandy Architecture Diagrams

This document contains visual documentation of key systems in ShaderCandy.

## Rendering Pipeline

### macOS Metal Rendering Flow

```mermaid
flowchart TD
    A[ScreenSaverView / Standalone Window] --> B[MTKView]
    B --> C[Metal Renderer]
    C --> D[Shader Compiler]
    D --> E[Render Pipeline State]
    E --> F[Command Buffer]
    F --> G[Render Encoder]
    G --> H[Frame Rendered]

    subgraph "Shader Pipeline"
        I[Shader Source (.metal)] --> J[Runtime Compilation]
        J --> K[Function Library]
        K --> L[Pipeline Cache]
    end

    subgraph "Uniform Management"
        M[Uniform Buffer] --> N[CPU -> GPU Upload]
        N --> O[Shader Uniforms]
    end

    D --> I
    L --> E
    M --> O
```

### Linux OpenGL Rendering Flow

```mermaid
flowchart TD
    A[X11 Window / Wayland Surface] --> B[OpenGL Context]
    B --> C[GL Renderer]
    C --> D[Shader Compiler]
    D --> E[Shader Program]
    E --> F[Render Loop]
    F --> G[Draw Calls]
    G --> H[Frame Rendered]

    subgraph "Shader Pipeline"
        I[Shader Source (.frag/.glsl)] --> J[GLSL Compilation]
        J --> K[Program Object]
        K --> L[Program Cache]
    end

    subgraph "Uniform Management"
        M[Uniform Variables] --> N[CPU -> GPU Upload]
        N --> O[Shader Uniforms]
    end

    D --> I
    L --> E
    M --> O
```

## Audio System

### Audio Input Processing Flow

```mermaid
flowchart TD
    A[Microphone Input] --> B[Audio Input System]
    B --> C[FFT Processing]
    C --> D[Frequency Bands]
    D --> E[Beat Detection]
    E --> F[Audio Reactivity Data]
    F --> G[Shader Uniforms]

    subgraph "Audio Analysis"
        H[Raw Audio Samples] --> I[Windowing Function]
        I --> J[FFT Transform]
        J --> K[Spectrum Analysis]
    end

    subgraph "Reactivity Mapping"
        L[Bass Response] --> M[Low Frequency Uniforms]
        N[Mid Response] --> O[Mid Frequency Uniforms]
        P[High Response] --> Q[High Frequency Uniforms]
    end

    A --> H
    K --> L
    K --> N
    K --> P
    M --> G
    O --> G
    Q --> G
```

## Neural Style Transfer System

### CoreML Style Transfer Pipeline

```mermaid
flowchart TD
    A[Input Frame] --> B[Neural Style Engine]
    B --> C[Style Model Loader]
    C --> D[Model Selection]
    D --> E[CoreML Inference]
    E --> F[Style Transfer]
    F --> G[Output Frame]

    subgraph "Model Management"
        H[.mlmodel Files] --> I[Model Library]
        I --> J[Model Cache]
        J --> D
    end

    subgraph "Style Parameters"
        K[Style Intensity] --> L[Uniform Buffer]
        M[Style Selection] --> L
        N[Blend Mode] --> L
        L --> E
    end
```

## Shader Management System

### Shader Compilation and Caching

```mermaid
flowchart TD
    A[Shader Source Files] --> B[Shader Manager]
    B --> C[File Watcher]
    C --> D[Hot Reload Trigger]
    D --> E[Shader Compiler]
    E --> F[Compilation Result]
    F --> G{Success?}
    G -->|Yes| H[Update Pipeline Cache]
    G -->|No| I[Error Handling]
    I --> J[Fallback to Previous]
    J --> K[Error Reporting]

    subgraph "Platform-Specific Compilation"
        L[Metal Compiler] --> M[.metallib Generation]
        N[GLSL Compiler] --> O[Program Object]
    end

    E --> L
    E --> N
    H --> P[Render System]
```

## Uniform Buffer Management

### CPU to GPU Data Flow

```mermaid
flowchart TD
    A[Frame Start] --> B[Update Uniforms]
    B --> C[CPU State]
    C --> D[Uniform Buffer]
    D --> E[GPU Upload]
    E --> F[Shader Access]

    subgraph "Buffer Strategy"
        G[Double Buffering] --> H[Frame N Buffer]
        G --> I[Frame N+1 Buffer]
        H --> E
        I --> E
    end

    subgraph "Uniform Types"
        J[Time / Resolution] --> K[Global Uniforms]
        L[Camera / View] --> K
        M[Mouse / Input] --> K
        N[Audio Data] --> K
        O[Custom Params] --> K
    end

    K --> D
```

## Platform Abstraction Layer

### Cross-Platform Architecture

```mermaid
flowchart TD
    A[Application Layer] --> B[Platform Abstraction]
    B --> C[macOS Metal Backend]
    B --> D[Linux OpenGL Backend]
    B --> E[Linux Wayland Backend]

    subgraph "Shared Core"
        F[Math Utilities]
        G[Shader Manager]
        H[Performance Monitor]
        I[Configuration]
    end

    C --> F
    C --> G
    C --> H
    C --> I

    D --> F
    D --> G
    D --> H
    D --> I

    E --> F
    E --> G
    E --> H
    E --> I

    subgraph "Platform-Specific"
        J[ScreenSaverView] --> C
        K[Standalone App] --> C
        L[X11 Screensaver] --> D
        M[Wayland Screensaver] --> E
    end
```

## Performance Monitoring System

### Frame Timing and Metrics

```mermaid
flowchart TD
    A[Frame Start] --> B[PerformanceMonitor.beginFrame]
    B --> C[Render Pass]
    C --> D[PerformanceMonitor.endFrame]
    D --> E[Calculate Metrics]
    E --> F[Update History]
    F --> G[Generate Reports]

    subgraph "Metrics Collected"
        H[Frame Time] --> I[Average FPS]
        J[GPU Time] --> K[P99 Frame Time]
        L[CPU Time] --> M[Dropped Frames]
    end

    subgraph "Reporting"
        N[Real-time Display] --> O[Debug Overlay]
        P[Logging] --> Q[Performance Log]
        R[Regression Detection] --> S[Alert System]
    end

    E --> H
    E --> J
    E --> L
    F --> N
    F --> P
    F --> R
```

## File Structure Overview

### Directory Layout

```mermaid
graph TD
    A[ShaderCandy] --> B[src]
    A --> C[shaders]
    A --> D[tests]
    A --> E[docs]
    A --> F[install]

    B --> G[core]
    B --> H[metal]
    B --> I[gl]
    B --> J[platform]
    B --> K[audio]
    B --> L[neural]
    B --> M[config]

    C --> N[base]
    C --> O[effects]

    subgraph "Core Libraries"
        G --> P[MathUtils]
        G --> Q[ShaderManager]
        G --> R[PerformanceMonitor]
        G --> S[UniformBuffer]
    end

    subgraph "Platform Backends"
        H --> T[MetalRenderer]
        I --> U[GLRenderer]
    end
```

## Key Design Patterns

### Observer Pattern for Hot Reload

```mermaid
flowchart TD
    A[File Watcher] --> B[Subject]
    B --> C[Shader Manager (Observer)]
    B --> D[Renderer (Observer)]
    B --> E[UI (Observer)]

    C --> F[Recompile Shaders]
    D --> G[Update Pipeline]
    E --> H[Show Status]
```

### Strategy Pattern for Tone Mapping

```mermaid
flowchart TD
    A[Tone Mapping Controller] --> B{Strategy Selection}
    B --> C[ACES Filmic]
    B --> D[Reinhard]
    B --> E[Reinhard-Jodie]
    B --> F[Hable]

    C --> G[Apply Tone Mapping]
    D --> G
    E --> G
    F --> G

    G --> H[Final Color]
```

## Notes

- All diagrams use Mermaid syntax for rendering
- Diagrams can be rendered using Mermaid live editor or any Mermaid-compatible tool
- Update these diagrams when architecture changes significantly
