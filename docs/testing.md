# Testing, Coverage, and Static Analysis

This document covers how ShaderCandy is verified: what the test suite
contains, how line coverage is measured, how races are detected, and how
clang-tidy is configured.

Related documents:

- [`nextsteps.md`](nextsteps.md) — the optimisation work that motivated the
  current race-hardening, and its measurements.
- [`experiments.md`](experiments.md) — raw measurement log (E1–E10).
- [`LinuxFeatures.md`](LinuxFeatures.md) — platform behaviour, including hot
  reload.

---

## Quick reference

| Task | Command | Gate |
|------|---------|------|
| Build and run all tests | `cmake --build build --target shadercandy-test && ./build/shadercandy-test` | 140 passed, 0 failed |
| Run one suite | `./build/shadercandy-test --run "Concurrency Tests"` | — |
| List suites | `./build/shadercandy-test --list` | — |
| Validate every shader | `tests/validate_shaders.sh` | 114 compiled, 0 failed |
| Lint | `tests/lint.sh` | no warnings |
| Coverage | `tests/coverage.sh` | see [Coverage](#coverage) |
| Race detection | `tests/tsan.sh` | 0 races in project code |

---

## Test suite

140 tests across 12 suites, all run by `ctest` or by invoking
`shadercandy-test` directly.

| Suite | Focus |
|-------|-------|
| Logic & Uniform Tests | Value semantics, colour conversion, easing |
| Math & SIMD Tests | Vec2/3/4, matrices, batch colour, round-trip accuracy |
| Core Functionality Tests | `UniformBuffer`, `PerformanceMonitor`, GLSL wrapper text |
| Shader Compilation Tests | Shader source compiles through the real include pipeline |
| Renderer Feature Tests | Dynamic resolution, thermal scaling, descriptor heaps, LoD |
| Coverage Expansion Tests | Broad branch coverage across the core libraries |
| Shader Regression Tests | Per-shader compile-time baseline (`glslc` or `glslangValidator`) |
| Shader Wrapper Tests | Preamble generation, ES/desktop variants, include expansion |
| Linux Platform & Audio Coverage Tests | IPC, ALSA paths, config, GLX, multi-display |
| Memory Leak & Cleanup Tests | GLRenderer shutdown/reinit, hot-reload detection, uniform reset |
| **Concurrency Tests** | Flag handoff, concurrent reload, concurrent uniform writes |
| **Coverage Closure Tests** | Each test targets one named coverage gap |

### Adding a test

1. Put the test in the suite that owns the domain, or create a new
   `tests/<Name>Tests.cpp`.
2. Register it with the `REGISTER_TEST_SUITE(<Name>)` macro.
3. On Linux, add an `#include "<Name>Tests.cpp"` to `tests/main.cpp` — the
   test binary is a **unity build**, so a new file is not picked up
   automatically.
4. Assert with `TEST_ASSERT(cond, "message")`. The message must be a string
   literal or a `std::string`; the macro stringifies it.
5. `TEST_ASSERT_EQUAL` uses `std::to_string` on both arguments, so it only
   works with arithmetic types. For strings, use `TEST_ASSERT(a == b, ...)`.

---

## Coverage

```bash
tests/coverage.sh
```

This configures an instrumented build in `build-coverage/`, runs the suite
through **every** command-line entry point (so argument parsing is covered
too), generates gcov output, and summarises it.

Pass `--no-build` to reuse an existing instrumented build.

### Current figure

| Metric | Value |
|--------|-------|
| Project line coverage | **95.43%** (7905 / 8282) |
| Files at 100% | 17 of 37 |
| Shaders compiling | 114 / 114 |
| Tests | 140 / 140 |

Coverage counts only `src/`, `tests/` and `tools/`. System headers pulled in
by the standard library are excluded — they are not ours to cover.

### What is not covered, and why

100% line coverage is not achievable on this platform without contriving
production code into testability. The remaining 377 lines break down as
follows.

**Syscall and driver failure modes.** These require an actual failure to
trigger, and cannot be provoked from a test without changing the code under
test:

| Location | Lines | Why |
|----------|-------|-----|
| `src/platform/linux/LinuxIPC.h` | 8 | `ftok` / `shmget` / `shmat` failure paths. Need a bad projection key or an exhausted shared-memory segment. |
| `src/platform/linux/GLLoader.h` | 2 | `glCreateProgram` failing to resolve from the driver. |
| `src/platform/linux/GLShaderProgram.cpp` | 1 | The "No AudioUniforms block" diagnostic for an internal shader. |
| `src/gl/GLRenderer.cpp` (tone-map compile failure) | 6 | Requires GL itself to fail to compile a fixed internal shader. |
| `src/core/UniformBuffer.cpp` | 4 | The `localtime_r` null branch. glibc's `localtime_r` only returns null for an unrepresentable `time_t`, which cannot be constructed portably. |

**Driver-dependent GL paths.** These are reachable in principle but behave
differently per driver. Notably the *link* failure path in `GLRenderer`:
Mesa happily links both a type-mismatched varying and a second unlocated
fragment output, so no reliably-failing program can be constructed. The
*compile* failure path is tested instead, and is deterministic.

**Adaptive-quality resolution scaling.** `GLRenderer`'s resolution
downscale/upscale loop needs sustained frame-time pressure to cross its
thresholds. It is timing-dependent, so a test would be flaky rather than
deterministic.

**Audio device paths.** `AudioInput_Linux` branches on live ALSA device
enumeration results, which differ per machine. The failure branches that use
deliberately nonexistent device names *are* covered.

**Test helper code.** Roughly 267 of the remaining lines live in test files
themselves — helper functions and assertion paths used only by tests that
are themselves skipped. Covering these means writing tests for tests, which
does not improve confidence in the shipped binary.

### Trajectory

| Stage | Coverage | Change |
|-------|----------|--------|
| Baseline | 93.71% | 126 tests |
| `main.cpp` / `TestFramework` CLI paths | 94.31% | drove every entry point from `coverage.sh` |
| `CoverageClosureTests` | 94.86% | 7 new tests for named gaps |
| GLRenderer hot-reload + error paths | 94.94% | real GL context, 4 outcomes + failures |
| `ShaderRegressionTests` tool detection | 95.43% | suite now runs with `glslc`, not just `glslangValidator` |

---

## Race detection

```bash
tests/tsan.sh
```

Builds with `-fsanitize=thread` and runs the full suite. `tests/tsan.supp`
suppresses races reported inside ALSA and Mesa's Gallium driver; both are
third-party and maintain their own threading.

Verification is deliberately blunt. Anything TSan points at in this
repository is a real defect:

```bash
TSAN_OPTIONS="suppressions=tests/tsan.supp" ./build-tsan/shadercandy-test \
  2>&1 | grep -E 'ShaderCandy/(src|tests)'
# expect no output
```

### Defects found and fixed

TSan found six data races that the tests themselves had reported as passing.
All six are fixed; the current build reports zero.

| # | Location | Defect |
|---|----------|--------|
| 1 | `GLRenderer` file-watcher thread | Issued `glCreateShader` / `glCompileShader` / `glLinkProgram` from a thread that does not own the GL context, concurrently with `render()` submitting draw calls. |
| 2 | `GLRenderer::checkForShaderReload()` | Read `currentShader_` outside `shaderMutex_` while `loadShader()` wrote it. |
| 3 | `GLRenderer::reloadCurrentShader()` | Held an iterator into `shaderPrograms_` across a compile and wrote through it afterwards; a concurrent `loadShader()` could rehash the map and dangle it. |
| 4 | `ShaderManager::reloadShaders()` | The 500 ms reload throttle read and wrote `lastReloadPoll_` unguarded. **Introduced by the throttle optimisation itself.** |
| 5 | `UniformBuffer::updateTime/updateResolution/updateMouse` | All writes to `data_` were unsynchronised. |
| 6 | `UniformBuffer` accessors | `getData()` returned a live reference, which cannot be made safe. |

Two of these deserve comment.

**#1 is the serious one.** OpenGL commands from a second thread, without a
shared context, are undefined behaviour and were a long-standing source of
crashes during hot reload. The fix moves all GL work onto the thread that
owns the context: the watcher thread only sets an atomic `pendingReload_`
flag, and `render()` drains it.

**#4 was introduced by our own optimisation work.** The reload throttle was
added to stop ~230 `stat()` syscalls per frame. TSan caught that the
throttle's own timestamp was unsynchronised. Both defects — the busy-poll and
the race — came from the same change.

### Consequence: `UniformBuffer::getData()` now returns by value

Making `UniformBuffer` thread-safe forced `getData()` to return a snapshot
rather than a reference. This is a **breaking API change**: binding the
result to `const auto &` now dangles.

```cpp
const auto &data = ub.getData();   // WRONG: dangles immediately
const auto data = ub.getData();    // right: an independent copy
```

Two existing tests bound it to a `const &`. One of them had been passing by
luck — it snapshotted *before* a later update and then read fields that
update was supposed to have written, succeeding only because the dead
temporary happened to still hold matching stack contents.
`testUniformBufferSnapshotSemantics` now pins the by-value contract so this
cannot regress silently.

---

## Static analysis

```bash
tests/lint.sh              # everything under src/, tests/, tools/
tests/lint.sh src/gl/GLRenderer.cpp   # specific files
```

Requires a configured build tree with a compilation database:

```bash
cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

`.clang-tidy` enables `bugprone-*`, `performance-*`, `concurrency-*` and
`cert-*`. Each disabled check is listed in that file with the reason it is
off; the goal is to catch real defects, not to restyle.

Two notes on how the configuration behaves:

- `CheckOptions` with `key: <check>.Check / value: false` **does not**
  disable a check. Checks are disabled by listing them with a leading `-` in
  the `Checks` field. The config uses the correct form.
- `concurrency-mt-unsafe` is deliberately **left enabled**. Its only hit is
  `getenv`/`unsetenv` in a single-threaded test, which carries a scoped
  `NOLINT` rather than disabling the check globally — so the check remains
  available for real threading mistakes.

The Homebrew clang used in this environment cannot see the Homebrew
libstdc++ headers, so every translation unit reports `'chrono' file not
found` for standard library includes. `tests/lint.sh` filters those out: they
are a toolchain packaging artifact, not defects.

---

## Shader validation

```bash
tests/validate_shaders.sh
```

Compiles all 114 `.frag` shaders with `glslc` through the same `#include`
resolution the renderer uses, so a shader that passes here is one the renderer
can load. **This must stay at 114/114** after any shader edit.

---

## Benchmarking and shader A/B comparison

These tools exist because whole-corpus before/after timing is worthless here
— a full-corpus sweep with only five shaders modified reported 72 shaders as
">3% changed", some by 20–30%, all of them pixel-identical.

| Tool | Purpose |
|------|---------|
| `tests/measure_shaders.sh` | Per-shader FPS on one tree |
| `tests/ab_compare.sh` | Interleaved A/B of two trees — **the only trustworthy timing comparison** |
| `tests/compare_frames.sh` | Pinned-time pixel diff between two trees |
| `tests/full_bench.sh` | Sweep the whole corpus (indicative only, see above) |
| `tests/bound_probe.sh` | Sweep bounding radii, report pixel identity per radius |

`ShaderBenchmark` requires `-time <seconds>` to pin animation time;
without it every animated shader looks like a regression.

See [`nextsteps.md`](nextsteps.md) for what these were used to establish.