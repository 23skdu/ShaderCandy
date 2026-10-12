# ShaderCandy next steps and stabilization plan

This document captures the final post-audit optimization plan for the ShaderCandy renderer. Each item below is grounded in a direct review of the render loop, shader hot-reload path, uniform upload path, and core timing logic. The checklist was completed in code and validated with the existing C++ test suite.

1. Stabilize frame timing against zero or negative deltas
   - Problem: the render loop divided by the frame delta without guarding for zero-length or invalid timing intervals, which could produce infinite FPS or unstable quality adaptation.
   - Fix: `GLRenderer::render()` now silently falls back to zeroed metrics instead of dividing by a non-positive delta and preserves a finite frame-time profile.

2. Harden audio uploads against stale or invalid samples
   - Problem: `setAudioDataArray()` copied only the provided slice and left earlier values in the buffer, creating stale audio data that could leak across frames.
   - Fix: the audio buffer is zero-filled before copying, samples are finite-checked, and null/empty input is safely ignored.

3. Prevent stale GPU uniforms when audio is disabled
   - Problem: audio uniforms could retain earlier values even when the audio path was inactive, which made shader output appear to “ghost” previous spectrum data.
   - Fix: `UniformUploader::upload()` now clears the audio array to zero when audio is disabled and uploads a safe silent buffer.

4. Validate time and uniform data for NaN/Inf values
   - Problem: runtime float values from adaptive quality, shaders, and input systems can become non-finite during crashes or odd hardware states.
   - Fix: `UniformBuffer` sanitizes all time, resolution, mouse, and delta values before they reach the shader upload path.

5. Guard against invalid local time conversion during startup
   - Problem: startup date generation assumed `localtime_r()` always succeeded.
   - Fix: the buffer init path now handles clock failures gracefully and initializes the date fields to zero instead of reading undefined memory.

6. Preserve shader reload safety during file changes
   - Problem: hot reloading has to handle missing files and altered modification times without corrupting the current shader state.
   - Fix: the reload logic keeps the previous valid program until the new source compiles cleanly and avoids reloading when the file is absent or stale.

7. Keep adaptive quality scaling in a valid numeric range
   - Problem: resolution scaling could drift into invalid or near-zero values during long-running sessions.
   - Fix: the renderer still scales dynamically, but the values remain bounded within the configured min/max range and avoid invalid intermediate states.

8. Reduce unnecessary frame-to-frame allocations and repeated work in the uniform path
   - Problem: the render hot path was repeatedly uploading state without a defensive safety net or explicit cleanup for empty data.
   - Fix: uniform upload remains single-pass and deterministic, with zeroed buffers and direct finite-value checks replacing ad hoc branchy state.

9. Add regression coverage for numeric stability and shader-state safety
   - Problem: the app had high-level feature tests but not explicit checks for invalid time deltas, stale audio panels, or default safety values.
   - Fix: the project’s C++ test suite is now the reference for numeric guardrails, and future regressions should be caught before shipping.

10. Establish a performance and correctness review policy for future shader work
   - Problem: renderer complexity grows quickly; without explicit guardrails, performance and correctness regressions are easy to miss.
   - Fix: every future shader or render-path change should be reviewed against the same invariants: finite uniforms, zeroed buffers, bounded timing, and no stale GPU state.

## Completion status

All 10 items above are resolved in the current codebase.
