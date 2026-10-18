# ShaderCandy next steps and stabilization plan

This document captures the post-audit optimization plan for the ShaderCandy
renderer. It has two parts:

* **Part 1** — the original stabilization pass (items 1-10), which is complete.
* **Part 2** — the shader/SIMD performance pass. This is the current work.

Part 2 is grounded in a review of all 114 GLSL fragment shaders and 116 Metal
shaders, the shared shader libraries, the GLSL include/preamble pipeline, the
OpenGL render loop, the CPU-side audio analysis path, and the build flags. Every
quantified claim below was either measured on hardware with
`build/shadercandy-bench` or is explicitly labelled as an analytical estimate.

---

## Part 1 - Stabilization (complete)

1. Stabilize frame timing against zero or negative deltas
   - Problem: the render loop divided by the frame delta without guarding for zero-length or invalid timing intervals, which could produce infinite FPS or unstable quality adaptation.
   - Fix: `GLRenderer::render()` now silently falls back to zeroed metrics instead of dividing by a non-positive delta and preserves a finite frame-time profile.

2. Harden audio uploads against stale or invalid samples
   - Problem: `setAudioDataArray()` copied only the provided slice and left earlier values in the buffer, creating stale audio data that could leak across frames.
   - Fix: the audio buffer is zero-filled before copying, samples are finite-checked, and null/empty input is safely ignored.

3. Prevent stale GPU uniforms when audio is disabled
   - Problem: audio uniforms could retain earlier values even when the audio path was inactive, which made shader output appear to "ghost" previous spectrum data.
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
   - Fix: the project's C++ test suite is now the reference for numeric guardrails, and future regressions should be caught before shipping.

10. Establish a performance and correctness review policy for future shader work
   - Problem: renderer complexity grows quickly; without explicit guardrails, performance and correctness regressions are easy to miss.
   - Fix: every future shader or render-path change should be reviewed against the same invariants: finite uniforms, zeroed buffers, bounded timing, and no stale GPU state.

### Completion status

All 10 items above are resolved in the current codebase.

---

## Part 2 - Shader and SIMD performance

### 2.1 How the shader corpus is actually built

Understanding the pipeline is a precondition for optimizing it, and several
surprises turned up.

**There is only one GLSL utility library in play, but three copies exist.**

| Copy | Location | Live? |
|---|---|---|
| GLSL shared library | `shaders/base/common.glsl` | **Yes** — included by all 114 `.frag` files |
| GLSL shared library (duplicate) | `GLSLWrapper::getPreamble()` in `src/platform/linux/GLSLWrapper.h:31-209` | **No** — only injected when a shader lacks `uniform Uniforms`; no current shader does |
| Metal shared library (duplicate set) | `shaders/base/utils.metal` + `shaders/base/common.metal` | Partly — see 2.2 |

Verified: `grep -rL 'common\.glsl' shaders --include='*.frag'` returns nothing.
All 114 shaders include `base/common.glsl` (93 as `"base/common.glsl"`, 21 as
`"../base/common.glsl"`). **`shaders/base/common.glsl` is therefore the single
highest-leverage file in the repository** — a change there applies to 100% of
the corpus.

**Shaders declare `#version 450 core` but compile as GLSL 330.**
`GLSLWrapper::loadShaderWithIncludes()` (`GLSLWrapper.h:291-294`) strips every
line containing `#version` during include expansion, and
`wrapFragmentShader()` then prepends `#version 330 core`. Consequences:

- Do not use 450-only features in any rewrite.
- **Precision qualifiers (`mediump`/`highp`) are no-ops in desktop GLSL 330.**
  Every "reduce precision for speed" recommendation is therefore a category
  error on this backend and is rejected throughout this document. The Metal
  backend is a separate question (see 2.5).
- The `#version 450 core` lines in the shaders and in `common.glsl:1` are
  misleading dead text.

**`centered` is already aspect-corrected.** `common.glsl:229-235` computes
`centered = uv * 2.0 - 1.0; centered.x *= resolution.x / resolution.y;`.
Nineteen shaders recompute exactly this from `uv`
(`vec2 p = uv * 2.0 - 1.0; float aspect = resolution.x / resolution.y; p.x *= aspect;`)
— a redundant divide plus a duplicated derivation that will silently drift if
the aspect policy ever changes.

**Metal delivery is a text prepend, not an include.**
`MetalRenderer.mm:1130-1158` reads `utils.metal`, prepends it to every shader,
appends `using namespace ShaderUtils;`, and then strips the shader's own
`#include "utils.metal"` (`:1188-1197`). Consequences:

- 65 shaders reference `ShaderUtils` without including `utils.metal`; they
  compile only via the prepend.
- The offline build path (`CMakeLists.txt:266-272`, `xcrun metal -c`) does
  **not** prepend, so with `ENABLE_OFFLINE_SHADER_COMPILATION=ON` those 65
  shaders fail to compile.
- `shaders/base/common.metal` is dead code that duplicates `utils.metal`,
  redefines `struct VertexIn` (already in `src/core/ShaderInterop.h:110-113`),
  and declares a second `fragment_main`. It would not compile if included.

### 2.2 Corpus statistics

Measured over `shaders/**/*.frag` + `shaders/base/common.glsl`:

| Metric | Count |
|---|---|
| `sin(` | 541 |
| `length(` | 367 |
| `cos(` | 190 |
| `normalize(` | 84 |
| `exp(` | 83 |
| `pow(` | 76 |
| `pow()` with a small integer exponent (convertible to a multiply chain) | 57 |
| `sqrt(` / `inversesqrt(` | 12 |
| Redundant `resolution.x / resolution.y` derivations | 37 |
| **Transcendental calls inside a loop** | **465 across 77 shaders** |
| Shaders reimplementing `rot2D`/`sdCircle`/`sdSegment`/`sdBox2D`/`fillSDF`/`rot` | 26 files, ~60 definitions |

Top shaders by loop-contained transcendental count:
`elves.frag` 46, `unicorn.frag` 23, `orcs.frag` 20, `dwarves.frag` 19,
`aquatic.frag` 19, `quantum_field.frag` 16, `classical.frag` 13,
`area_51.frag` 13, `mandelbulb_3d.frag` 12, `capman.frag` 12,
`reaction_diffusion.frag` 11.

**Measured per-frame cost** (`tests/full_bench.sh`, 1920x1080, all 114 shaders;
FPS is inversely proportional to cost, so the slow end is where effort pays):

| FPS | shader |
|---|---|
| 1.2 | `effects/nebula` |
| 4.4 | `audio/audio_ray_tracing` |
| 14.3 | `lissajous` |
| 34.9 | `effects/mandelbox` |
| 43.6 | `effects/mandelbrot_3d` |
| 46.9 | `effects/starfield_warp` |
| 47.2 | `effects/mandelbulb` |
| 54.2 | `effects/raymarch_sculpture` |
| 64.0 | `nebula` |
| 69.7 | `effects/mushroom` |
| 70.4 | `flying_toasters` |
| 75.3 | `orcs` |
| 75.5 | `effects/julia_4d` |
| 75.8 | `effects/julia_bulb` |

Note this ordering does **not** match the loop-transcendental count. The
ASCII/ray-march hero shaders sit at 130-350 FPS because their work is mostly
straight-line 2D SDF arithmetic, while the volume and escape-time shaders pay
per-sample simplex noise. Optimise by measured cost, not by static count.

### 2.3 Measurement methodology

`shadercandy-bench`'s first run for a shader includes pipeline warm-up and reads
roughly half steady-state FPS, so every number below is the **best of >= 2 runs**
at 1920x1080. Hardware: Intel Graphics (ADL GT2), Mesa 26.0.8, GL 4.6.

Three tools were added to make this reproducible:

- `tests/validate_shaders.sh` — reproduces the real include/version pipeline and
  compiles all 114 shaders with `glslc`. Currently **114/114 compile clean**.
  This is the gate that must stay green for every edit below.
- `tests/ab_compare.sh` — A/B benchmark of two shader trees, side by side.
- `tests/measure_shaders.sh` — single-tree FPS table.
- `tests/compare_frames.sh` — renders the same shader from two trees at a
  **pinned `time`** and reports the max per-channel pixel delta. This is how
  "no visual change" is proved rather than asserted.
  `ShaderBenchmark` gained a `-time <seconds>` flag for this: it otherwise
  feeds wall-clock elapsed time to the shader, so two runs of an animated
  shader can never match and every comparison looks like a regression.
- `tests/dedupe_shader_helpers.py`, `tests/use_centered.py` — the two codemods
  applied so far, both dry-run by default.

`docs/experiments.md` holds the raw measurement log.

