# Plan: 5 New Shaders

**Status:** Proposed (not yet implemented)  
**Owner:** ShaderCandy contributors  
**Related:** `docs/shaders.md`, `docs/ShaderAuthoringGuide.md`, `docs/roadmap.md` (P0 verification items)

This document is the implementation plan for adding **five new shaders** to the
ShaderCandy corpus while preserving the project's current guarantees:

- 100% GLSL / Metal parity (every `.frag` has a matching `.metal`).
- All shaders compile clean under `tests/validate_shaders.sh` (GLSL via `glslc`,
  Metal via `xcrun metal`).
- `effect_main(vec2 centered, vec2 uv)` entry point and the shared
  `shaders/base/common.glsl` / `shaders/base/utils.metal` uniforms.
- Long-session time wrapping (`mod(time * speed, 3600.0)`) and finite uniforms.
- Measured, not assumed, performance (see `docs/roadmap.md` Part 2).

## Scope

Add exactly five shaders, one per category, so the corpus grows from 117 `.frag`
files to 122 `.frag` files (and 115 -> 120 `.metal` files) with no regressions.

| # | Shader | Category | Directory | Audio-reactive |
|---|--------|----------|-----------|----------------|
| 1 | `solar_flare` | Nature & Environment | `shaders/effects/` | Yes (intensity from `bass`/`volume`) |
| 2 | `crystal_cavern` | Nature & Environment | `shaders/effects/` | Yes (sparkle from `treble`) |
| 3 | `neon_highway` | Visual Effects | `shaders/effects/` | Yes (lane speed from `bass`) |
| 4 | `coral_reef` | Nature & Environment | `shaders/effects/` | Yes (bubble rate from `mid`) |
| 5 | `fractal_clockwork` | Geometric & Mathematical | `shaders/effects/` | Yes (gear speed from `volume`) |

All five are placed under `shaders/effects/` to match the recent additions
(`clouds`, `default`, `smpte_calibration`) and keep the top-level shader list
focused on legacy standalone effects.

## Shared implementation contract (applies to all five)

1. **Files created (per shader):**
   - `shaders/effects/<name>.frag`
   - `shaders/effects/<name>.metal`
   - Entry in `docs/shaders.md` (category section + table of contents count).
   - Optional thumbnail under `thumbnails/` and `screenshots/` (generated, not
     committed unless already tracked).

2. **GLSL header:**
   ```glsl
   #include "base/common.glsl"

   // <name> - <one-line description>

   vec4 effect_main(vec2 centered, vec2 uv) {
       float t = mod(time * speed, 3600.0);
       vec2 p = centered;
       ...
       return vec4(color, alpha);
   }
   ```

3. **Metal header:** mirror the GLSL logic using `ShaderUtils` from
   `shaders/base/utils.metal`, with `#include "utils.metal"` so the file is
   self-contained for the offline `xcrun metal` build (see roadmap 2.6.9).

4. **Time wrapping:** use `mod(time * speed, 3600.0)` (or a multiple of it for
   effects with long cycles, e.g. `29524.0`).

5. **Finite uniforms:** do not introduce new non-finite values; reuse
   `sanitizeFinite`-guarded uniforms only.

6. **Audio reactivity:** read `bass`/`mid`/`treble`/`volume`/`beat` from the
   shared uniform block; never assume audio is present (fall back to a slow
   autonomous animation when `volume == 0`).

7. **Performance budget:** target >= 60 FPS at 1920x1080 on the reference
   Intel Graphics (ADL GT2) / Mesa backend. Any shader below 30 FPS must be
   gated behind `intensity` or reduced iteration counts with a measured
   `tests/ab_compare.sh` delta.

## Per-shader design

### 1. `solar_flare` (Nature & Environment)

- **Concept:** Animated solar surface with convection cells, sunspots, and
  erupting prominences on the limb.
- **Technique:** Domain-warped FBM for the photosphere; polar coordinates for
  limb prominences; additive corona glow.
- **Key uniforms:** `time`, `speed`, `intensity`, `bass` (flare eruption rate),
  `volume`.
- **Performance notes:** cap FBM at 4 octaves; gate the prominence loop on
  `abs(p.x) > 0.6` (bounding rejection, see roadmap 2.6.4).
- **Metal parity:** use `ShaderUtils::mod` (floored) and `constexpr` PI.

### 2. `crystal_cavern` (Nature & Environment)

- **Concept:** Glowing crystal formations in a dark cave with light caustics
  on the floor.
- **Technique:** SDF (hexagonal prisms) for crystals; raymarched caustics via
  animated normal perturbation; emissive crystal tips.
- **Key uniforms:** `time`, `speed`, `intensity`, `treble` (sparkle), `mouse`
  (flashlight direction).
- **Performance notes:** bounding sphere rejection around the crystal cluster;
  tetrahedral normals (roadmap 2.6.5) for the caustic pass.
