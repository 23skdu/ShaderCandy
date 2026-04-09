# Next Steps / Improvement Plan for ShaderCandy

## Completed Tasks ✅

All previously identified TODOs have been completed!

| Task | Status | Date |
|------|--------|------|
| 29 shader stubs → working GLSL | ✅ | 2026-04-09 |
| GLRenderer particle system | ✅ | 2026-04-09 |
| Wayland keyboard handlers | ✅ | 2026-04-09 |
| Audio waveform visualization | ✅ | 2026-04-09 |
| Screenshot capture hotkey | ✅ | 2026-04-09 |
| OSD notification system | ✅ | 2026-04-09 |
| Smooth shader transitions | ✅ | 2026-04-09 |

---

## New Feature Suggestions for Next Milestone

### P0 - High Priority

#### 1. Dynamic Shader Configuration
- **Description**: Allow runtime configuration of shader parameters
- **Impact**: Users can customize shader behavior without editing files
- **Files**: `src/config/`, shaders

#### 2. Preset Save/Load System
- **Description**: Save current shader, settings, and audio config as named presets
- **Impact**: Quick access to favorite configurations
- **Files**: `src/config/PresetManager.cpp`

#### 3. Multi-Display Support
- **Description**: Handle multiple monitors with independent or mirrored shaders
- **Impact**: Support multi-monitor setups
- **Files**: `src/platform/linux/screensaver.cpp`

### P1 - Medium Priority

#### 4. Shader Hot-Reload with File Watching
- **Description**: Auto-reload shaders when source files change
- **Impact**: Faster development workflow
- **Files**: `src/core/ShaderManager.cpp`, `screensaver.cpp`

#### 5. Audio Input Device Selection
- **Description**: UI for selecting audio input source
- **Impact**: Support USB microphones, multiple devices
- **Files**: `src/audio/`

#### 6. Frame Rate Cap Option
- **Description**: Configurable FPS limit (30/60/unlimited)
- **Impact**: Power saving on laptops
- **Files**: `src/gl/GLRenderer.cpp`

### P2 - Nice to Have

#### 7. Shader Chaining
- **Description**: Apply multiple shaders in sequence
- **Impact**: Combined effects
- **Files**: `src/core/ShaderManager.cpp`

#### 8. Time-of-Day Scheduling
- **Description**: Auto-change shaders based on time
- **Impact**: Morning/evening different themes
- **Files**: `src/config/`

#### 9. Recording/GIF Export
- **Description**: Record shader output to video
- **Impact**: Share shader animations
- **Files**: `screensaver.cpp`

#### 10. Mobile App Companion
- **Description**: iOS/Android app for remote control
- **Impact**: Control from phone
- **Files**: New mobile project

---

## Keyboard Controls

| Key | Action |
|-----|--------|
| Escape / Ctrl+Q | Quit |
| Right Arrow / Space / P | Next shader |
| Left Arrow / N | Previous shader |
| F12 / PrintScreen | Screenshot |

---

*Last updated: 2026-04-09*
*All tasks complete! Ready for new feature planning.*