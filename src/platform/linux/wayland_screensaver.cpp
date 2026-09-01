// Linux Wayland Screensaver for ShaderCandy
// Supports sway, GNOME, KDE Plasma, and other wlroots-based compositors

#ifdef __linux__
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES3/gl3.h>
#include <GLES3/gl3ext.h>
#include <wayland-client.h>
#include <wayland-egl.h>
#endif
#include "GLSLWrapper.h"
#include "LinuxStubs.h"
#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdlib>
#include <cstring>
#include <dirent.h>
#include <iostream>
#include <sys/stat.h>
#include <unistd.h>
#include <sys/mman.h>
#include <thread>
#include <time.h>

using namespace ShaderCandy::Platform::Linux;

// Try to include wlroots, but make it optional
#ifdef WLR_FOUND
#include <wlr/backend.h>
#include <wlr/backend/session.h>
#include <wlr/render/allocator.h>
#include <wlr/render/wlr_renderer.h>
#include <wlr/types/wlr_input_device.h>
#include <wlr/types/wlr_keyboard.h>
#include <wlr/types/wlr_layer_shell_v1.h>
#include <wlr/types/wlr_output.h>
#include <wlr/types/wlr_pointer.h>
#include <wlr/types/wlr_xdg_shell.h>
#include <wlr/util/log.h>
#endif

// Audio support
#include "../../audio/AudioInput.h"
#include "../../config/ConfigurationManager.h"
using namespace ShaderCandy::Audio;

// Forward declarations
struct GLShaderProgram;

// Shader hot-reload functionality
void checkForShaderChanges();

// Uniforms matching ShaderInterop.h
struct Uniforms {
  float time;
  float speed;
  float resolution[2];
  float mouse[2];
  float mouseButtons;
  float intensity;
  float date[4];
  int frame;
  float deltaTime;
  float alpha;
  float gravity;
  float volume;
  float bass;
  float mid;
  float treble;
  float beat;
  float audioData[256];
  float gpuTime;
  float cpuTime;
  float fps;
};

// Shader program with OpenGL ES support
class GLESShaderProgram {
public:
   GLuint program = 0;
   GLuint vertexShader = 0;
   GLuint fragmentShader = 0;
   GLuint ubo = 0;
   
   // Store original sources for reloading
   std::string vertexSourceStr;
   std::string fragmentSourceStr;
   
   Uniforms uniforms;
   int frameCount = 0;
   std::chrono::steady_clock::time_point startTime;
   std::chrono::steady_clock::time_point lastFrame;
   std::string name;

  ~GLESShaderProgram() { cleanup(); }

  void cleanup() {
    if (program) {
      glDeleteProgram(program);
      program = 0;
    }
    if (vertexShader) {
      glDeleteShader(vertexShader);
      vertexShader = 0;
    }
    if (fragmentShader) {
      glDeleteShader(fragmentShader);
      fragmentShader = 0;
    }
    if (ubo) {
      glDeleteBuffers(1, &ubo);
      ubo = 0;
    }
  }

   bool loadShader(const char *vertexSource, const char *fragmentSource) {
     // Store sources for potential reload
     vertexSourceStr = vertexSource ? std::string(vertexSource) : "";
     fragmentSourceStr = fragmentSource ? std::string(fragmentSource) : "";
     
     vertexShader = compileShader(GL_VERTEX_SHADER, vertexSource);
     if (!vertexShader)
       return false;

     fragmentShader = compileShader(GL_FRAGMENT_SHADER, fragmentSource);
     if (!fragmentShader) {
       glDeleteShader(vertexShader);
       vertexShader = 0;
       return false;
     }

     program = glCreateProgram();
     glAttachShader(program, vertexShader);
     glAttachShader(program, fragmentShader);
     glLinkProgram(program);

     GLint success;
     glGetProgramiv(program, GL_LINK_STATUS, &success);
     if (!success) {
       char infoLog[512];
       glGetProgramInfoLog(program, 512, nullptr, infoLog);
       std::cerr << "Shader link error: " << infoLog << std::endl;
       cleanup();
       return false;
     }

     glGenBuffers(1, &ubo);
     glBindBuffer(GL_UNIFORM_BUFFER, ubo);
     glBufferData(GL_UNIFORM_BUFFER, sizeof(Uniforms), nullptr, GL_DYNAMIC_DRAW);

     GLuint blockIndex = glGetUniformBlockIndex(program, "Uniforms");
     if (blockIndex != GL_INVALID_INDEX) {
       glUniformBlockBinding(program, blockIndex, 0);
     }

     uniforms.speed = 1.0f;
     uniforms.intensity = 1.0f;
     uniforms.alpha = 1.0f;
     uniforms.gravity = 1.0f;
     uniforms.mouseButtons = 0.0f;

     startTime = std::chrono::steady_clock::now();
     lastFrame = startTime;

     return true;
   }
   