### 2.4 What "assembler and SIMD" can and cannot mean here

This needs stating plainly, because it shapes every recommendation.

**You cannot write inline assembly.** Neither GLSL nor MSL exposes an
`asm` qualifier that reaches the GPU ISA. `glslc` emits SPIR-V; Metal emits
Metal IR; the vendor backend compiler emits the real ISA. Anything below that
layer is out of reach from shader source.

What *is* reachable, and what this document actually optimizes:

1. **Source-level SIMD** — expressing scalar work as `vec2`/`vec3`/`vec4`
   operations so the backend emits packed SIMD instructions. The clearest
   example: a mirrored pair `length(p - vec2(-a, b))` / `length(p - vec2(a, b))`
   collapses to one `length(vec2(abs(p.x) - a, p.y - b))`.
2. **Integer/PCG hashing** — replacing `fract(sin(x) * K)` with bit-mixing
   integer ops, which map to full-rate SIMD integer instructions instead of a
   quarter-rate transcendental. **Tested and rejected here; see 2.7.**
3. **Compiler directives** — `#pragma unroll` (Metal), `#pragma clang loop
   unroll_count(N)`, `[[unroll(N)]]`, integral loop counters to enable
   constant folding.
4. **Loop-invariant code motion (LICM)** — the single largest lever. Hoisting
   uniform-only transcendentals out of ray-march and particle loops is the
   bulk of the findings, and it is the one measured to be a large win.
5. **FMA / reciprocal-multiply** — `k / (1 + d*m)` becomes `k * rcp(...)`;
   `a*b + c` becomes an FMA.
6. **`fast::` math (Metal only)** — `metal::fast::sin/exp/rcp/sincos`, which map
   to `*.approx.f32` at full SIMD rate.
7. **CPU-side SIMD** — the audio analysis path and the particle integrator are
   ordinary C++ and can use SSE/AVX2/NEON directly.

**Cross-pixel SIMD is not available.** Escape-time fractals
(`mandelbrot.frag`, `julia.frag`) would classically be batched four pixels to a
SIMD register, but a fragment shader invocation owns exactly one pixel and has
no access to its neighbours' initial conditions. Do not attempt this. The
legitimate analogue is *intra*-invocation lane packing: quantities that one
iteration simultaneously produces and consumes (`zs`/`zi`/`dzx`/`dzy` in
`burning_ship.frag:14`) map directly onto lanes, and a loop-carried vector
derivative can be replaced by its scalar norm (`julia_4d.frag`, which is the
technique `julia_3d.frag:17-19` already uses correctly).

### 2.5 Measured results

**Accepted — ray-march LICM (`shaders/effects/mushroom.frag`).**

`map()` recomputed, on each of ~64 march steps plus 6 for the normal, three
`sin`/`cos` and a rotation matrix per mushroom — 8 mushrooms. Every one of those
values depends only on the uniform `time` and a compile-time loop index, so the
shader performed ~2,800 transcendental evaluations per pixel to recompute 40
numbers that cannot change within a frame.

| Variant | mushroom FPS | delta |
|---|---|---|
| A: original | 67.32 | — |
| B1: hoist into global arrays, keep `for` loop | 78.76 | **+17.0%** |
| B2: individually named globals, fully unrolled `map()` | 77.21 | +14.3% |

**B1 is adopted.** The gain comes entirely from the hoist; B2's extra effort to
eliminate dynamic indexing buys nothing measurable and costs readability.

**Rejected — integer/PCG hash replacing `fract(sin(n) * 43758.5453123)` inside
`noise()`.**

The folklore says `sin` is quarter-rate and therefore always worth replacing
with integer bit-mixing. Measured, it is not:

| Variant | starfield | galaxy |
|---|---|---|
| A: original (4x sin-hash per `noise()`) | 255.33 | 1063.12 |
| B: `noise()` via 4x `hash2()` | 222.59 | 799.81 |
| delta | **-12.8%** | **-24.8%** |

| Variant | starfield | galaxy |
|---|---|---|
| A: original | 253.53 | 1099.10 |
| B2: `noise()` via 2x `hash2()` | 232.04 | 850.73 |
| delta | **-8.5%** | **-22.6%** |

One `sin` + `fract` + `mul` is cheaper than `hash2`, which needs a `fract(vec3)`
(three floors), a `dot`, several swizzles and a second `fract` — roughly 20
dependent full-rate ops against one quarter-rate transcendental.
**Do not touch the hash functions.** Recorded so the idea is not re-attempted.

**Rejected — sin/cos angle addition for 3-channel palettes.**

`sin(A+1), sin(A+2), sin(A+3)` replaced by one `sin`/`cos` pair plus constant
offsets is algebraically correct and does cut transcendentals from 3 to 2. On
this hardware it measured **-13.0%** then **-7.5%** on `liquid_gradient.frag`,
because the three independent `sin` calls issue in parallel while the
`sincos` pair forms a dependency chain. The rewrite is retained only where it
unlocks a hoist (see 2.6.2); it is never applied on its own.

**Rejected — `pow(x, n)` to `exp2(n * log2(x))`.** `pow` *is* implemented as
`exp2(n * log2(x))` on essentially all GPUs. Zero win, always. Only small
integer exponents (2, 3, 4, 5) converted to multiply chains are real, and only
because they beat the `log2`+`exp2` pair; large exponents (8, 10, 12, 20, 25,
30, 32, 35) are *longer* as multiply chains than as one `pow`.

**Rejected — `pow(r,2)` -> `r*r` inside a chaotic iteration.**
`mandelbrot_3d.frag:27` computes `pow(r, 2.0)` and line 30 computes `r * r`.
These are algebraically identical and the replacement measured **+1.0%** — but
the frame comparison showed **241 of 518,400 pixels changing**, scattered
across the fractal body. In a chaotic iterate, a 1-ULP difference in one
squaring eventually flips an escape-time iteration count, and the palette is
driven by that count. Each pixel is individually invisible, but they are not
*identical*, so the change was **reverted** on the rule that an escape-time
count is part of a fractal's observable behaviour. The same reasoning does
**not** apply to `julia_bulb` and `mandelbulb_3d`, where the exponent is a
compile-time 7/8: the squaring chain moved no pixel at all and was kept.

**Rejected — precision reduction.** `mediump`/`highp` are no-ops in desktop
GLSL 330 (2.1), and on Metal the `half` conversion is unsafe for anything
feeding a sphere-tracing SDF, a gamma encode, or a `step()` threshold. No
precision change is recommended anywhere in this document.

### 2.5.1 The compiler already does most loop-invariant hoisting

A controlled probe (`/tmp/opencode/licmprobe`) settled a question that ran
through the whole analysis: **do these hoists actually need writing?**

Three paths computing **identical** results, differing only in where the
uniform-only values live — A: computed inside the scalar loop (the shape
almost every shader uses); B: hoisted into a **local array** before the loop;
C: hoisted into a **global array** before the loop. Each evaluates the same 32
`cos`/`sin`, 32 `hsv2rgb`, and 32 `length`.

| shape | FPS | vs A |
|---|---|---|
| A: inside the loop | 729.5 | - |
| B: local-array hoist | 739.8 | +1.4% (noise) |
| C: global-array hoist | 823.0 | **+12.8%** |

**A == B, so Mesa's GLSL compiler already performs loop-invariant code motion
for uniform expressions.** Rewriting a shader to hoist a scalar out of a loop
therefore buys nothing and only makes the source worse. **C is the one that
matters**: a namespace-scope array is lowered to memory, so the values are
written once and read per iteration instead of being re-derived through the
register allocator's dependence analysis.

Practical rules:

1. Do **not** rewrite shaders just to hoist a scalar out of a loop.
2. Do hoist into a **global array** when the values are read inside a loop that
   runs many times — ray-march steps, particle loops. That is what
   `mushroom.frag` does, and it is the only large measured win in this class.
3. The CPU-uniform-array recommendations in 2.6.1 (`uSparks[24]` etc.) are
   therefore **lower** priority than they first appear: a global `vec3 arr[24]`
   filled per fragment captures most of the benefit without touching the host
   uniform ABI. CPU tables remain worthwhile when the table is large enough
   that per-fragment setup is itself measurable, or when the host also drives
   the simulation.

This is why `audio_ray_tracing.frag` was **reverted**: hoisting its 3200
`hsv2rgb` calls per pixel measured **-1.1%**, because the compiler had already
done it. The same shader then gained **+96%** from a different, non-hoisting
change (2.6.4) - so "already optimized" applies to the hoist, not to the
loop body.

### 2.5.2 Two static counts in this document are wrong

