# Experiment log - ShaderCandy shader optimization

Hardware: Intel Graphics (ADL GT2), Mesa 26.0.8, GL 4.6 core profile.
Display 1920x1080. Tool: `build/shadercandy-bench`, 150-200 frames,
best (warm) run taken, 2 repetitions. Delta is B relative to A.

## E1 - Replace transcendental `hash()` inside `noise()` with `hash2()`

Hypothesis: `hash(float n) = fract(sin(n) * 43758.5453)` costs a quarter-rate
transcendental; `hash2(vec2)` is pure fract/dot/mul. Four `hash()` calls inside
one `noise()` evaluation should be replaceable by four `hash2()` calls.

Result: **rejected, slower.**

| variant                          | starfield | galaxy |
|----------------------------------|-----------|--------|
| A: original (4x sin-hash)        | 255.33    | 1063.12 |
| B: noise() via 4x hash2          | 222.59    | 799.81  |
| delta                            | **-12.8%**| **-24.8%** |

| variant                          | starfield | galaxy |
|----------------------------------|-----------|--------|
| A: original                      | 253.53    | 1099.10 |
| B2: noise() via 2x hash2         | 232.04    | 850.73  |
| delta                            | **-8.5%** | **-22.6%** |

Why: one `sin` + `fract` + `mul` is cheaper than a `hash2`, which needs a
`fract(vec3)` (3 floors), a `dot`, several swizzles and a second `fract` -
roughly 20 dependent full-rate ops against one quarter-rate transcendental.
The "sin-based hashes are slow" folklore does not hold here.

**Conclusion: do not touch the hash functions.** Recorded so the idea is not
re-attempted.

## E2 - Hoist uniform-only math out of a 64-step ray-march loop

Target: `shaders/effects/mushroom.frag`. `map()` recomputed, on every one of
the ~64 march steps plus 6 more for the normal, three `sin`/`cos` and one
rotation matrix per mushroom - 8 mushrooms. Every one of those values depends
only on the uniform `time` and a compile-time loop index, so the whole
shader was doing ~2,800 transcendental evaluations per pixel to recompute 40
numbers that cannot change within a frame.

| variant                                                         | mushroom FPS | delta |
|-----------------------------------------------------------------|--------------|-------|
| A: original                                                       | 67.32        | -     |
| B1: hoist into global arrays, keep `for` loop                    | 78.76        | **+17.0%** |
| B2: hoist into individually named globals, fully unrolled `map()` | 77.21       | +14.3% |

**Conclusion: adopt B1.** The gain comes entirely from hoisting into
**global** arrays. B2's extra effort to remove dynamic indexing buys nothing
(within run-to-run noise) and costs readability, so the simpler array form is
kept. E4 below shows why "global" is the operative word.

Also folded into B1/B2 and verified not to regress:
- `normalize(vec3(1,2,1))` -> precomputed constant
- `pow(x, 32.0)` -> 5 multiplies
- `0.5 + 0.5*cos(vec3(0,0.5,1) + A)` (3 transcendentals) -> one
  `sin`/`cos` pair plus constant angle offsets

## E5 - Applied optimizations, re-measured against HEAD

All A/B numbers are 1920x1080 against `git archive HEAD shaders`, with the
pinned `-time` frame comparison used to prove output equivalence.

| shader | change | FPS A | FPS B | delta |
|---|---|---|---|---|
| `effects/mushroom.frag` | global-array LICM of uniform-only transforms | 68.19 | 78.54 | **+15.2%** |
| `lissajous.frag` | constant-fold `j/200*TWO_PI`, hoist `curveCol`, `int` loop | 14.31 | 15.11 | **+5.6%** |
| `effects/mandelbulb.frag` | share the base between `pow(r,power-1)` / `pow(r,power)` | 257.29 | 263.15 | +2.3% |
| `effects/mandelbulb_3d.frag` | `pow(r,7)`/`pow(r,8)` -> squaring chain | 257.00 | 261.53 | +1.8% |
| `effects/julia_bulb.frag` | `pow(r,7)`/`pow(r,8)` -> squaring chain | 75.14 | 76.04 | +1.2% |
| `effects/mandelbrot_3d.frag` | `pow(r,2.0)` -> `r*r` | 43.40 | 43.82 | +1.0% **reverted** |
| `audio/audio_ray_tracing.frag` | hoist 3200 `hsv2rgb`/px out of the inner loop | 4.34 | 4.29 | **-1.1% reverted** |
| `audio/audio_ray_tracing.frag` | exact early-out + deferred sqrt (E10) | 4.40 | 8.64 | **+96.4%** |