   // Reload shader from stored sources
   bool reload() {
     if (vertexSourceStr.empty() || fragmentSourceStr.empty()) {
       std::cerr << "Cannot reload shader: source not available" << std::endl;
       return false;
     }
     
     // Clean up old shader
     cleanup();
     
     // Reload with stored sources
     return loadShader(vertexSourceStr.c_str(), fragmentSourceStr.c_str());
   }

  std::string loadShaderWithIncludes(const char *path, int depth = 0) {
    if (depth > 10)
      return "";

    std::ifstream file(path);
    if (!file.is_open())
      return "";

    std::string dir = path;
    size_t lastSlash = dir.find_last_of("/\\");
    if (lastSlash != std::string::npos) {
      dir = dir.substr(0, lastSlash + 1);
    } else {
      dir = "./";
    }

    std::stringstream buffer;
    std::string line;
    while (std::getline(file, line)) {
      if (line.find("#include \"") == 0) {
        size_t start = 10;
        size_t end = line.find("\"", start);
        if (end != std::string::npos) {
          std::string includeFile = line.substr(start, end - start);
          std::string includePath = dir + includeFile;
          std::string included =
              loadShaderWithIncludes(includePath.c_str(), depth + 1);
          buffer << included << "\n";
        }
      } else {
        buffer << line << "\n";
      }
    }

    return buffer.str();
  }

  bool loadFromFile(const char *path) {
    std::string vertPath = std::string(path) + ".vert";
    std::string fragPath = std::string(path) + ".frag";

    // Try loading as single file first
    std::ifstream testSingle(path);
    if (testSingle.is_open()) {
      testSingle.close();
      return loadSingleFile(path);
    }

    // Try .vert and .frag pair
    std::string vertSrc = loadShaderWithIncludes(vertPath.c_str());
    std::string fragSrc = loadShaderWithIncludes(fragPath.c_str());

    if (vertSrc.empty() || fragSrc.empty()) {
      std::cerr << "Failed to load shader files: " << path << std::endl;
      return false;
    }

    return loadShader(vertSrc.c_str(), fragSrc.c_str());
  }

  bool loadSingleFile(const char *path) {
    std::ifstream file(path);
    if (!file.is_open())
      return false;

    std::stringstream buffer;
    buffer << file.rdbuf();
    std::string source = buffer.str();

    // Add vertex shader wrapper if not present
    std::string vertSource;
    std::string fragSource;

    if (source.find("#version") != std::string::npos) {
      // Single file with both shaders separated
      size_t vertEnd = source.find("#ifdef FRAGMENT");
      if (vertEnd != std::string::npos) {
        vertSource = source.substr(0, vertEnd);
        size_t fragStart = source.find("#ifdef FRAGMENT");
        fragStart = source.find("\n", fragStart) + 1;
        size_t fragEnd = source.find("#endif", fragStart);
        fragSource = source.substr(fragStart, fragEnd - fragStart);
      } else {
        fragSource = GLSLWrapper::getPreamble(true) + source;
        vertSource = GLSLWrapper::getVertexShader(true);
      }

      return loadShader(vertSource.c_str(), fragSource.c_str());
    }

    // If no #version directive, wrap the whole file as fragment shader
    fragSource = GLSLWrapper::getPreamble(true) + source;
    vertSource = GLSLWrapper::getVertexShader(true);
    return loadShader(vertSource.c_str(), fragSource.c_str());
  }

  void update(float deltaTime, int width, int height, float mouseX,
              float mouseY) {
    auto now = std::chrono::steady_clock::now();
    auto elapsed = std::chrono::duration<float>(now - startTime).count();
    auto frameDelta = std::chrono::duration<float>(now - lastFrame).count();

    uniforms.time = elapsed;
    uniforms.deltaTime = frameDelta;
    uniforms.resolution[0] = (float)width;
    uniforms.resolution[1] = (float)height;
    uniforms.mouse[0] = mouseX / width;
    uniforms.mouse[1] = 1.0f - (mouseY / height);
    uniforms.frame = frameCount++;

    lastFrame = now;

    glBindBuffer(GL_UNIFORM_BUFFER, ubo);
    glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(Uniforms), &uniforms);
  }

private:
  GLuint compileShader(GLenum type, const char *source) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);

    GLint success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success) {
      char infoLog[512];
      glGetShaderInfoLog(shader, 512, nullptr, infoLog);
      std::cerr << "Shader compile error ("
                << (type == GL_VERTEX_SHADER ? "vertex" : "fragment")
                << "): " << infoLog << std::endl;
      glDeleteShader(shader);
      return 0;
    }
    return shader;
  }
};