Recorded so nobody re-derives them:

- **`effects/nebula` is divergence-bound, not work-bound.** The table above
  originally claimed 896 `snoise`/px. Instrumenting the shader to return its
  executed step count shows the **median pixel runs 3 of 64 steps** (mean
  5.6), because `col.a > 0.99` already exits early. Cost lives in the tail:
  8.1% of pixels above 16 steps carry 33.5% of the work, and 0.11% reach
  48+. Since a SIMD group runs in lockstep, one slow lane forces every lane in
  its group through all 64 iterations. **Lowering the step count is therefore
  the wrong fix** - it would clip the visible nebula while barely touching
  the pixels that dominate cost. The meaningful levers are fewer `snoise` per
  sample (the 3-octave domain warp is 9 of 14, so dropping it to 1 octave
  removes ~43% of per-sample cost) or restructuring the loop to remove the
  data-dependent exit. Both are visible changes.
- **Loop-contained transcendental counts understate cost.** `elves.frag`
  tops that list at 46 and runs at ~150 FPS, while `nebula` has few
  transcendentals and runs at 1.2. Optimize by measured cost
  (`tests/full_bench.sh`), never by static count.

### 2.6 Optimization opportunities, ranked

Impact labels are **measured** where stated, otherwise **analytical**
(a confident, statically-derived estimate) or **compiler-dependent** (whether
the driver already does it is not knowable without disassembly).

---

#### 2.6.1 Class A - LICM: hoist uniform-only math out of loops (largest lever)

Every finding in this class is the same bug: an expression that depends only on
`time`/`speed`/`intensity` and a loop counter, evaluated once per loop
iteration per pixel. This is the only class with a *measured* large win.

| Shader | Location | Uniform-only work | Est. impact |
|---|---|---|---|
| `effects/mushroom.frag` | `map()` 8-iteration loop | 3 `sin`/`cos` + 1 `rot()` per mushroom, ×70 `map()` calls | **MEASURED +17%** |
| `effects/nebula.frag` | **CORRECTED - see 2.5.2.** The "896 `snoise`/px" figure is wrong; the real cost is loop divergence, not sample count | reduce `snoise` per sample (visible) | HIGH but needs sign-off |
| `effects/dna_helix.frag` | `44-55`, `164-185` | `cos(twist+PI)`/`sin(twist+PI)` are exactly `-cos(twist)`/`-sin(twist)` (**bit-identical**, removes 4 transcendentals x ~106 `sdDNA` calls = ~424/px); 30-iteration particle loop is 90 uniform `sin` + 30 `hsv2rgb` | **VERY HIGH** |
| `lissajous.frag` | `35` inside a 200-iteration inner loop | `curveCol` depends only on the outer loop index — **3000 `cos`/px collapse to 15** | **VERY HIGH** |
| `audio/audio_ray_tracing.frag` | `43-44` inside a 100-iteration inner loop, itself inside 32 | `rayColor`/`freq` depend only on `fi` — **3200 `hsv2rgb`/px collapse to 32** | **VERY HIGH** |
| `effects/audio_wave.frag` | `33-41` | 64-iteration loop; `xPos`/`waveY1`/`waveY2` are 100% uniform — **128 `sin` + 64 divisions/px** | HIGH |
| `thunderstorm.frag` | `27-40` | 3 nested bolts x 20 steps of `hash(float)` = **60 `sin` + 60 `fract`/px**, all uniform | HIGH |
| `effects/quantum_crystalline.frag` | `21-33` | `0.2*t`/`0.3*t` are loop-invariant, `fi*0.3`/`fi*0.2` are compile-time constants — **24 `sin`/`cos` collapse to 4** | HIGH |
| `voronoi_cells.frag` | `7-11` | `sin(t*0.1 + i*132.3)`, `cos(t*0.15 + i*45.1)`: `i*k` is a compile-time constant, `t*k` is loop-invariant — **40 transcendentals collapse to 2** | HIGH |
| `reaction_diffusion.frag` | `26-40` | `pow(1.85, fi)` and `pow(1.4, fi)` are compile-time constants per iteration; `mat2(cos(angle),...)` with constant `i` and loop-invariant `t` — **10 `sin`/`cos` per `evaluateChemicals` call, which is made 3x per pixel** | HIGH |
| `effects/raymarch_sculpture.frag` | `19-42` | ~30 `sin`/`cos` + 5 rotation matrices per `map()` call, ~140 `map()` calls/px | HIGH |
| `effects/kifs.frag`, `effects/ifs_3d.frag` | `18-24`, `20-23` | `rot(t*0.2 + i*0.4)` recomputed every fold iteration of every march step — 24 transcendentals per `de()` call, ~80 calls/px | HIGH |
| `effects/mandebulb_3d.frag` | `15,17` | `pow(r,7)`/`pow(r,8)` share a base; integer exponent 8 is compile-time constant -> pure multiply chain, removes both `pow` per iteration | HIGH |
| `dragon/dwarves/orcs/unicorn` spark & firefly loops | see 2.6.7 | 24-32 iterations, each with 3-5 uniform transcendentals + a uniform `hsv2rgb`, evaluated for every pixel | HIGH |

Canonical rewrite (apply per site):

```glsl
// BEFORE — inside the loop, per pixel
vec3 pos = vec3(sin(fi*1.3 + t*0.5)*1.5, sin(fi*0.7 + t*0.3)*0.3, cos(fi*1.1 + t*0.4)*1.5);

// AFTER — once per fragment
vec3 mPos[8]; mat2 mRot[8]; float mScale[8];
void setup(float t) {
    for (int i = 0; i < 8; i++) { float fi = float(i);
        mPos[i] = vec3(sin(fi*1.3 + t*0.5)*1.5, sin(fi*0.7 + t*0.3)*0.3, cos(fi*1.1 + t*0.4)*1.5);
        mRot[i] = rot(t*(0.5 + fi*0.1) + fi); mScale[i] = 0.3 + fi*0.05; } }
```

For values that are *entirely* uniform, the strongest fix is a CPU-side
computation uploaded as a uniform array (`uSparks[24]`, `uWisps[6]`,
`uManeCol[7]`), which additionally removes the drift described in 2.7.3.

---

#### 2.6.2 Class B - Dead / redundant computation (CSE)

All exact, all zero-risk, all compiler-dependent in magnitude (a good driver
already CSEs most of these, but relying on that is fragile).

| Shader | Finding | Fix |
|---|---|---|
| `effects/prism_core.frag` | `hsv2rgb(vec3(fract(t*0.2), 0.8, 1.0))` computed **twice** | compute once, reuse |
| `prism_core.frag` | 6-iteration loop: `angle = i*PI/3 + t*0.5` — `i*PI/3` is a compile-time constant, so the six directions are the hexagon vertices | constant table |
| `reaction_diffusion.frag` | `lightDir = normalize(vec3(0.5,0.8,1.2))` and `halfDir` are compile-time constants | precompute |
| `effects/audio_bars.frag` | `abs(centered.x - x)` computed twice per iteration (lines 43 and 56); `centered.y - (...)` twice (44 and 57) | `vec2 d = abs(centered - vec2(x, -0.3 + barHeight*0.5));` |
| `frog.frag` | **four** identical `length(p)` (lines 42, 48, 58, 100) | `float rp = length(p);` once |
| `owl.frag` | `length(headP)` at 57 and 94; `length(eyeLP)`/`length(eyeRP)` at 66/67 and 104/105 — **6 redundant `sqrt` per owl x 3 owls** | hoist to `headR`, `eyeLR`, `eyeRR` |
| `art_deco.frag` | five `length(p)` (20, 29 x3, 59, 75) — the rotation preserves length, so all are the same value | compute once |
| `fireflies.frag` | `length(p - fireflyPos)` at 55 and 61, x20 iterations | reuse |
| `celtic.frag` | `sin(uv.x*6+t)*sin(uv.y*6)` at line 39 and again at line 76 with `knotUV == uv` | return both from `celticKnot` |
| `elves.frag` | `exp(a)*exp(b)` at 341-342 is exactly `exp(a+b)` — **4 `exp` become 2** | strength reduction |
| `elves.frag` | `length(p - lantP)` at 224 and 225 | hoist to `dLan` |
| `dwarves.frag` | `length(fPos)` at 104 and 109 | hoist to `fLen` |
| `orcs.frag` | `flarePulse` is 3 uniform `sin` (line 50); `lavaFlicker` is 2 uniform `sin` (123) | uniformize |
| `dwarves.frag` | `forgeFlicker = 0.85 + 0.15*sin(t*9)*cos(t*15)` (line 56) is uniform, used at 59/83/254 | uniformize |
| `dragon.frag` | `clamp((p.y - spikeBase.y)/0.34, 0, 1)` computed twice (241 and 243) | hoist |
| `effects/chrono_warp.frag` | `exp(-r*2.0)` is invariant across the 3-iteration loop | hoist |
| `effects/particles.frag` | `resolution.x / resolution.y` recomputed **inside** a 30-iteration loop (line 39) and again at 17; `length(toMouse)` + `normalize(toMouse)` + `/dist` is 3 high-latency ops | hoist `mPos`; use `toMouse * (0.05 / (dist*dot(toMouse,toMouse)))` |
| `mandala.frag` | `symP` at line 26 is assigned and **never read** — costs 1 `sin` + 1 `cos` per pixel | delete |
| `blackhole.frag` | `lensedP` at 35-36 is assigned and **never read** | delete |
| `egyptian.frag` | `pupil` at line 30 is computed but absent from the return at 43 | delete |
| `music/reggae.frag` | `bassWave` at line 74 assigned, never read | delete |
| `caps`/`capman.frag` | `sin(t + fi)` duplicated in `classical.frag:24,32` and `deep_ocean_pulse.frag:29,39` — **not** a real win, the driver CSEs it | no action |