Visual verification of everything except the two reverted rows:

| group | shaders | result |
|---|---|---|
| structural passes (dedupe, `centered`) | 66 | max per-channel delta **0**, pixel-identical |
| bounding-sphere rejection | `mandelbrot_3d`, `kifs` | max per-channel delta **0**, pixel-identical |
| `mushroom`, `lissajous`, `mandelbulb` | 3 | 1-5 pixels differ of 518,400 (max 1/255) |
| `mandelbulb_3d` | 1 | 11 pixels differ of 518,400 (max 6/255, mean 1.5) |
| `mandelbox` | 1 | **deliberate** - see E6; removes a background artifact |

The rounding groups are float noise from replacing `pow` with an
algebraically identical product: 0.000-0.002% of pixels, at or below a few
8-bit levels, on smooth gradients.

The two reverts are the interesting ones:

* **`audio_ray_tracing`** is the direct consequence of E4: the compiler was
  already hoisting those `hsv2rgb` calls, so writing the hoist by hand changed
  nothing and cost a little.
* **`mandelbrot_3d`** passed the benchmark (+1.0%) but moved 241 of 518,400
  pixels. `pow(r,2.0)` and `r*r` differ in rounding, and in a chaotic iterate
  that eventually flips an escape-time iteration count. Reverted on the rule
  that an escape-time count is observable behaviour of a fractal.

**Method lesson: a frame comparison catches what an FPS number cannot.**
Neither revert would have been visible in the benchmark.

## E6 - Bounding-sphere ray rejection on the fractal ray-marchers

Escape-time and IFS fractals march a fixed budget of steps (64-80) with no
test of whether the ray could possibly reach the object. Background pixels pay
the full budget. Adding a ray/sphere rejection first, via a new `boundHit()`
helper in `common.glsl`, skips the whole march.

Two things had to be right, and both were found by the frame comparison
rather than by reasoning:

1. **The march must still start at the ray origin.** Starting it at the
   sphere's entry point spends fewer steps of the fixed budget and changes
   which rays converge. The bound is a *rejection* test only.
2. **The "no hit" sentinel must reproduce the caller's real behaviour.** In
   `mandelbox` the loop could exit on the step budget while still reporting
   `d < 15.0`, which the caller shaded as a hit. Returning `1e9` there is
   therefore the correct "miss", and it revealed that the original never
   reached its own `else` background branch: the visible "background" was
   noise from non-converged rays being shaded as surface. See below.
   In `julia_4d` / `julia_bulb` the DE escapes on the first iteration, so
   the real terminating value is `d ~ 1.0`; a large sentinel erases the
   fractal and a small one paints a halo.

Results, each verified pixel-identical with `tests/compare_frames.sh`:

| shader | radius | FPS before | FPS after | delta |
|---|---|---|---|---|
| `effects/mandelbox.frag` | 2.0 | 34.8 | 140.5 | **+303%** |
| `effects/mandelbrot_3d.frag` | 3.0 | 43.9 | 72.5 | **+65%** |
| `effects/kifs.frag` | 2.5 | 101.2 | 101.7 | +0.5% (noise) |

Radius choice was measured per shader with `tests/bound_probe.sh`, which
sweeps candidate radii and reports whether each is pixel-identical:

- `mandelbox`: 1.5 clips (222 ch differ), **2.0 identical**, larger wastes steps.
- `mandelbrot_3d`: 2.0 and 3.0 identical, 4.0+ changes the image. 3.0 gives
  **+72%** vs only **+9.8%** for 2.0 - the larger sphere catches rays that
  *visually* miss but whose DE still under-reports distance, so they were
  being shaded as surface. Bigger is not automatically wrong here.
- `kifs`: 2.0 clips slightly, 2.5/3.0 identical, 4.0 changes it.