// Global state
static std::atomic<bool> g_running{true};
static std::string g_currentShader;
static GLESShaderProgram *g_shader = nullptr;
static std::unordered_map<std::string, double> g_shaderModTimes;
static bool g_hotReloadEnabled = true;

// Shader hot-reload functionality
void checkForShaderChanges() {
    if (!g_hotReloadEnabled || !g_shader)
        return;
    if (g_currentShader.empty())
        return;
    struct stat st;
    if (stat(g_currentShader.c_str(), &st) == 0) {
        double modTime = st.st_mtime;
        auto it = g_shaderModTimes.find(g_currentShader);
        if (it != g_shaderModTimes.end() && modTime > it->second) {
            if (g_shader->reload()) {
                g_shaderModTimes[g_currentShader] = modTime;
                // Show notification would go here - simplified for now
                std::cout << "Reloaded shader: " << g_currentShader << std::endl;
            }
        } else if (it == g_shaderModTimes.end()) {
            g_shaderModTimes[g_currentShader] = modTime;
        }
    }
}
static std::vector<std::string> g_shaderList;
static size_t g_currentShaderIndex = 0;
static std::chrono::steady_clock::time_point g_shaderStartTime;
static float g_shaderDisplayTime = 30.0f;
static float g_mouseX = 0, g_mouseY = 0;
static int g_width = 1920, g_height = 1080;
static EGLDisplay g_eglDisplay = EGL_NO_DISPLAY;
static EGLSurface g_eglSurface = EGL_NO_SURFACE;
static EGLContext g_eglContext = EGL_NO_CONTEXT;
static std::unique_ptr<AudioInput> g_audioInput;
static struct wl_keyboard *g_wlKeyboard = nullptr;
static struct wl_seat *g_wlSeat = nullptr;

// Wayland globals
static struct wl_display *g_wlDisplay = nullptr;
static struct wl_registry *g_wlRegistry = nullptr;
static struct wl_compositor *g_wlCompositor = nullptr;
static struct wl_subcompositor *g_wlSubcompositor = nullptr;
static struct xdg_wm_base *g_xdgWmBase = nullptr;
static struct zwlr_layer_shell_v1 *g_layerShell = nullptr;
static struct wl_output *g_wlOutput = nullptr;

// ext-idle-notify-v1 (sway, GNOME compatible)
static struct zext_idle_notifier_v1 *g_idleNotifier = nullptr;
static uint32_t g_idleTimeout = 0;

// ext-session-lock-v1 (GNOME, KDE compatible)
static struct ext_session_lock_manager_v1 *g_sessionLockManager = nullptr;
static struct ext_session_lock_v1 *g_sessionLock = nullptr;
static bool g_sessionLocked = false;

static void handleKeyboardKey(void *data, struct wl_keyboard *keyboard,
                              uint32_t serial, uint32_t time, uint32_t key,
                              uint32_t state);

static void handleGlobal(void *data, struct wl_registry *registry,
                         uint32_t name, const char *interface,
                         uint32_t version) {
  if (strcmp(interface, wl_compositor_interface.name) == 0) {
    g_wlCompositor = (wl_compositor *)wl_registry_bind(
        registry, name, &wl_compositor_interface, 4);
  } else if (strcmp(interface, wl_subcompositor_interface.name) == 0) {
    g_wlSubcompositor = (wl_subcompositor *)wl_registry_bind(
        registry, name, &wl_subcompositor_interface, 1);
  } else if (strcmp(interface, xdg_wm_base_interface.name) == 0) {
    g_xdgWmBase = (xdg_wm_base *)wl_registry_bind(registry, name,
                                                  &xdg_wm_base_interface, 1);
  } else if (strcmp(interface, zwlr_layer_shell_v1_interface.name) == 0) {
    g_layerShell = (zwlr_layer_shell_v1 *)wl_registry_bind(
        registry, name, &zwlr_layer_shell_v1_interface, 4);
  } else if (strcmp(interface, wl_output_interface.name) == 0) {
    g_wlOutput =
        (wl_output *)wl_registry_bind(registry, name, &wl_output_interface, 2);
  } else if (strcmp(interface, wl_seat_interface.name) == 0) {
    g_wlSeat =
        (wl_seat *)wl_registry_bind(registry, name, &wl_seat_interface, 5);
  }
#ifdef __linux__
  } else if (strcmp(interface, "zext_idle_notifier_v1") == 0) {
    g_idleNotifier = (zext_idle_notifier_v1 *)wl_registry_bind(
        registry, name, &zext_idle_notifier_v1_interface, 1);
  } else if (strcmp(interface, "ext_session_lock_manager_v1") == 0) {
    g_sessionLockManager = (ext_session_lock_manager_v1 *)wl_registry_bind(
        registry, name, &ext_session_lock_manager_v1_interface, 1);
#endif
  }
}