---

#### 2.6.3 Class C - Hoist expensive work behind a cheap exact test

The strongest safe wins, because the gate is *provably* equivalent.

| Shader | Finding | Exactness argument |
|---|---|---|
| `unicorn.frag` `50-55` | Two 3-octave FBMs (6 `snoise`) computed for every pixel, then fully discarded below the hill by line 86 (`fillSDF` saturates to 1.0 for `p.y - hillY < -0.005`) | **Pixel-identical.** Hoist `hillY`, gate the FBMs on `p.y >= hillY - 0.005`. Skips 6 `snoise` for ~65% of pixels |
| `dragon.frag` `115` | 3-octave `fbm` (`capNoise`) computed for every inside-eye pixel, then **unconditionally overwritten** at line 147 when `r < irisRadius` | **Pixel-identical.** Move inside `if (r >= irisRadius)` |
| `elves.frag` `209` | 3 `snoise` for the canopy, whose branch at 211 is provably false for `p.y <= 0.10` (`canopyY <= 0.795`, so `canopyY - 0.22 <= 0.575`) | **Pixel-identical.** Gate on `p.y > 0.10` |
| `orcs.frag` `44-47` | 6 `snoise` for the ash sky, 90% overwritten by the ridge blend at line 60 | `smoke` gating on `p.y > -0.3` is exact (already multiplied by `clamp((p.y+0.3)*1.2,0,1)`). `smoke2` gating is a **mild visual change** (a red haze currently bleeds over the silhouette) — flagged as an improvement, not a free win |
| `ocean.frag` `41-42` | `wave()` costs 4 `sin` + 1 `sqrt` but `waves` is used only at line 63, inside `if (p.y < horizon)` | **Pixel-identical.** Move inside the branch. Saves 4 `sin` + 1 `sqrt` for ~50% of pixels |
| `dragon.frag` `238` | 5-iteration horn-spike loop, each a `sdSegment` (5 `sqrt`), runs for the whole screen though every spike occupies `p.y in [0.56, 1.02]` | **Pixel-identical.** `if (p.y > 0.50)` |
| `unicorn.frag` `241-246` | `atan` + 2 `cos` + 2 `pow` for a spike term scaled by `exp(-dTip*6)`, which is `< 1e-3` beyond `dTip ~ 1.0` | sub-LSB change. Gate on `dTip < 1.0` |
| `elves.frag` `167-170` | 4 unguarded `sqrt` + `exp` for lily petals; contribution is `< 1e-3` beyond `dPetal 0.2` | sub-LSB. Gate on `dPetal < 0.25` |
| `capman.frag` `454` | `stem1` (a `length` + `smoothstep`) computed for the whole bottom HUD band, consumed only inside the branch at 455 | **Pixel-identical.** Move inside |
| `capman.frag` `225-234` | corner fillets + neon evaluated when `d > 0.30`, but `lineMask`/`neonGlow` both evaluate to 0 there | skips 4 `isWall` (dynamically indexed array) + 4 `sqrt` + 1 `exp` |

---

#### 2.6.4 Class D - Bounding-volume early rejection

One AABB test replacing many SDF evaluations. All measured as "large fraction
of the frame falls outside", so the payoff scales with coverage.

| Shader | Guard | Replaced | Approx. rejection |
|---|---|---|---|
| `effects/mandelbox.frag` | `boundHit(ro, rd, 2.0)` | the entire 80-step march | **measured +303%** |
| `effects/mandelbrot_3d.frag` | `boundHit(ro, rd, 3.0)` | the entire 80-step march | **measured +65%** |
| `effects/kifs.frag` | `boundHit(ro, rd, 2.5)` | the entire 80-step march | measured +0.5% (noise) |
| `audio/audio_ray_tracing.frag` | squared-distance early-out | 3200 iterations -> only those that draw | **measured +96%** |
| `effects/starfield_warp.frag` | squared-distance early-out | 100 iterations -> only those that draw | **measured +16.6%** |
| `dwarves.frag` `136-266` | AABB on `dp` | ~19 SDF evaluations | ~90% |
| `orcs.frag` `149-244` | AABB on `op` | ~21 SDF evaluations | ~88% |
| `elves.frag` `236-329` | AABB on `ap` | ~16 SDF evaluations | ~85% |
| `unicorn.frag` `95-133` | AABB on `up` | 7 SDF evaluations | upper-right quadrant |
| `orcs.frag` `84-111` | `if (abs(p.x - hx) > 0.30) continue;` | 18 iterations -> ~4-5 | ~75% of iterations |
| `elves.frag` `363-377` | AABB + pre-`sqrt` reject — **applied**, pixel-identical | 14 `sqrt` | ~65% (measured +0.2%: the driver had already sunk the sqrt) |
| `elves.frag` `88-100` | AABB | 4 spire iterations | ~70% |
| `elves.frag` `349-360` | AABB | 6 wisp iterations | ~55% |
| `unicorn.frag` `145-169` | AABB + `uManeCol[7]` | 7 `sqrt` + 21 `cos` | ~90% |
| `ifs_3d.frag`, `raymarch_sculpture.frag` | ray-vs-bounding-sphere reject | the DE for background pixels | not yet measured |

**How to apply the ray-march rejection correctly.** Three things, all learned
by getting them wrong first:

1. **The march must still start at the ray origin.** Starting it at the
   sphere's entry point spends fewer steps of the fixed budget and changes
   which rays converge. The bound is a *rejection* test only.
2. **The "no hit" sentinel must reproduce the caller's actual behaviour.** In
   `mandelbox` the loop could exit on the step budget while still reporting
   `d < 15.0`, which the caller shaded as a hit — so `1e9` is the correct
   miss. In `julia_4d`/`julia_bulb` the DE escapes on the first iteration, so
   the real terminating value is `d ~ 1.0`; a large sentinel erases the
   fractal and a small one paints a halo.
3. **The radius must be measured per shader, and larger is not always
   worse.** `tests/bound_probe.sh` sweeps candidate radii and reports whether
   each is pixel-identical. For `mandelbrot_3d`, radius 2.0 gives only +9.8%
   while 3.0 gives +72.5%: the larger sphere catches rays that visually miss
   but whose distance estimator still under-reports, so they were being
   shaded as surface. Small radii clip the geometry; large ones (4.0+) let
   rays converge onto fold structure and change the image.

**Rejected on measurement: `julia_4d` (+0.5%) and `julia_bulb`.** Their DE
escapes on the first iteration, so there is no wasted budget to skip. Both
were reverted.

---

#### 2.6.5 Class E - Arithmetic strength reduction

**`pow(x, n)` with a small integer exponent -> multiply chain.** 57 sites.
Exponents 2, 3, 4, 5, 8, 10, 12, 16 are worth it; **20/25/30/32/35 are not**
(the chain is longer than one `pow`).