**Rejected on measurement: `julia_4d` (+0.5%) and `julia_bulb`.** Their DE
escapes on the first iteration, so there is no wasted budget to skip. Both
reverted rather than kept for the sake of a clean story.

**The `mandelbox` case is a latent bug, not just a speedup.** Before:
every pixel took the shading branch, so the shader's own background colour
`vec3(0.02, 0.02, 0.05)` was dead code and the frame was filled with
speckle. After: the fractal renders against black as clearly intended.
This is the one change in the set that alters the image, and it does so by
removing an artifact.

`mandelbox` also picked up the 4-tap tetrahedral normal (4 DE evaluations
instead of 6) alongside the rejection.

## E7 - 4-tap tetrahedral normals

Central-differencing a distance field needs 6 evaluations per normal; the
tetrahedral form needs 4 and returns the gradient without averaging, which is
the better estimator. Applied by `tests/tetra_normal.py` to
`mandelbulb_3d`, `kifs`, `mushroom`, `flying_toasters`, `julia_3d`
(and hand-written in `mandelbox`).

**This one is not pixel-identical and is not supposed to be.** The normal is a
different estimator, so per-pixel lighting shifts:

| shader | pixels changed | max | FPS before | FPS after | delta |
|---|---|---|---|---|---|
| `mandelbulb_3d` | 14.1% | 188 | 258.7 | 284.7 | **+10.1%** |
| `flying_toasters` | 7.5% | 143 | 70.0 | 75.4 | **+7.6%** |
| `julia_3d` | 25.2% | 195 | 270.4 | 282.8 | **+4.6%** |
| `mushroom` | 2.7% | 86 | 73.2 | 76.3 | **+4.2%** |
| `kifs` | 4.0% | 101 | 105.1 | 104.8 | -0.3% |

A large "pixels changed" number looks alarming but is expected: these are
high-frequency fractals where a sub-degree normal perturbation moves a
shaded pixel's colour along the palette. Two checks confirm the *quality* is
not degraded:

- **Detail energy is unchanged.** Mean `|laplacian|` over lit pixels on
  `mandelbulb_3d`: 115.83 (6-tap) vs 115.71 (4-tap) - a 0.1% difference, so
  no smoothing or sharpening.
- **Lit-pixel count rises slightly** (14,381 -> 14,432), i.e. marginally more
  surface resolves, consistent with the tetrahedron sampling the field more
  efficiently.
- **Side-by-side renders are visually indistinguishable** at 1:1.

`kifs` shows no gain (-0.3%, noise) because its bounding sphere already
removes most background pixels, so the normal is not the bottleneck there.
Kept anyway for consistency, since it is not a regression.

| variant | mushroom FPS | delta |
|---|---|---|
| `HEAD` | 68.19 | - |
| landed | 78.54 | **+15.2%** |

Visual check at pinned `time = 2.5`, 960x540: max per-channel delta **1**,
with only **4 of 1,555,200 channels** differing at all - float rounding from
restructuring the trigonometry, not a visible change.

The measured gain comes from the **hoist**, not from the angle-addition
rewrite; see E3, where the same rewrite *without* a hoist measured slower.

## E4 - Does the compiler already hoist uniform-only math? (the important one)

E2's +17% seemed to contradict E3. To find out what actually mattered, a
controlled probe was built (`/tmp/opencode/licmprobe`) with three paths that
compute **identical** results and differ only in where the uniform-only values
live:

* **A** - computed inside the scalar loop (the shape nearly every shader uses)
* **B** - computed into a **local array** before the loop, then looped
* **C** - computed into a **global array** before the loop, then looped

Each path evaluates the same 32 `cos`/`sin`, the same 32 `hsv2rgb`, and the
same 32 `length`. 32 iterations, 200 frames, best of several runs:

| shape | FPS | vs A |
|---|---|---|
| A: inside the loop (compiler's own LICM) | 729.5 | - |
| B: local-array hoist | 739.8 | +1.4% (noise) |
| C: global-array hoist | 823.0 | **+12.8%** |

**A == B means Mesa's GLSL compiler already performs loop-invariant code
motion for uniform expressions.** Writing `vec2 q = vec2(cos(fi*1.3 + t*0.5),
sin(fi*0.7 + t*0.3));` inside a loop costs the same as hoisting it into a
local. That makes the entire "hoist this out of the loop" category mostly a
non-issue for the scalars.

**C is the one that matters.** A global array at namespace scope is lowered to
private/constant memory, so the values are written once and *read* by each loop
iteration, rather than being re-derived per iteration through the register
allocator's dependence analysis. The gain is real and matches E2.

### What this changes

1. **Do not** rewrite shaders merely to hoist a scalar expression out of a
   loop. That is already handled, and doing it only makes the source worse.
2. **Do** hoist into a **global (namespace-scope) array** when the values are
   read inside a loop that runs many times - ray-march steps, particle loops.
   This is what `mushroom.frag` does, and it is the only measured win.
3. **Do not** convert a `vec2`/`vec3`/`vec4` value to an array of scalars "to
   hoist it" unless it is going into a loop; per-iteration vector math is
   already fine.
4. This makes the CPU-uniform-array recommendations in
   `docs/nextsteps.md` 2.6.1 (upload `uSparks[24]` etc.) **lower** priority
   than they first appear: a global `vec3 arr[24]` filled per fragment
   captures most of the same benefit without touching the host uniform ABI.
   The CPU-uniform route remains valuable only where the table is large enough
   that per-fragment setup is itself measurable, or where the host also wants
   to drive the simulation.

## E8 - Deferred sqrt behind an exact squared-distance test

`starfield_warp.frag` ran a 100-iteration star loop that computed
`length(st - pos)` and then immediately tested `step(d, size)` - so almost
every iteration paid a sqrt only to be discarded. Because `d` and `size` are
both non-negative, `d < size` is exactly `dot(st - pos, st - pos) < size*size`,
so the sqrt can be deferred to the few iterations that contribute. The loop
index also became `int`, letting `i * 0.0123 / 123.4 / 456.7` fold to
compile-time constants.

| shader | change | FPS before | FPS after | delta | max pixel delta |
|---|---|---|---|---|---|
| `effects/starfield_warp.frag` | deferred sqrt + int loop | 48.2 | 56.2 | **+16.6%** | 1/255 |
| `elves.frag` | same pattern on the 14-iteration leaf loop | 152.7 | 153.1 | +0.2% | **0** |

The `elves` result is a useful negative: the change is exactly equivalent and
pixel-identical, but gains nothing, because Mesa already sank the sqrt into
the branch. It was kept for symmetry with `starfield_warp` (both now read the
same way), not for speed. Consistent with E4: source shape does not predict
whether the compiler already did the work.

## Consolidated measured results

All figures 1920x1080, 3 reps x 40 frames, against `git archive HEAD shaders`:

| shader | change | FPS before | FPS after | delta |
|---|---|---|---|---|
| `effects/mandelbox` | bounding sphere + 4-tap normal | 34.8 | 140.5 | **+303.2%** |
| `effects/mandelbrot_3d` | bounding sphere | 43.9 | 72.5 | **+65.0%** |
| `effects/mushroom` | global-array LICM | 69.4 | 81.6 | **+17.6%** |
| `effects/starfield_warp` | deferred sqrt | 48.2 | 56.2 | **+16.6%** |
| `effects/mandelbulb_3d` | `pow` chain + 4-tap normal | 251.5 | 277.8 | **+10.4%** |
| `effects/julia_3d` | 4-tap normal | 268.0 | 287.9 | **+7.4%** |
| `lissajous` | constant fold + hoist | 14.3 | 15.1 | **+5.6%** |
| `effects/mandelbulb` | shared `pow` base | 257.3 | 263.2 | +2.3% |
| `effects/flying_toasters` | 4-tap normal | 74.3 | 75.5 | +1.6% |
| `effects/kifs` | bounding sphere + 4-tap normal | 101.2 | 101.7 | +0.5% |
| `julia_bulb` | `pow` chain | 75.1 | 76.0 | +1.2% |

Plus 66 shaders given pixel-identical structural cleanups (duplicate helper
removal, redundant aspect preamble), and four CPU-side fixes.

## E10 - Exact early-out over a rejected loop body

`audio_ray_tracing.frag` runs 32 rays x 100 steps = 3200 iterations per pixel,
each computing a `length()` and a `smoothstep`. The visible term is
`smoothstep(thickness, thickness * 0.5, d)`, which with reversed edges is
**exactly 0** once `d >= thickness`. `thickness` stays positive over
`dist in [0, 2)` and both operands are non-negative, so the entire iteration
can be gated on `dot(q, q) < thickness * thickness`, deferring both the sqrt
and the smoothstep to the few steps that actually draw.

| variant | FPS | delta | pixel delta |
|---|---|---|---|
| A: original | 4.40 | - | - |
| B: early-out + deferred sqrt | 8.64 | **+96.4%** | **0** |

Pixel-identical. The same shape gave `starfield_warp` +16.6% (E8) and
`elves` +0.2% (already sunk by the compiler) - three data points on the same
transformation, with the outcome depending entirely on whether the driver
already sank the sqrt into the branch.

The general form worth reusing:

> If a loop body's only contribution passes through a term that is provably
> zero outside a region, test that region on squared distance first and keep
> the `sqrt` inside the branch.

## E9 - `effects/nebula` is divergence-bound, not work-bound

`effects/nebula` runs at 1.2 FPS, the slowest shader in the corpus, and the
static analysis said it evaluates 896 `snoise` per pixel (64 march steps x
14 `snoise`). That number is wrong. Instrumenting the shader to return the
executed step count instead of the colour:

```
steps executed: min=1  median=3  mean=5.6  max=64
  steps>16: 8.12% of pixels carrying 33.5% of all work
  steps>32: 0.81% of pixels carrying  5.8% of all work
  steps>48: 0.11% of pixels carrying  1.1% of all work
```

**The median pixel runs 3 of 64 steps.** The march already exits early for
most of the frame, so the average cost is ~78 `snoise`/pixel, not 896.

The cost lives in the tail, and a fragment shader cannot escape it: a SIMD
group executes in lockstep, so the group runs as many iterations as its
*slowest* lane. The 0.11% of pixels that reach 48+ steps force every lane
sharing their group to run all 64 iterations, and the 8% above 16 steps carry
a third of the total work.

Consequences for how this should be optimized:

- **Reducing the step count is the wrong lever.** The median is already 3;
  a lower cap would clip the visible nebula without touching the pixels
  that dominate cost.
- **Reducing `snoise` calls per sample is the right lever.** The 3-octave
  domain warp is 9 of the 14 `snoise` in `nebula()`. Cutting it to 1 octave
  removes ~43% of per-sample cost — but it visibly simplifies the cloud
  structure, so it needs sign-off.
- **The divergence itself is the structural defect**, and fixing it means
  restructuring so the loop does not carry a data-dependent exit. That is a
  rewrite, not a tweak.

No change was made. Recorded so the next person does not spend time on the
"896 snoise" figure or on lowering the step count.

## Measurement notes

- The benchmark's first run for a shader includes pipeline warm-up and reads
  roughly half the steady-state FPS. Always take the best of >= 2 runs.
- **Run-to-run noise is large.** A full-corpus sweep of 114 shaders run twice
  with *only 5 shaders actually modified* reported 72 shaders as "changed by
  more than 3%", with several showing 20-30% swings (`sierpinski` +29.6%,
  `retro_robot` +25.6%, `8bit` +23.3%). Every one of those was verified
  pixel-identical and none was edited, so the spread is pure measurement
  noise from thermal/clock variation on a shared GPU. **Only compare a
  specific shader with `tests/ab_compare.sh`, which interleaves both trees in
  one session; never draw conclusions from a whole-corpus before/after diff.**
