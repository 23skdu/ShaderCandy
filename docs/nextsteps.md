# Next Steps / Improvement Plan for ShaderCandy

## Code Analysis Summary (2026-04-09)

### Incomplete/Stubbed Code Identified

| Category | Location | Issue | Priority |
|----------|----------|-------|----------|
| Shader Stubs | 29 shader `.frag` files | All converted ✅ | HIGH |
| Particle System | `src/gl/GLRenderer.cpp` | Implemented ✅ | MEDIUM |
| Wayland Callbacks | `src/platform/linux/wayland_screensaver.cpp` | Implemented ✅ | LOW |

---

## Completed Tasks (2026-04-09)

| Task | Status | Date |
|------|--------|------|
| 29 shader stubs → working GLSL | ✅ Complete | 2026-04-09 |
| GLRenderer particle system | ✅ Complete | 2026-04-09 |
| Wayland keyboard event handlers | ✅ Complete | 2026-04-09 |
| ShaderManager factory function | ✅ Complete | 2026-04-05 |
| ConfigurationManager metadata parsing | ✅ Complete | 2026-04-05 |
| MetalRenderer placeholder cleanup | ✅ Complete | 2026-04-05 |
| 14 shader conversions (base category) | ✅ Complete | 2026-04-05 |

---

## Implementation Details

### Particle System (GLRenderer.cpp:375-448)
- Full particle simulation with configurable count, gravity, and speed
- Point-based rendering with dynamic VBO updates
- Particle lifecycle management (spawn, update, respawn)

### Wayland Keyboard Handlers (wayland_screensaver.cpp:351-420)
- Keymap handling for XKB layout support
- Modifier tracking (Ctrl, Shift, etc.)
- Extended key bindings:
  - Escape / Ctrl+Q: Exit
  - Space / P / N: Next/Previous shader

---

## Next Actions

- [ ] Implement audio waveform visualization shader
- [ ] Add shader hot-reload notification UI
- [ ] Add screenshot capture hotkey
- [ ] Implement smooth shader transitions

---

*Last updated: 2026-04-09*
*All identified TODOs have been addressed!*