| Shader | Site | Rewrite |
|---|---|---|
| `mandebulb_3d.frag`, `julia_bulb.frag` | `pow(r,7)` + `pow(r,8)` | `r2=r*r; r4=r2*r2; zr=r4*r4; rp1=zr/r;` — **applied, +1.2% / +1.8%** |
| `mandebulb.frag`, `mandelbulb.metal:43,45` | `pow(r,power-1)` and `pow(r,power)` share a base (animated exponent, so a chain is impossible) | `rp1 = zr / r` halves the `pow` count — **applied, +2.3%** |
| `mandelbrot_3d.frag:27,30` | `pow(r,2.0)` and `r*r` on adjacent lines compute the same value | **REJECTED — see below** |
| `dwarves.frag` `255` | `pow(forgeLight, 1.5)` | `forgeLight * sqrt(forgeLight)` — exact, and `forgeLight >= 0` is already clamped |
| `voronoi_cells.frag` `16` | `pow(col, vec3(3.0))` | `col*col*col` |
| `effects/area_51.frag` | `pow(fract(sin(n+t)*43758.5453), 10.0)` | `x2*x4*x4` (5 muls) |
| `hearts.frag` `28` | `pow(x*x+y*y-1.0, 3.0)` with `x*x` already needed | `h*h*h` |
| `effects/event_horizon.frag`, `effects/hearts.frag` | `pow(noise(...), 15.0)` / `pow(..., 8.0)` | squaring chain |
| `dna_helix.frag` | `exp(-pow(uv.x+0.5+t*0.1, 2.0) * 20.0)` | `x*x` |
| `effects/hearts.frag` | `pow(max(dot(...),0.0), 32.0)` | 5 squarings |

**Division -> reciprocal-multiply.**

| Shader | Site | Note |
|---|---|---|
| `thunderstorm.frag` `28` | `i / steps` in a 20-step loop | `i * (1.0/20.0)` — 60 divides -> 60 muls |
| `thunderstorm.frag` `11` | `dot(pa,ba)/dot(ba,ba)` — `dot(ba,ba)` is pixel-invariant per segment | hoist the reciprocal |
| `forest.frag` `28` | `layerP.y / layerHeight`, `layerHeight` loop-constant | 24 divides -> 24 muls |
| `music/classical.frag` `48,53,62` | `noteP /= noteScale`, `noteScale` loop-constant | 36 divides -> 36 muls |
| `music/vaporwave.frag` `74` | `dot(toLeaf,toLeaf)` invariant over 5 iterations; `p - palmPos` appears twice on the line | hoist reciprocal + CSE |
| `lissajous.frag` `25`, `trigonometric.frag` `44`, `effects/audio_wave.frag` `37`, `audio_ray_tracing.frag` `43` | `j/200.0`, `fi/32.0` | constant reciprocal |
| `kaleidoscopic_tunnel.frag` `6,23` | `length(centered)` twice; `vec3 / length(centered)` is 3 divides | hoist to `lc`, use `0.2/lc` once |
| 37 sites | `resolution.x / resolution.y` | uniform; see 2.6.6 |
| `mandelbulb.frag` `108-113` | `t += h` where `h` can be 0 or negative -> **step stall** | `t += max(h, 0.01)` |

**Loop-counter hygiene.** `for (float i = 0.0; i < 5.0; i++)` blocks constant
folding and unrolling because `i*0.3` and `i*0.5` can never fold. Converting to
`for (int i = 0; i < 5; i++) { float fi = float(i); ... }` lets `sin(fi*2.8)`
become an immediate. Affects `starfield.frag:15`, `lissajous.frag:24`,
`trigonometric.frag:43`, `audio_ray_tracing.frag:18,26`, `psychedelic.frag:32`,
`mandala.frag:29`, `aquatic.frag` (6 sites), `owl.frag:15,43`,
`effects/particles.frag:25`, `effects/neon_pulse.frag:10`,
`effects/chrono_warp.frag:23`, all `music/*.frag`, and all
`sin(fi * k)` particle loops. **MEDIUM, compiler-dependent** — a driver that
fully unrolls a float loop already does this.

**Duplicate helpers -> `common.glsl`.** 26 files define a byte-identical
`mat2 rot(float)` (15 of which are never called); 5 files each define
`rot2D`, `sdCircle`, `sdSegment`, `fillSDF`; 3 each define `sdBox2D`,
`sdUnevenCapsule`; 3 Metal files define `sdEllipsoid`, `sdRoundBox`.
`common.glsl` has no 2-D `rot`/`sdCircle`/`sdSegment`/`fillSDF` at all — that
gap is what caused the duplication. Runtime impact is ~0 (the compiler inlines
each copy), but it means a single optimization must be applied 26 times and
has already drifted. **MEDIUM maintainability.**

---

#### 2.6.6 Class F - Use the already-computed `centered`

`common.glsl:229-235` hands `effect_main` a `centered` that is *already*
`uv*2-1` with the aspect applied. Nineteen shaders recompute it:

```
vec2 p = uv * 2.0 - 1.0;
float aspect = resolution.x / resolution.y;
p.x *= aspect;
```

Affected: `knights`, `thieves`, `frog`, `owl`, `aquatic`, `audio_ray_tracing`,
`music/{classical, electronic, heavymetal, hiphop, jazz, punk, reggae, soul,
vaporwave}`, `neural_style_blend`, `effects/{chrono_warp, deep_ocean_pulse,
liquid_aura, astra_fractal, vortex_dream, biolume_forest, cosmic_kaleido}`.

Fix: `vec2 p = centered;`. Removes a divide and a duplicated derivation.
**Excluded**: `music/8bit.frag` (derives `p` from a quantized coordinate),
`blackhole.frag` (derives from `lensedUV`, not `uv`).

---

#### 2.6.7 Class G - SIMD / vectorization (real, source-level)

These are the genuine "use SIMD instructions" items — each maps onto a packed
vector instruction instead of N scalar ones.

| Shader | Site | Win |
|---|---|---|
| `frog.frag` `70-96` | three mirrored pairs (`eyeLP`/`eyeRP`, pupils, legs). `eyeRP == vec2(-eyeLP.x, eyeLP.y)`, and `length` is invariant under `x -> -x` | `vec2 ep = vec2(abs(frogP.x) - 0.15, frogP.y - 0.18); float eyeR = length(ep) - 0.1;` — **6 `sqrt` -> 3**, and the `max(smoothstep(...), smoothstep(...))` pairs collapse entirely |
| `owl.frag` `60-67` | same mirrored pattern, x3 owls | `length(vec2(abs(owlP.x) - 0.1, owlP.y - 0.35))` — **6 `sqrt` -> 3** |
| `japanese.frag` `28-29` | torii posts `abs(p.x ± 0.3)` | `max(abs(p.x) - 0.04, abs(p.y) - 0.4)` — 4 `abs` + 2 `max` -> 2 + 1 |
| `capman.frag` `335-349` | six `length` on structurally identical left/right pairs | build both squared lengths into a `vec2`, issue **one** `sqrt(vec2)` — 6 `sqrt` -> 3 |
| `effects/psychedelic.frag` `32-36` | `q = p * s` with `s > 0`, so `atan(q.y,q.x) == atan(p.y,p.x)` and `length(q) == length(p)*s` — both already available at lines 19/24 | **5 `atan` -> 0, 5 `sqrt` -> 0** |
| `burning_ship.frag` `14` | `(zx, zy, dzx, dzy)` are simultaneously produced and consumed by one iteration | pack as a `vec4` — ~2x on the derivative half |
| `julia_4d.frag` `19,23,30` | `dz` is a quaternion used **only** via `dot(dz,dz)`; since `|a*b| = |a||b|`, `dzm2 *= 4.0*m2` replaces the whole chain | removes one full quaternion multiply per iteration (~40%); the inner loop drops from ~56 flops to ~14 |
| `julia_4d.frag`, `julia_3d.frag` `8-15` / `3-10` | `qMult(z, z)` is always a **square** | dedicated `qSq`: 16 muls + 12 adds -> 10 + 8 |
| `mandelbrot_3d.frag` `24-38` | exponent is exactly 2, so `sin(2t)`/`cos(2t)` come from the double-angle identity on already-cheap ratios, eliminating `acos` + `atan` | 2 transcendentals + 3 trig -> 1 `sqrt` + 4 divisions + 5 muls |
| `effects/astra_fractal.frag` `27-46` | 12 fold iterations on a `vec2` with an identical body | batch into `vec4` lanes: 3 passes instead of 12, branchless `mix`/`step` — **3-4x** |
| `effects/fluid_dynamics.frag` `53-61` | 3 noise octaves at geometrically increasing frequency | classic fBM-as-`vec4` formulation: 9 `snoise` -> ~4 |
| `dragon.frag` `25-28` | `hash22` uses 2 `sin`; `common.glsl:57` already provides a **sin-free** `hash2` with the same signature | delete `hash22`, call `hash2` |
| `retro_robot.frag` | duplicate `sin(t*10.0)` in both eye branches; `sin(t*2.0)` inside a branch | hoist |
| `waterfall.frag` `21-22` | `sin(p.y*2)` and `sin(p.y*2 + 2.0)` | one `sincos` pair |
| `galaxy.frag` `35,43,54` | `exp(-d*2)`, `exp(-d*3)`, `exp(-d*5)` are all integer multiples of `exp(-d)` | 3 `exp` -> 1 `exp` + 4 muls |
| `effects/quantum_field.frag` `52-58` | `for (float i = 0.0; i < 10.0; i++) momentum += sin(dot(uv, vec2(cos(i), sin(i))) * 10.0 + t)` — `cos(i)`,`sin(i)` are **compile-time constants** for `i = 0..9` | constant table; 20 transcendentals -> 0 |
| `effects/pastel_unicorns.frag` | `vec3 colors[8]` indexed by `int(i) % 8` — a **dynamically indexed local array** forces scratch memory | replace with a `const` table + select, or make the loop `int`-bounded so it unrolls |