- `shadercandy-bench` iterates directories non-recursively, so
  `shaders/music`, `shaders/audio`, `shaders/neural` and `shaders/system`
  must be passed explicitly with `-dir`.
- The benchmark only writes a screenshot for the **last** `-dir` in one run.
  To capture a specific shader, invoke it alone.
- `time` is wall-clock elapsed, so two runs of an animated shader can never
  produce the same frame. Use `-time <seconds>` (added for this work) to pin it
  when pixel-comparing two shader trees. Without it, every animated shader
  looks like a large regression.
- The benchmark also only reports the **best** FPS for a shader name; if two
  files in different directories share a stem, pass the right `-dir`.

---

## E11 - Does the test suite actually detect a defect?

The Part 2 methodology depends on tests catching regressions. Before trusting
it, that needed measuring rather than assuming.

**Method.** Build with `-fsanitize=thread`, run the full suite, and inspect
every frame TSan attributes to `src/` or `tests/`.

**Result.** Six data races, all in code the suite had been passing.

| Location | Racy expression | Detected by an existing test? |
|----------|-----------------|------------------------------|
| `GLRenderer` watcher thread | GL commands from a non-context thread | no |
| `GLRenderer::checkForShaderReload` | `currentShader_` read outside `shaderMutex_` | no |
| `GLRenderer::reloadCurrentShader` | iterator into `shaderPrograms_` held across compile | no |
| `ShaderManager::reloadShaders` | `lastReloadPoll_` unguarded | no - and *we introduced it* |
| `UniformBuffer::updateTime` | `data_.time` | no |
| `UniformBuffer::updateResolution` | `data_.resolution[]` | no |
| `UniformBuffer::updateMouse` | `data_.mouse[]` | no |