static void handleGlobalRemove(void *data, struct wl_registry *registry,
                               uint32_t name) {}

static const struct wl_registry_listener registryListener = {
    .global = handleGlobal, .global_remove = handleGlobalRemove};

static void goToNextShader();
static void goToPreviousShader();

static uint32_t g_keyboardMods = 0;
static void takeScreenshot();

static void handleKeyboardKeymap(void *data, struct wl_keyboard *keyboard,
                                  uint32_t format, int fd, uint32_t size) {
  (void)data;
  (void)keyboard;
  if (format != WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1)
    return;

  void *map = mmap(nullptr, size, PROT_READ, MAP_PRIVATE, fd, 0);
  if (map == MAP_FAILED)
    return;

  munmap(map, size);
  close(fd);
}
static void handleKeyboardEnter(void *data, struct wl_keyboard *keyboard,
                                uint32_t serial, struct wl_surface *surface,
                                struct wl_array *keys) {
  (void)data;
  (void)keyboard;
  (void)serial;
  (void)surface;
  (void)keys;
}
static void handleKeyboardLeave(void *data, struct wl_keyboard *keyboard,
                                uint32_t serial, struct wl_surface *surface) {
  (void)data;
  (void)keyboard;
  (void)serial;
  (void)surface;
}
static void handleKeyboardKey(void *data, struct wl_keyboard *keyboard,
                              uint32_t serial, uint32_t time, uint32_t key,
                              uint32_t state) {
  if (state == 0)
    return;

  bool ctrl = g_keyboardMods & (1 << 2);
  bool shift = g_keyboardMods & (1 << 0);

  if (ctrl && key == 23)
    g_running = false;
  else if (ctrl && shift && key == 23)
    g_running = false;
  else if (key == 57)
    goToNextShader();
  else if (key == 48)
    goToPreviousShader();
  else if (key == 45)
    goToNextShader();
  else if (key == 33)
    goToPreviousShader();
  else if (key == 1)
    g_running = false;
  else if (key == 88)
    takeScreenshot();
  // P key = next shader (evdev code 25)
  else if (key == 25)
    goToNextShader();
  // N key = previous shader (evdev code 49)
  else if (key == 49)
    goToPreviousShader();
  // D key = toggle debug overlay (evdev code 32)
  else if (key == 32)
    g_showDebug = !g_showDebug;
  // T key = run test suite (evdev code 20)
  else if (key == 20)
    runShaderTestSuite();
  // Tab key = switch display (evdev code 15)
  else if (key == 15)
    goToNextDisplay();
  // Ctrl+S = save preset (evdev code 31)
  else if (ctrl && key == 31)
    savePreset("default");
  // Ctrl+O = load preset (evdev code 24)
  else if (ctrl && key == 24)
    loadPreset("default");
  // Ctrl+Plus = increase intensity (evdev code 13)
  else if (ctrl && key == 13)
    g_intensity = MIN(2.0f, g_intensity + 0.1f);
  // Ctrl+Minus = decrease intensity (evdev code 12)
  else if (ctrl && key == 12)
    g_intensity = MAX(0.0f, g_intensity - 0.1f);
}
static void handleKeyboardModifiers(void *data, struct wl_keyboard *keyboard,
                                    uint32_t serial, uint32_t modsDepressed,
                                    uint32_t modsLatched, uint32_t modsLocked,
                                    uint32_t group) {
  (void)data;
  (void)keyboard;
  (void)serial;
  (void)group;
  g_keyboardMods = modsDepressed | modsLatched | modsLocked;
}
static void handleKeyboardRepeatInfo(void *data, struct wl_keyboard *keyboard,
                                      int32_t rate, int32_t delay) {
  (void)data;
  (void)keyboard;
  (void)rate;
  (void)delay;
}

static const struct wl_keyboard_listener keyboardListener = {
    .keymap = handleKeyboardKeymap,
    .enter = handleKeyboardEnter,
    .leave = handleKeyboardLeave,
    .key = handleKeyboardKey,
    .modifiers = handleKeyboardModifiers,
    .repeat_info = handleKeyboardRepeatInfo};

static void handleSeatCapabilities(void *data, struct wl_seat *seat,
                                   uint32_t caps) {
  if ((caps & WL_SEAT_CAPABILITY_KEYBOARD) && !g_wlKeyboard) {
    g_wlKeyboard = wl_seat_get_keyboard(seat);
    wl_keyboard_add_listener(g_wlKeyboard, &keyboardListener, nullptr);
  } else if (!(caps & WL_SEAT_CAPABILITY_KEYBOARD) && g_wlKeyboard) {
    wl_keyboard_destroy(g_wlKeyboard);
    g_wlKeyboard = nullptr;
  }
}
static void handleSeatName(void *data, struct wl_seat *seat, const char *name) {
}