- **Metal parity:** match SDF conventions with GLSL (see roadmap 2.7 item 9).

### 3. `neon_highway` (Visual Effects)

- **Concept:** Synthwave infinite highway at sunset with neon grid, retro sun,
  and passing light trails.
- **Technique:** Perspective-projected grid with animated scroll; radial sun
  with horizontal scanlines; instanced light trails via loop.
- **Key uniforms:** `time`, `speed`, `intensity`, `bass` (lane speed),
  `color1`/`color2` (neon palette).
- **Performance notes:** convert the light-trail loop to `int` counter; hoist
  `resolution.x / resolution.y` (use `centered`).
- **Metal parity:** avoid `fast::` on the gamma encode of the sun (roadmap
  2.6.10).

### 4. `coral_reef` (Nature & Environment)

- **Concept:** Underwater reef with swaying coral, fish silhouettes, and
  caustic light shafts.
- **Technique:** Layered 2D SDF coral; animated fish via simple kinematics;
  caustic pattern from overlapping sine waves.
- **Key uniforms:** `time`, `speed`, `intensity`, `mid` (bubble rate),
  `volume`.
- **Performance notes:** gate fish loop on screen-space AABB; reuse `centered`.
- **Metal parity:** use floored `mod` for bubble phase.

### 5. `fractal_clockwork` (Geometric & Mathematical)

- **Concept:** Steampunk clockwork with rotating gears and a fractal
  escapement mechanism.
- **Technique:** SDF gears (circles + teeth); recursive subdivision for the
  fractal escapement; brass/copper palette.
- **Key uniforms:** `time`, `speed`, `intensity`, `volume` (gear speed),
  `colorPalette`.
- **Performance notes:** cap recursion depth at 4; hoist gear rotation angles
  into a global array (roadmap 2.6.1 global-array LICM win).
- **Metal parity:** match rotation helper orientation (roadmap 2.7 item 4).

## Implementation phases

### Phase A - Scaffolding (per shader, ~1 file each)
1. Create `.frag` and `.metal` skeletons with the shared contract.
2. Add a minimal, correct (but unoptimized) reference implementation.
3. Run `tests/validate_shaders.sh`; expect 122/122 GLSL and 120/120 Metal clean.

### Phase B - Parity and correctness
1. Render both GLSL and Metal outputs at a pinned `time` (`ShaderBenchmark -time`)
   and compare with `tests/compare_frames.sh` (max per-channel delta 0 for
   deterministic parts; document any intentional differences).
2. Wrap time (`mod(time * speed, 3600.0)`); verify no precision drift.
3. Add audio fallback path (`volume == 0`).

### Phase C - Optimization (measured)
1. Baseline FPS via `tests/measure_shaders.sh` at 1920x1080.
2. Apply only optimizations from roadmap Part 2 with a measured win; reject
   anything that changes pixels unintentionally (escape-time counts are
   observable).
3. Re-run `tests/ab_compare.sh` against the Phase A reference; keep changes
   only if FPS improves and `compare_frames.sh` passes.

### Phase D - Documentation and registration
1. Add entries to `docs/shaders.md` (category sections + total count).
2. Update `docs/shaders.md` table of contents counts.
3. Regenerate `SHADER_CATALOG.md` (CI `documentation` job).
4. Add entries to `ShaderManager` scan paths if placed outside the scanned
   directories (currently `shaders/{audio,neural,system,...}` plus effects).

### Phase E - Verification
1. `make validate-shaders` (or `tests/validate_shaders.sh`) green.
2. `make test-all` green (140+ tests; new shaders must not break shader
   validation tests).
3. `make lint` and `make security` green.
4. On macOS (P0-19 arm64 job): Metal compile + test binary green.
5. Coverage gate unchanged or improved.

## Acceptance criteria

- [ ] 5 new `.frag` + 5 new `.metal` files, all compiling clean.
- [ ] 100% GLSL/Metal parity maintained (122 `.frag` / 120 `.metal`).
- [ ] Each shader >= 30 FPS at 1920x1080 on the reference backend (or
      documented reduction with measurement).
- [ ] `tests/validate_shaders.sh` reports `compiled OK: 122 failed: 0`.
- [ ] `docs/shaders.md` updated with entries and counts.
- [ ] No new compiler warnings under `tests/lint.sh`.

## Risks

- **Scope creep:** keep each shader to a single concept; defer advanced
  features to follow-up plans.
- **Parity drift:** Metal SDF/rotation conventions differ (roadmap 2.7);
  verify with `compare_frames.sh` on macOS before merging.
- **Performance:** raymarched shaders (crystal_cavern) may fall below 30 FPS;
  use bounding rejection and step caps, measured via `tests/bound_probe.sh`.
- **Time wrapping:** long-cycle effects (clockwork) need a period that is a
  multiple of all sub-cycles (see `capman.frag` 29524.0 precedent).