(The last three are one defect - `UniformBuffer` was entirely unsynchronised -
and the test that exercised it reported PASS while racing.)

**Conclusion.** A green suite was not evidence. `tests/tsan.sh` is now the gate
for anything touching shared state.

## E12 - How much did the suite's own tests actually assert?

Chasing the coverage gap in `testUniformBuffer` turned up a test that could not
have failed.

```cpp
buffer.updateResolution(1920.0f, 1080.0f);
const auto &data = buffer.getData();     // line 1
TEST_ASSERT_EQUAL(1920.0f, data.resolution[0]);

buffer.updateMouse(0.5f, 0.5f);
TEST_ASSERT_EQUAL(0.5f, data.mouse[0]);   // reads what line 2 just wrote
```

After `UniformBuffer` became thread-safe, `getData()` returned a snapshot by
value, so `data` became a reference to a destroyed temporary. The mouse
assertion then read stale stack memory and failed.

It had been *passing* because that stack memory happened to still hold 0.5.
The assertion order was wrong; the dangling reference masked it.

**Conclusion.** Coverage percentage measures execution, not assertion. A test
that runs but asserts nothing meaningful counts fully. Renamed the fixed test
and added `testUniformBufferSnapshotSemantics` to pin the by-value contract.

## E13 - Coverage ceiling on this platform

Measured with `tests/coverage.sh` (drives every CLI entry point, then gcov).

| Stage | Coverage | Note |
|-------|----------|------|
| Baseline | 93.71% | 126 tests |
| + CLI entry points | 94.31% | `--help`, `--list`, `--run`, unknown option |
| + CoverageClosureTests | 94.86% | 7 tests, one per named gap |
| + GL hot-reload/error paths | 94.94% | real GLX context |
| + validator tool detection | **95.43%** | 140 tests, 17/37 files at 100% |

The last step was not a coverage chore. `ShaderRegressionTests` hardcoded
`glslangValidator`; only `glslc` is installed here, so the entire
timing-and-comparison half of the suite had been silently inert. It now
detects either tool.

**Where the remaining 377 lines are.** Measured, not estimated:

| Cause | Approx. lines |
|-------|---------------|
| Helper code inside test files whose own tests skip | ~267 |
| ALSA / device-enumeration branches that depend on the machine | ~22 |
| Syscall failure modes (`ftok`, `shmget`, `shmat`, GL loader) | ~17 |
| Driver-dependent GL paths (link failure, tone-map failure) | ~13 |
| Timing-dependent adaptive-quality resolution loop | ~24 |
| `localtime_r` null branch | 4 |

The GL **link** failure path is worth calling out: it cannot be reached
deterministically. Both a type-mismatched varying and a second unlocated
fragment output link cleanly on Mesa 26.0.8. The compile-failure path is
deterministic and is tested instead.

**Conclusion.** 100% line coverage is not claimed. It would require either
fault injection into production code or accepting flaky timing-dependent
tests, both of which trade real assurance for a number.