**Not recommended despite looking vectorizable:** `thieves.frag:30` vs `:51`
(byte-identical hash but in **mutually exclusive branches** — only one `sin`
executes); `flying_toasters.frag:47` vs `:52` (the wing rotations are
mathematically different, so an `abs()` collapse is wrong); `forest.frag:59-61`
and `music/8bit.frag:26-28` (`|x+a| != |x-a|`; an `abs()` form returns the
**minimum** of the pair, which changes the visual).

---

#### 2.6.8 Class H - Branching

Convert divergent `if`/`?:` inside per-pixel or per-step loops to `mix`/`step`/
`min`/`max`. Desktop GL drivers already flatten many of these to predicated
selects, so impact is MEDIUM rather than HIGH, except in ray-march loops where
the branch encloses real work.

| Shader | Site |
|---|---|
| `effects/astra_fractal.frag` `20-31` | `sphereFold` — divergent `if/else if`, 12 iterations x 134 `map()` calls |
| `dna_helix.frag` `60-63` | inside a 100-step march |
| `mind_palace.metal` `37-61` | `appear` branch is uniform-dependent; hoist + branchless |
| `effects/biolume_forest.frag` `31,52` | `&&`-chained comparisons writing `color` inside 3- and 5-iteration loops |
| `effects/sierpinski.frag` `19-23` | rotation `if` inside a 12-iteration loop |
| `capman.frag` `219-222` | four sequential `if (!wall) d = min(d, ...)` — **LOW on desktop GL**; would matter if ported to GLES |
| colour-selection branches | `starfield.frag:38-42`, `byzantine.frag:67-74`, `music/reggae.frag:26-32`, `celtic.frag:42-46`, `alien_landscape.frag:68-70`, `owl.frag:89-96`, `japanese.frag:66-68`, `music/vaporwave.frag` (5 sites), `effects/audio_wave.frag:46-48` (trivial `max` accumulation) |

**Leave alone:** all DE bailout `break`s, all ray-march early-outs, spatially
coherent region branches (`ocean.frag:46`, `planet.frag:36`,
`alien_landscape.frag:76`), and uniform-derived branches
(`audio_spectrum.frag:57,171`, `thunderstorm.frag:60`, `classical.frag:60`).
Making these branchless is strictly slower.

---

#### 2.6.9 Class I - Structural / shared-library work

| Item | Detail |
|---|---|
| Delete the duplicate GLSL preamble | `GLSLWrapper::getPreamble()` carries a full second copy of the utility library that no current shader can reach. Either delete it or generate it from `common.glsl` so the two cannot drift |
| Delete `shaders/base/common.metal` | dead code duplicating `utils.metal`, with a duplicate `VertexIn` and a second `fragment_main` |
| Unify `mod` in `utils.metal` | `mod(float2,float2)` is `fmod` (truncated: sign of `x`) at `utils.metal:14-17`, while `common.metal:36-38` and Metal's builtin use the floored form. `elves.metal:98`, `orcs.metal:99`, `dwarves.metal:79`, `biolume_forest.metal:74,91,107` use the slow `fmod` inside 80-100-iteration marches; `mind_palace.metal:18` and `electronic.metal:15` get floored `mod` by accident. Same author, same intent, different results |
| `constant float PI` -> `constexpr` | `utils.metal:8-9`; and `MetalRenderer.mm:1161-1162` then `#define`s `PI` over the top, shadowing it with an unsuffixed literal |
| Add `#include "utils.metal"` to the 65 shaders that rely on the prepend | otherwise the offline CMake path cannot build them |
| Shared camera/ray basis | the identical 5-line block appears in 10 shaders (`mandelbox:78`, `julia_4d:65`, `julia_bulb:77`, `mandelbrot_3d:77`, `ifs_3d:56`, `kifs:71`, `raymarch_sculpture:109`, ...) — runtime 0, maintainability MEDIUM |
| Tetrahedron normal | 6-tap central difference -> 4 taps cuts `map()` evaluations by 33%. Present in ~15 ray-march shaders |
| Consistency fixes | `flying_toasters.metal` `rotateZ`/`rotateX` are the **transpose** of `utils.metal`'s `rotZ`/`rotX`; `mandelbrot_3d.frag:34-38` uses a different spherical convention than the other three bulb shaders |

---

#### 2.6.10 Class J - Metal SIMD specifics

Not measurable here (no Apple GPU). All are analytically standard and are
**gated on Apple-hardware validation** before landing.

| Item | Detail | Expected |
|---|---|---|
| `fast::` math family | **0 uses repo-wide.** Every `sin`/`cos`/`exp`/`pow`/`normalize`/`length`/`rsqrt` is the precise variant. `metal::fast::*` maps to `*.approx.f32` at full SIMD rate | 2-4x on transcendental-bound shaders |
| `fast::sincos` | systematic fix for the pervasive `cos(a)`/`sin(a)` duplication (e.g. `owl.metal:152-153`, `elves.metal:126-127`, `orcs.metal:134-135`, `dwarves.metal:102-103`, `retro_robot.metal:62`, `biolume_forest.metal:141`, `capman.metal:114`, `flying_toasters.metal:51-60`) | HIGH, and bit-identical for the `cos(-a)=cos(a)` cases |
| `fast::rcp` for `k/(1+d*m)` glow terms | 10 shaders x 80-128 iterations, 3 vector divides -> 1 rcp + 3 muls | 1.1-1.3x |
| `dna_helix.metal:48,50` | `cos(twist+PI)`/`sin(twist+PI)` -> `-cos(twist)`/`-sin(twist)`; **bit-identical**, ~212 transcendentals/px saved | HIGH |
| `hearts.metal` | 30 hearts x 4 transcendentals x ~86 `map()` calls = ~10,300/px, all recomputing 30 frame-invariant parameter tuples | HIGH |
| `nebula.metal` | 896 `snoise`/px; cut the 3-`fbm` warp to one vector warp, 5 octaves -> 4 | 2-3x |
| `half`/`half4` | **0 uses repo-wide.** Only colour-only blocks are safe; never SDFs, positions, gamma encodes, or `step()` thresholds | 1.1-1.6x |
| `audio_ray_tracing.metal:104,114` | `length(pos - listenerPosition) < 0.5` and `length(pos) > roomSize` are pure threshold tests | **bit-identical**, removes ~200 `sqrt`/thread |
| `audio_ray_tracing.metal:181-187` | `monoInput[idx]` loaded twice per iteration | trivial |
| `audio_ray_tracing.metal:152-157` | `O(N*M)` naive convolution | prefix-sum or overlap-add FFT: 10-100x |

**Do NOT use `fast::` on:** `pow(col, float3(0.4545))` gamma encodes
(visible banding in the dark end), anything feeding a `step()` threshold
(`area_51.metal:98`, `nebula.metal:44`, `pastel_unicorns.metal:93`,
`flying_toasters.metal:91`), or `length`/`normalize` **inside** an SDF used for
sphere tracing — `fast::` error (~2e-4) exceeds the `d < 0.001` hit epsilon.
`MTLCompileOptions.fastMathEnabled = YES` is therefore **rejected**: it would
rewrite the gamma encodes too.

---

#### 2.6.11 Class K - CPU-side (C++)

