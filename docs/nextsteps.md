# Next Steps / Improvement Plan for ShaderCandy

## Code Analysis Summary (2026-04-09)

### Incomplete/Stubbed Code Identified

| Category | Location | Issue | Priority |
|----------|----------|-------|----------|
| Shader Stubs | 29 shader `.frag` files | `// TODO: Implement shader logic here` - missing GLSL implementations | HIGH |
| Particle System | `src/gl/GLRenderer.cpp:375-379` | Empty stub implementations | MEDIUM |
| Wayland Callbacks | `src/platform/linux/wayland_screensaver.cpp:351-381` | Empty keyboard event handlers | LOW |

---

## Prioritized Task List

### P0 - Critical (Blocking Features)

#### 1. Shader Implementation Stubs (HIGH - 29 files remaining)
- **Location**: 
  - `shaders/effects/*.frag` (20 files)
  - `shaders/*.frag` (9 files)
- **Issue**: 29 shader .frag files contain placeholder comment `// TODO: Implement shader logic here`
- **Already Completed**: 14 shaders converted (classical, reggae, owl, thieves, unicorn, orcs, frog, knights, elves, dragon, dwarves, aquatic, neural/neural_style_blend, audio/audio_ray_tracing)
- **Action**: Implement actual shader logic using working Metal shaders as reference

**Remaining shader stubs**:
1. `shaders/effects/area_51.frag`
2. `shaders/effects/astra_fractal.frag`
3. `shaders/effects/biolume_forest.frag`
4. `shaders/effects/calibration.frag`
5. `shaders/effects/chrono_warp.frag`
6. `shaders/effects/cosmic_kaleido.frag`
7. `shaders/effects/deep_ocean_pulse.frag`
8. `shaders/effects/event_horizon.frag`
9. `shaders/effects/fallout.frag`
10. `shaders/effects/hearts.frag`
11. `shaders/effects/liquid_aura.frag`
12. `shaders/effects/mind_palace.frag`
13. `shaders/effects/neural_nexus.frag`
14. `shaders/effects/particles.frag`
15. `shaders/effects/prism_core.frag`
16. `shaders/effects/quantum_crystalline.frag`
17. `shaders/effects/retro_robot.frag`
18. `shaders/effects/starship_hud.frag`
19. `shaders/effects/vortex_dream.frag`
20. `shaders/aquatic.frag`
21. `shaders/dragon.frag`
22. `shaders/dwarves.frag`
23. `shaders/elves.frag`
24. `shaders/frog.frag`
25. `shaders/knights.frag`
26. `shaders/orcs.frag`
27. `shaders/thieves.frag`
28. `shaders/unicorn.frag`
29. `shaders/owl.frag`

### P1 - Important (Missing Functionality)

#### 2. GLRenderer Particle System
- **Location**: `src/gl/GLRenderer.cpp:375-379`
- **Issue**: Three empty stub methods:
  - `setParticlesEnabled(bool enabled)` - line 375
  - `setParticleCount(int count)` - line 377
  - `setParticleGravity(float gravity)` - line 379
- **Action**: Implement particle system functionality or remove unused methods

#### 3. Wayland Keyboard Event Handlers
- **Location**: `src/platform/linux/wayland_screensaver.cpp:351-381`
- **Issue**: Empty stub implementations:
  - `handleKeyboardKeymap()` - line 351
  - `handleKeyboardEnter()` - line 353
  - `handleKeyboardLeave()` - line 356
  - `handleKeyboardModifiers()` - line 376
- **Action**: Implement keyboard event handling or remove unused callbacks

---

## Completed Tasks

| Task | Status | Date |
|------|--------|------|
| ShaderManager factory function | ✅ Complete | 2026-04-05 |
| ConfigurationManager metadata parsing | ✅ Complete | 2026-04-05 |
| MetalRenderer placeholder cleanup | ✅ Complete | 2026-04-05 |
| 14 shader conversions (base category) | ✅ Complete | 2026-04-05 |

---

## Quick Wins - Low Effort

| Task | Effort | Impact |
|------|--------|--------|
| Implement 3-5 more GLSL shaders from Metal | 1hr each | Visual output |
| Implement GLRenderer particle system | 2hr | Feature parity |
| Fill in Wayland keyboard callbacks | 1hr | Input support |

---

## Detailed Implementation Plans

### Task 1: Shader Stubs → Real Implementations

**Strategy**: Use working Metal shaders as reference
- Each `.frag` file has corresponding `.metal` with working raymarching/3D code
- Convert 3D raymarching to 2D pattern-based effects for GLSL
- Use established patterns from working shaders like `plasma.frag`, `audio_spectrum.frag`

**Working GLSL shaders to reference**:
- `shaders/effects/plasma.frag` - sin waves, color cycling
- `shaders/effects/audio_spectrum.frag` - audio-reactive 
- `shaders/effects/audio_circular.frag` - audio circular patterns

### Task 2: GLRenderer Particle System

**Approach**: Implement actual particle rendering using GL_POINTS or compute shaders
- Store particle state (position, velocity, lifetime, color)
- Update particles each frame based on gravity
- Render with point sprites or instanced geometry

---

## Next Actions

- [ ] Convert remaining 29 shader stubs to working GLSL
- [ ] Implement GLRenderer particle system
- [ ] Fill in Wayland keyboard event handlers

---

*Last updated: 2026-04-09*