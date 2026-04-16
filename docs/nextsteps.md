# ShaderCandy: Roadmap for Performance & Stability

**Last Updated:** April 15, 2026

---

## 🚀 Performance Optimization

1.  **Metal Parallel Encoder Integration**
    Use multiple parallel render command encoders for complex scenes with many post-processing passes. This better utilizes multi-core CPUs during frame encoding.

2.  **Indirect Command Buffers (ICB)**
    Implement ICB for particle systems to reduce CPU overhead in frame recording and allow the GPU to generate its own draw calls for dynamic systems.

3.  **Variable Rate Shading (VRS)**
    Utilize VRS on supported Apple Silicon (M1+) to reduce fragment shader load in less detailed areas of the screen without visible quality loss.

4.  **Metal Mesh Shaders**
    Transition particle rendering and complex geometry to Mesh Shaders for M2/M3 GPUs to significantly improve vertex throughput and culling efficiency.

5.  **Compute-Based Bloom & Effects**
    Replace current fragment-based bloom with a more efficient tile-based compute shader implementation, taking advantage of local memory (threadgroup memory) on Apple GPUs.

6.  **Persistent Pipeline State Object (PSO) Disk Cache**
    Implement a persistent disk cache for Metal PSOs to eliminate micro-stutter during the first load of a shader by reusing pre-compiled binaries.

---

## 🛡️ Stability & Power Management

7.  **Battery & Thermal Aware Rendering**
    Add a "Low Power Mode" that automatically caps FPS, reduces resolution scale, and simplifies shader complexity when on battery or when thermal throttling is detected.

8.  **Unified Memory Management Audit**
    Audit and optimize all buffer allocations to use `MTLStorageModeShared` with proper alignment and padding for true zero-copy access between CPU and GPU.

9.  **Dynamic LoD for Audio Visualization**
    Scale the complexity of FFT processing and visualization based on current GPU load and audio complexity to ensure stable 60+ FPS during intense segments.

10. **Spatial Audio Ray-Tracing Optimization**
    Implement a more efficient ray-tracer for spatial audio using Metal Performance Shaders (MPS) to reduce the CPU cost of the soundscape engine.

---

## ⌨️ Keyboard Controls Reference

| Key | Action |
|-----|--------|
| Escape / Ctrl+Q | Quit |
| Right Arrow / Space / P | Next shader |
| Left Arrow / N | Previous shader |
| F12 / PrintScreen | Screenshot |
| 1–5 | Adjust shader params |
| Ctrl+S / Ctrl+O | Save/Load preset |
| Tab | Switch display |
| Ctrl++ / Ctrl+- | Intensity |
| D | Toggle debug overlay |
| T | Run shader test suite |