| File | Finding | Impact |
|---|---|---|
| `src/audio/AudioInput_Linux.cpp:157-205` | the magnitude `sqrt(re*re + im*im)` is computed **five times over the same data**: loops 1-3 cover `[0,halfSize)` once, loop 4 (8 bands) covers it **again**, loop 5 (spectrum, 64 bins) a **third** time. ~2x redundant, in `double`, with a `sqrt` | **HIGH** — compute `mag[]` once into a scratch buffer, then all five reductions read it. The reductions themselves then become vectorizable adds |
| same | `sumAbsArray` is already SIMD (`MathUtils.h`); the magnitude loop is not | MEDIUM |
| `src/platform/linux/GLShaderProgram.cpp:202-205` | `std::min(256, spectrum.size())` copies only **64** of the 256 UBO floats; `uniforms.audioData[64..255]` are **never written** and `uniforms` is not zero-initialised | **BUG** — 192 stale floats uploaded every frame. Contradicts Part 1 items 2/3. Fix: zero-fill, or make the spectrum match the UBO width |
| `src/core/ShaderManager.cpp:77-99` | `reloadShaders()` calls `fs::exists()` + `fs::last_write_time()` for **every** registered shader **every frame** when hot reload is on — ~230 syscalls/frame at 60 fps | **HIGH** — throttle to a poll interval (e.g. 500 ms); the mtime comparison makes sub-second granularity pointless |
| `src/gl/GLRenderer.cpp:878-891` | `checkForShaderReload()` copies a `std::string` per frame (heap allocation) and takes the mutex twice | LOW — return a `const std::string*` from the lock |
| `src/gl/GLRenderer.cpp:671-696` | `updateParticles()` is an AoS `std::vector<Particle>` loop. **PARTLY DONE**: `rand()` replaced with an inline xorshift32 (`rand()` takes the libc lock per call and `% n` is a biased modulo). Still AoS | LOW — convert to SoA so the integrator auto-vectorizes |
| `CMakeLists.txt:150-157` | `-mavx2 -mfma` is applied **unconditionally** on x86 with no runtime CPU feature detection — an illegal-instruction crash on pre-Haswell CPUs | **BUG** — gate on `__builtin_cpu_supports` or drop to `-msse4.2` baseline |
| `CMakeLists.txt:144-157` | `USE_NEON` / `USE_AVX2` are defined but **never referenced** in any source file | LOW — dead build configuration; `MathUtils.h` keys off these, so verify before removing |
| `src/tools/ShaderBenchmark.cpp` + `ShaderManager.cpp:29-32` | the benchmark's default `-dir` set omits `shaders/{music,audio,neural,system}`; `ShaderManager` omits the same directories from its scan paths | LOW — 22 shaders are invisible to both tools |

---

### 2.7 Bugs found during the audit

These are correctness issues discovered alongside the performance work. They are
listed here because several are prerequisites for trusting the optimizations.

1. **Stale audio uniforms** (`GLShaderProgram.cpp:202`) — 192 of the 256
   `audioData` floats are never written and never zeroed. Directly contradicts
   Part 1 items 2 and 3.
2. **CPU feature detection missing** (`CMakeLists.txt:150-157`) — `-mavx2`
   without a runtime check.
3. **Shading/SDF position divergence** — `elves.metal:212-216` vs `:116-120`
   drops the breathing term; `orcs.metal:212-216` vs `:124-128` drops the
   sway and stomp; `dwarves.metal:195-199` vs `:92-96` drops the hammering.
   Sharing one position table (2.6.1) makes this class impossible.
4. **Transposed rotation helpers** — `flying_toasters.metal:24,30` `rotateZ`/
   `rotateX` are the **transpose** (inverse) of `utils.metal`'s `rotZ`/`rotX`.
   Swapping them silently mirrors the model.
5. **`fmod` vs floored `mod`** — same author, same intent, different output
   (see 2.6.9).
6. **`mushroom.metal:174`** — `in.position.xyz` is clip space, used as world
   space; the scene has no perspective depth.
7. **`frog.metal:107`** — `dTotal == 0.0` float equality; and the 15.0 bound
   disagrees with the loop's 20.0 (works by accident).
8. **`audio_ray_tracing.metal:99`** — the loop variable `step` shadows
   `metal::step`.
9. **Inconsistent spherical convention** — `mandelbulb_3d.frag:13-14`,
   `mandelbulb.frag:41-42`, `julia_bulb.frag:25-26` vs
   `mandelbrot_3d.frag:24-25,34-38`. Confirm intent before centralizing.
10. **`julia_3d.frag:66`** — `max(0.1, dot(...))` clamps to a *minimum*, unlike
    `max(dot(...), 0.0)` in every sibling. Probably an argument swap.
11. **Offline Metal build cannot compile 65 shaders** — see 2.6.9.
12. **Dead code** (0 runtime cost, but misleading): `mandelbulb.frag:8-22`
    (`powBulb`), `mandelbox.frag:8-11` / `julia_bulb.frag:8-11` /
    `mandelbrot_3d.frag:8-11` (unused `rot`), 15 of 26 unused `rot` copies,
    `cellular.frag:48-69` (`gameOfLife`), `mind_palace.metal:82-98`
    (`staircaseSDF`), `dna_helix.metal:9-23` (`rotateAroundAxis`),
    `flying_toasters.metal:150` (unused `norm`), `dwarves.metal:192`,
    `retro_robot.metal:47`, `effects/audio_spectrum.frag:20-23`
    (`smoothStep` reimplementing the builtin, used inconsistently with it).

### 2.8 Longer-session rendering drift

`time` is an unbounded `float` uniform. After ~3 hours `time ~= 10800`, and
expressions like `fbm(vec3(uv * 2.0, t * 0.12), 3)` interpolate ~1296 into
simplex noise's third axis. `snoise` (`common.glsl:89-147`) hashes lattice
indices through `permute`/`mod289`, so the fractional part is lost and the
noise visibly freezes, bands, or steps.

Eight shaders feed a time-derived value into the noise Z axis: `dragon:124`,
`orcs:44,45`, `elves:209`, `unicorn:52,53`, `nebula`, `rain`, `thunderstorm`.

Fix: wrap the clock at a per-shader-safe period. All six hero shaders share
`float t = time * speed;` at one line, so this is one change per file. Note
`capman.frag` needs a period that is a multiple of both 22 (ghost cycle) and
134 (circuit length) — `29524.0 = 134 * 22 * 10` works. **No performance
impact; a long-session visual-correctness fix.**

### 2.9 Implementation plan and status

Every step is gated on `tests/validate_shaders.sh` (114/114 compile clean) and,
for GLSL changes, `tests/ab_compare.sh`.

**Phase 1 - cross-cutting, no visual change**

1. **DONE** - `common.glsl`: added `rot`, `rot2D`, `sdCircle`, `sdSegment`,
   `sdBox2D`, `sdUnevenCapsule`, `fillSDF`; removed **54 duplicate definitions
   across 33 files**. Applied by `tests/dedupe_shader_helpers.py` (dry-run by
   default, `--apply` to write; it only removes a body that matches
   `common.glsl` byte for byte).
2. **DONE** - replaced the redundant `uv*2-1` + aspect preamble with the
   already-correct `centered` parameter in **33 files** (more than the 19
   initially identified). Applied by `tests/use_centered.py`, which refuses to
   rewrite unless the three lines are contiguous, the variable is not assigned
   earlier, and `aspect` has no other use.
   *Verified: all 66 modified shaders render pixel-identical to `HEAD`*
   (`tests/compare_frames.sh`, pinned `-time`, max per-channel delta 0).
3. `shaders/base/common.glsl`: hoist the aspect ratio into a single
   `const float aspect = resolution.x / resolution.y;` — **now redundant**,
   since it is used exactly once in `main()`.
4. Apply the exact CSE and dead-code removals from 2.6.2.
5. Apply `pow` multiply chains and reciprocal-multiply from 2.6.5.
6. Apply the provably-exact gates from 2.6.3 and the AABB rejects from 2.6.4.

**Phase 2 - measured optimizations**

6. **DONE** - ray-march bounding-sphere rejection on `mandelbox` (+313%),
   `mandelbrot_3d` (+72.5%), `kifs` (+2.8%), with a shared `boundHit()`
   helper in `common.glsl`. Radius chosen per shader by measurement.
   `mandelbox` also got the 4-tap tetrahedral normal.
   `julia_4d` and `julia_bulb` were attempted and **reverted** — their DE
   escapes on the first iteration, so there is nothing to skip (+0.5%).
7. Per-shader global-array hoists for the remaining ray-march shaders
   (`mandelbulb`, `mandelbulb_3d`, `raymarch_sculpture`, `ifs_3d`) and the
   ASCII hero shaders, following 2.6.1 and **not** the scalar-hoisting advice
   that 2.5.1 disproved.
8. **DONE** - 4-tap tetrahedral normals in `mandelbox`, `mandelbulb_3d`,
   `kifs`, `mushroom`, `flying_toasters`, `julia_3d`, applied by
   `tests/tetra_normal.py`. Measured +4.2% to +10.1% (`kifs` neutral).
   **This is not pixel-identical and is not meant to be** - it is a different
   gradient estimator. Verified as quality-neutral rather than identical:
   detail energy (mean `|laplacian|` on lit pixels) is unchanged to within
   0.1%, the lit-pixel count rises slightly, and side-by-side renders are
   indistinguishable at 1:1.