static const struct wl_seat_listener seatListener = {
    .capabilities = handleSeatCapabilities, .name = handleSeatName};

static void initInput() {
  if (g_wlSeat) {
    wl_seat_add_listener(g_wlSeat, &seatListener, nullptr);
  }
}

// Wayland surface and layer shell objects
static struct wl_surface *g_wlSurface = nullptr;
static struct zwlr_layer_surface_v1 *g_layerSurface = nullptr;
static struct wl_egl_window *g_eglWindow = nullptr;
static int g_surfaceWidth = 1920;
static int g_surfaceHeight = 1080;

static bool initEGL() {
  // Get EGL extensions
  const char *clientExtensions = eglQueryString(EGL_NO_DISPLAY, EGL_EXTENSIONS);

  // Initialize EGL
  PFNEGLGETPLATFORMDISPLAYEXTPROC eglGetPlatformDisplay =
      (PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress(
          "eglGetPlatformDisplayEXT");

  if (eglGetPlatformDisplay && clientExtensions &&
      strstr(clientExtensions, "EGL_EXT_platform_wayland")) {
    g_eglDisplay = eglGetPlatformDisplay(EGL_PLATFORM_WAYLAND_EXT,
                                         (void *)g_wlDisplay, nullptr);
  } else {
    g_eglDisplay = eglGetDisplay((EGLNativeDisplayType)g_wlDisplay);
  }

  if (g_eglDisplay == EGL_NO_DISPLAY) {
    std::cerr << "Failed to get EGL display" << std::endl;
    return false;
  }

  EGLint major, minor;
  if (!eglInitialize(g_eglDisplay, &major, &minor)) {
    std::cerr << "Failed to initialize EGL" << std::endl;
    return false;
  }

  // Choose config
  EGLint configAttribs[] = {EGL_SURFACE_TYPE,
                            EGL_WINDOW_BIT,
                            EGL_RED_SIZE,
                            8,
                            EGL_GREEN_SIZE,
                            8,
                            EGL_BLUE_SIZE,
                            8,
                            EGL_ALPHA_SIZE,
                            8,
                            EGL_DEPTH_SIZE,
                            0,
                            EGL_RENDERABLE_TYPE,
                            EGL_OPENGL_ES2_BIT,
                            EGL_NONE};

  EGLConfig config;
  EGLint numConfigs;
  if (!eglChooseConfig(g_eglDisplay, configAttribs, &config, 1, &numConfigs) ||
      numConfigs == 0) {
    std::cerr << "Failed to choose EGL config" << std::endl;
    return false;
  }

  // Bind OpenGL ES
  if (!eglBindAPI(EGL_OPENGL_ES_API)) {
    std::cerr << "Failed to bind OpenGL ES API" << std::endl;
    return false;
  }

  // Create context
  EGLint contextAttribs[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};

  g_eglContext =
      eglCreateContext(g_eglDisplay, config, EGL_NO_CONTEXT, contextAttribs);
  if (g_eglContext == EGL_NO_CONTEXT) {
    std::cerr << "Failed to create EGL context" << std::endl;
    return false;
  }

  std::cout << "EGL initialized: " << major << "." << minor << std::endl;
  return true;
}

static void layerSurfaceConfigure(void *data,
                                  struct zwlr_layer_surface_v1 *layer_surface,
                                  uint32_t serial, uint32_t width,
                                  uint32_t height) {
  zwlr_layer_surface_v1_ack_configure(layer_surface, serial);
  g_surfaceWidth = width;
  g_surfaceHeight = height;
  g_width = width;
  g_height = height;
  if (g_eglWindow) {
    wl_egl_window_resize(g_eglWindow, width, height, 0, 0);
  }
  std::cout << "Layer surface configured: " << width << "x" << height
            << std::endl;
}

static void layerSurfaceClosed(void *data,
                               struct zwlr_layer_surface_v1 *layer_surface) {
  g_running = false;
}

static const struct zwlr_layer_surface_v1_listener layerSurfaceListener = {
    .configure = layerSurfaceConfigure, .closed = layerSurfaceClosed};

static bool createWaylandSurface() {
  if (!g_wlCompositor) {
    std::cerr << "No compositor available" << std::endl;
    return false;
  }

  // Create wl_surface
  g_wlSurface = wl_compositor_create_surface(g_wlCompositor);
  if (!g_wlSurface) {
    std::cerr << "Failed to create Wayland surface" << std::endl;
    return false;
  }

  // Get output geometry if available
  if (g_wlOutput) {
    // Use default size for now, will be updated by configure event
    g_surfaceWidth = g_width;
    g_surfaceHeight = g_height;
  }

  // Try to create layer shell surface for screensaver overlay
  if (g_layerShell) {
    g_layerSurface = zwlr_layer_shell_v1_get_layer_surface(
        g_layerShell, g_wlSurface, g_wlOutput,
        ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY, "shadercandy-screensaver");

    if (g_layerSurface) {
      zwlr_layer_surface_v1_set_size(g_layerSurface, g_surfaceWidth,
                                     g_surfaceHeight);
      zwlr_layer_surface_v1_set_anchor(g_layerSurface,
                                       ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP |
                                           ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM |
                                           ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT |
                                           ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT);
      zwlr_layer_surface_v1_set_exclusive_zone(g_layerSurface, -1);
      zwlr_layer_surface_v1_set_keyboard_interactivity(
          g_layerSurface, ZWLR_LAYER_SURFACE_V1_KEYBOARD_INTERACTIVITY_NONE);

      zwlr_layer_surface_v1_add_listener(g_layerSurface, &layerSurfaceListener,
                                         nullptr);
    }
  }

  // Create EGL window
  g_eglWindow =
      wl_egl_window_create(g_wlSurface, g_surfaceWidth, g_surfaceHeight);
  if (!g_eglWindow) {
    std::cerr << "Failed to create EGL window" << std::endl;
    return false;
  }

  // Create EGL surface
  EGLint configAttribs[] = {EGL_SURFACE_TYPE,
                            EGL_WINDOW_BIT,
                            EGL_RED_SIZE,
                            8,
                            EGL_GREEN_SIZE,
                            8,
                            EGL_BLUE_SIZE,
                            8,
                            EGL_ALPHA_SIZE,
                            8,
                            EGL_DEPTH_SIZE,
                            0,
                            EGL_RENDERABLE_TYPE,
                            EGL_OPENGL_ES2_BIT,
                            EGL_NONE};

  EGLConfig config;
  EGLint numConfigs;
  if (!eglChooseConfig(g_eglDisplay, configAttribs, &config, 1, &numConfigs) ||
      numConfigs == 0) {
    std::cerr << "Failed to choose EGL config for surface" << std::endl;
    return false;
  }

  g_eglSurface = eglCreateWindowSurface(
      g_eglDisplay, config, (EGLNativeWindowType)g_eglWindow, nullptr);
  if (g_eglSurface == EGL_NO_SURFACE) {
    std::cerr << "Failed to create EGL surface" << std::endl;
    return false;
  }

  // Make current
  if (!eglMakeCurrent(g_eglDisplay, g_eglSurface, g_eglSurface, g_eglContext)) {
    std::cerr << "Failed to make EGL context current" << std::endl;
    return false;
  }

  std::cout << "Wayland surface created: " << g_surfaceWidth << "x"
            << g_surfaceHeight << std::endl;
  return true;
}

static bool initOpenGLES() {
  glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
  glViewport(0, 0, g_width, g_height);
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

  std::cout << "OpenGL ES initialized" << std::endl;
  std::cout << "Vendor: " << glGetString(GL_VENDOR) << std::endl;
  std::cout << "Renderer: " << glGetString(GL_RENDERER) << std::endl;
  std::cout << "Version: " << glGetString(GL_VERSION) << std::endl;

  return true;
}

static void renderFrame() {
  if (!g_shader)
    return;

  glClear(GL_COLOR_BUFFER_BIT);

  g_shader->update(1.0f / 60.0f, g_width, g_height, g_mouseX, g_mouseY);

  glUseProgram(g_shader->program);

  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

  // Draw fullscreen quad
  float vertices[] = {-1.0f, -1.0f, 1.0f, -1.0f, -1.0f, 1.0f, 1.0f, 1.0f};

  GLint posLoc = glGetAttribLocation(g_shader->program, "position");
  if (posLoc >= 0) {
    glEnableVertexAttribArray(posLoc);
    glVertexAttribPointer(posLoc, 2, GL_FLOAT, GL_FALSE, 0, vertices);
  }

  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

static void handleSignal(int signum) { g_running = false; }

static void discoverAndLoadShaders(const std::string &dir) {
  g_shaderList.clear();

  std::vector<std::string> dirs = {dir, "./shaders", "./shaders/effects",
                                   "/usr/local/share/shadercandy/shaders",
                                   "/usr/share/shadercandy/shaders"};

  for (const auto &shaderDir : dirs) {
    DIR *d = opendir(shaderDir.c_str());
    if (!d)
      continue;

    struct dirent *entry;
    while ((entry = readdir(d))) {
      std::string name = entry->d_name;
      if (name.length() > 5 && (name.substr(name.length() - 5) == ".frag" ||
                                name.substr(name.length() - 6) == ".metal" ||
                                name.substr(name.length() - 5) == ".glsl")) {
        g_shaderList.push_back(shaderDir + "/" + name);
      }
    }
    closedir(d);
  }

  std::cout << "Discovered " << g_shaderList.size() << " shaders" << std::endl;
}

static bool loadShaderByIndex(size_t index) {
  if (g_shaderList.empty() || index >= g_shaderList.size()) {
    return false;
  }

  if (g_shader) {
    delete g_shader;
    g_shader = nullptr;
  }

  g_shader = new GLESShaderProgram();
  if (g_shader->loadFromFile(g_shaderList[index].c_str())) {
    g_currentShader = g_shaderList[index];
    g_currentShaderIndex = index;
    g_shaderStartTime = std::chrono::steady_clock::now();
    std::cout << "Loaded shader [" << index << "]: " << g_shaderList[index]
              << std::endl;
    return true;
  }

  delete g_shader;
  g_shader = nullptr;
  return false;
}

static void goToNextShader() {
  if (g_shaderList.empty())
    return;
  size_t nextIndex = (g_currentShaderIndex + 1) % g_shaderList.size();
  loadShaderByIndex(nextIndex);
}

static void goToPreviousShader() {
  if (g_shaderList.empty())
    return;
  size_t prevIndex =
      (g_currentShaderIndex + g_shaderList.size() - 1) % g_shaderList.size();
  loadShaderByIndex(prevIndex);
}

static void takeScreenshot() {
  if (!g_width || !g_height)
    return;

  std::vector<unsigned char> pixels(g_width * g_height * 4);
  glReadPixels(0, 0, g_width, g_height, GL_RGBA, GL_UNSIGNED_BYTE,
              pixels.data());

  for (int y = 0; y < g_height / 2; y++) {
    for (int x = 0; x < g_width * 4; x++) {
      int top = (y * g_width * 4) + x;
      int bottom = ((g_height - 1 - y) * g_width * 4) + x;
      std::swap(pixels[top], pixels[bottom]);
    }
  }

  auto now = std::chrono::system_clock::now();
  auto time = std::chrono::system_clock::to_time_t(now);
  struct tm *tm = localtime(&time);

  char filename[256];
  strftime(filename, sizeof(filename), "shadercandy_%Y%m%d_%H%M%S.ppm", tm);

  std::ofstream file(filename, std::ios::binary);
  if (file) {
    file << "P6\n" << g_width << " " << g_height << "\n255\n";
    file.write(reinterpret_cast<char *>(pixels.data()), g_width * g_height * 3);
    std::cout << "Screenshot saved: " << filename << std::endl;
  }
}

static bool loadShader(const std::string &path) {
  if (g_shader) {
    delete g_shader;
    g_shader = nullptr;
  }

  g_shader = new GLESShaderProgram();
  if (g_shader->loadFromFile(path.c_str())) {
    g_currentShader = path;
    std::cout << "Loaded shader: " << path << std::endl;
    return true;
  }

  delete g_shader;
  g_shader = nullptr;
  return false;
}

static void printUsage(const char *prog) {
  std::cout << "Usage: " << prog << " [options]\n\n"
            << "Options:\n"
            << "  --shader <path>    Load specific shader\n"
            << "  --list             List available shaders\n"
            << "  --help             Show this help\n"
            << "\nKeyboard controls:\n"
            << "  ESC, q             Quit\n"
            << "  SPACE              Next shader\n"
            << "  b                  Previous shader\n"
            << "  h                  Toggle metrics\n"
            << "  +/-                Adjust speed\n"
            << "  i/o                Adjust intensity\n";
}

int main(int argc, char *argv[]) {
  signal(SIGINT, handleSignal);
  signal(SIGTERM, handleSignal);

  std::string shaderPath;
  bool listShaders = false;

  for (int i = 1; i < argc; i++) {
    std::string arg = argv[i];
    if (arg == "--shader" && i + 1 < argc) {
      shaderPath = argv[++i];
    } else if (arg == "--list") {
      listShaders = true;
    } else if (arg == "--help") {
      printUsage(argv[0]);
      return 0;
    }
  }

  // Connect to Wayland display
  g_wlDisplay = wl_display_connect(nullptr);
  if (!g_wlDisplay) {
    std::cerr << "Failed to connect to Wayland display" << std::endl;
    std::cerr
        << "Make sure WAYLAND_DISPLAY is set or running in a Wayland session"
        << std::endl;
    return 1;
  }

  // Get registry
  g_wlRegistry = wl_display_get_registry(g_wlDisplay);
  wl_registry_add_listener(g_wlRegistry, &registryListener, nullptr);
  wl_display_roundtrip(g_wlDisplay);

  if (!g_wlCompositor) {
    std::cerr << "No Wayland compositor found" << std::endl;
    return 1;
  }

  // Initialize EGL
  if (!initEGL()) {
    return 1;
  }

  // Create Wayland surface and EGL window surface
  if (!createWaylandSurface()) {
    return 1;
  }

  // Commit the surface
  if (g_layerSurface) {
    wl_surface_commit(g_wlSurface);
    wl_display_roundtrip(g_wlDisplay);
  }

  // Initialize OpenGL ES
  if (!initOpenGLES()) {
    return 1;
  }

  // Initialize input handling
  initInput();
  wl_display_roundtrip(g_wlDisplay);

  // Discover all available shaders
  discoverAndLoadShaders(".");

  // List shaders if requested
  if (listShaders) {
    std::cout << "Available shaders:\n";
    for (size_t i = 0; i < g_shaderList.size(); ++i) {
      std::cout << "  [" << i << "] " << g_shaderList[i] << "\n";
    }
    return 0;
  }

  // Load initial shader
  bool shaderLoaded = false;
  if (!shaderPath.empty()) {
    // Add to list if specific shader requested
    g_shaderList.insert(g_shaderList.begin(), shaderPath);
    shaderLoaded = loadShaderByIndex(0);
  } else if (!g_shaderList.empty()) {
    shaderLoaded = loadShaderByIndex(0);
  }

  // Fallback to defaults if no shaders loaded
  if (!shaderLoaded) {
    std::vector<std::string> defaults = {
        "./shaders/plasma.glsl", "./shaders/plasma.frag",
        "./shaders/effects/plasma.glsl",
        "/usr/local/share/shadercandy/shaders/plasma.glsl"};
    for (const auto &s : defaults) {
      if (loadShader(s)) {
        shaderLoaded = true;
        break;
      }
    }
  }

  if (!g_shader) {
    std::cerr << "Failed to load any shader" << std::endl;
    return 1;
  }

   // Main event loop
   while (g_running) {
     // Handle Wayland events (blocking with timeout)
     wl_display_dispatch(g_wlDisplay);

     // Check for shader hot-reload
     checkForShaderChanges();

     // Check for shader auto-switch
     auto now = std::chrono::steady_clock::now();
     float shaderTime =
         std::chrono::duration<float>(now - g_shaderStartTime).count();
     if (shaderTime > g_shaderDisplayTime && g_shaderList.size() > 1) {
       goToNextShader();
     }

      // Render
      renderFrame();

      // Swap buffers
      eglSwapBuffers(g_eglDisplay, g_eglSurface);

      // Frame rate limiting based on target FPS
      auto& config = ShaderCandy::Config::ConfigurationManager::getInstance();
      int targetFPS = config.getSettings().targetFPS;
      if (targetFPS <= 0) targetFPS = 60; // Safety fallback
      uint32_t frameDelayMs = 1000 / targetFPS;
      std::this_thread::sleep_for(std::chrono::milliseconds(frameDelayMs));
    }

  // Cleanup
  if (g_shader) {
    delete g_shader;
    g_shader = nullptr;
  }

  g_audioInput.reset();
  g_shaderList.clear();

  if (g_eglContext != EGL_NO_CONTEXT) {
    eglDestroyContext(g_eglDisplay, g_eglContext);
    g_eglContext = EGL_NO_CONTEXT;
  }
  if (g_eglSurface != EGL_NO_SURFACE) {
    eglDestroySurface(g_eglDisplay, g_eglSurface);
    g_eglSurface = EGL_NO_SURFACE;
  }
  if (g_eglWindow) {
    wl_egl_window_destroy(g_eglWindow);
    g_eglWindow = nullptr;
  }
  if (g_eglDisplay != EGL_NO_DISPLAY) {
    eglTerminate(g_eglDisplay);
    g_eglDisplay = EGL_NO_DISPLAY;
  }

  if (g_wlKeyboard)
    wl_keyboard_destroy(g_wlKeyboard);
  if (g_wlSeat)
    wl_seat_destroy(g_wlSeat);
  if (g_layerSurface)
    zwlr_layer_surface_v1_destroy(g_layerSurface);
  if (g_wlSurface)
    wl_surface_destroy(g_wlSurface);
  if (g_layerShell)
    zwlr_layer_shell_v1_destroy(g_layerShell);
  if (g_xdgWmBase)
    xdg_wm_base_destroy(g_xdgWmBase);
  if (g_wlSubcompositor)
    wl_subcompositor_destroy(g_wlSubcompositor);
  if (g_wlCompositor)
    wl_compositor_destroy(g_wlCompositor);
  if (g_wlRegistry)
    wl_registry_destroy(g_wlRegistry);
  if (g_wlDisplay)
    wl_display_disconnect(g_wlDisplay);

  std::cout << "Wayland screensaver terminated" << std::endl;
  return 0;
}