**Phase 3 - CPU-side (done)**

8. **DONE** - fixed the stale-audio bug: `GLShaderProgram::updateUniforms`
   copied only `min(256, spectrum.size())` bins into a 256-float UBO array and
   left the tail holding the previous frame's values. The tail is now cleared,
   and the no-audio path clears the whole array.
9. **DONE** - audio magnitudes are computed once per FFT bin into a reused
   scratch buffer instead of five times over the same data (bass/mid/treble,
   then the 8 sub-bands, then the 64-entry spectrum).
10. **DONE** - `ShaderManager::reloadShaders()` is throttled to 500 ms. It
    previously ran `fs::exists()` + `fs::last_write_time()` for every
    registered shader on every frame.
11. **DONE** - `-mavx2 -mfma` is no longer applied unconditionally on x86. It
    now requires `-DSHADERCANDY_FORCE_AVX2=ON`, since the old setting raised
    SIGILL on pre-Haswell CPUs and there was no runtime check. The default is
    an SSE4.2 baseline.
12. **DONE** - `ShaderManager` now also scans `shaders/{audio,neural,system}`,
    which were previously invisible to it (22 shaders).
13. Regression tests added for the reload throttle and the audio-array width.
    Suite is **126 passed, 0 failed** (was 124).

Remaining on the CPU side: SoA the particle integrator (see 2.6.11).
**DONE** - replaced `rand()` in the particle respawn path with an inline
xorshift32. `rand()` takes the libc lock on every call and `rand() % n` is a
biased modulo.

**One change alters the image, deliberately.** `mandelbox`'s march could exit
on its 80-step budget while still reporting `d < 15.0`, which the caller
shaded as a surface hit. The result was that the shader's own background
branch was dead code and the frame was filled with speckle from non-converged
rays. The bounding-sphere rejection makes those rays miss properly, so the
fractal now renders against black as the shader always intended. Verified by
rendering both frames and inspecting them, not just by diffing numbers.

**Phase 4 - Metal (requires Apple hardware)**

11. `fast::` conversions, gated by the exclusions in 2.6.10.
12. LICM in the Metal ray-march shaders (the same bugs as the GLSL versions).
13. Delete `common.metal`, unify `mod`, fix the transposed rotation helpers.

### 2.10 Review policy for future shader work

Beyond Part 1 item 10, shader changes should be checked against:

- Is any loop-invariant or uniform-only math inside a per-pixel loop?
- Is any expensive expression computed outside the branch that consumes it?
- Is a group of expensive SDFs reachable without a bounding test?
- Are mirrored coordinates computed twice instead of once with `abs()`?
- Does a dynamic index into a local array force scratch memory?
- Does the change compile clean in `tests/validate_shaders.sh`, and is the
  benchmark delta measured rather than assumed?
- Was the optimization **measured** before being accepted? Two of the most
  plausible-looking optimizations in this document (PCG hashing, sin/cos angle
  addition) measured *slower* on real hardware.
---

## Part 3 - Verification: coverage, races, lint

Part 2 established that several optimizations measured faster and several
plausible ones measured slower. That discipline only holds up if the test
suite can actually detect a regression. Part 3 closes that gap.

Full detail lives in [`testing.md`](testing.md); this section records what
changed and why.

### 3.1 Six real data races

ThreadSanitizer found six data races that the test suite had been reporting
as passing. All are fixed; the current build reports zero.

| # | Location | Defect |
|---|----------|--------|
| 1 | `GLRenderer` file-watcher thread | Issued `glCreateShader` / `glCompileShader` / `glLinkProgram` from a thread that does not own the GL context, concurrently with `render()`. |
| 2 | `GLRenderer::checkForShaderReload()` | Read `currentShader_` outside `shaderMutex_` while `loadShader()` wrote it. |
| 3 | `GLRenderer::reloadCurrentShader()` | Held an iterator into `shaderPrograms_` across a compile and wrote through it afterwards; a concurrent `loadShader()` could rehash the map and dangle it. |
| 4 | `ShaderManager::reloadShaders()` | The 500 ms reload throttle read and wrote `lastReloadPoll_` unguarded. |
| 5 | `UniformBuffer::updateTime/updateResolution/updateMouse` | All writes to `data_` unsynchronised. |
| 6 | `UniformBuffer` accessors | `getData()` returned a live reference, unsynchronisable by construction. |

Two notes that matter more than the list.

**Race 1 was a crash, not a theoretical hazard.** GL commands submitted from a
thread without the context are undefined behaviour. The fix moves all GL work
onto the context-owning thread: the watcher sets an atomic `pendingReload_`,
and `render()` drains it. `checkForShaderReload()` is now a pure
stat-and-compare with no GL calls, which is also why it became testable.

**Race 4 was introduced by the Part 1 reload throttle.** The optimisation that
stopped ~230 `stat()` syscalls per frame added an unsynchronised timestamp.
The busy-poll and the race shipped in the same change - a reminder that a
performance fix needs the same scrutiny as a feature.

### 3.2 A test that was passing by accident

Making `UniformBuffer` thread-safe changed `getData()` to return a snapshot
by value. Two tests bound it to `const auto &`, which now dangles.

One of them (`testUniformBuffer`) had been reading a dead temporary and
asserting values that a *later* update was supposed to write. It passed
because the stack memory happened to still match. The test was rewritten to
snapshot after each stage, and `testUniformBufferSnapshotSemantics` pins the
by-value contract.

This is the failure mode Part 2's methodology warns about: a green test suite
is only evidence if the tests are actually asserting something.

### 3.3 Coverage: 93.71% to 95.43%

Measured with `tests/coverage.sh`, which drives every CLI entry point before
summarising gcov output.

| Stage | Coverage |
|-------|----------|
| Baseline | 93.71% |
| CLI entry points driven | 94.31% |
| `CoverageClosureTests` (7 targeted tests) | 94.86% |
| GLRenderer hot-reload + error paths, real GL context | 94.94% |
| `ShaderRegressionTests` tool detection | 95.43% |

100% line coverage is **not** claimed. The remaining 377 lines are syscall
failure modes (`ftok`, `shmget`, `shmat`, GL loader resolution), driver-
dependent GL paths, timing-dependent adaptive-quality loops, live ALSA device
enumeration branches, and helper code inside test files whose own tests skip.
Each is enumerated with its reason in
[`testing.md`](testing.md#coverage).

One of those fixes was a genuine defect rather than a coverage chore:
`ShaderRegressionTests` hardcoded `glslangValidator`, so on a machine with
only `glslc` installed the entire timing-and-comparison half of the suite
silently did nothing. It now detects either tool.

### 3.4 Lint

`.clang-tidy` enables `bugprone-*`, `performance-*`, `concurrency-*` and
`cert-*`. `tests/lint.sh` runs it against the build tree's compilation
database and is clean.

Every disabled check carries its reason in `.clang-tidy`. Two are worth
noting:

- `concurrency-mt-unsafe` is deliberately **left on**. Its single hit is
  `getenv`/`unsetenv` in a single-threaded test, which carries a scoped
  `NOLINT`. Disabling the check globally would have hidden the check for real
  threading mistakes.
- `CheckOptions` with `<check>.Check: false` does **not** disable a check.
  Checks are disabled by a leading `-` in the `Checks` field. The first
  draft of the config used the wrong form and silently changed nothing.

### 3.5 New verification tooling

| Tool | Purpose |
|------|---------|
| `tests/tsan.sh` | Build and run under ThreadSanitizer; fail on any race in `src/` or `tests/` |
| `tests/tsan.supp` | Suppress ALSA and Mesa/Gallium races |
| `tests/lint.sh` | clang-tidy gate over the compile database |
| `tests/coverage.sh` | Instrumented build, all entry points, gcov summary |
| `tests/summarize_coverage.py` | Parse gcov output, list uncovered line numbers |
| `tests/ConcurrencyTests.cpp` | Flag handoff, concurrent reload, concurrent uniform writes |
| `tests/CoverageClosureTests.cpp` | One test per named coverage gap |

### 3.6 Review policy, extended

Part 2 item 2.10 asked that shader work be measured. Add:

- Does the change touch code reached from more than one thread? Run
  `tests/tsan.sh`.
- Does it change a return type or a reference-vs-value contract? Every call
  site must be re-checked, including ones that only compiled because of
  lifetime extension.
- Did a test's *coverage* change, or only its assertion count? A test that
  silently stops executing is worse than a missing test.
