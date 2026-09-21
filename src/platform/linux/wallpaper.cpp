#define GL_GLEXT_PROTOTYPES
#include "GLSLWrapper.h"
#include "LinuxIPC.h"
#include "LinuxStubs.h"

#ifdef __linux__
#include <GL/gl.h>
#include <GL/glext.h>
#include <GL/glx.h>
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/extensions/Xcomposite.h>
#include <X11/extensions/Xrender.h>
#endif

#include <algorithm>
#include <chrono>
#include <csignal>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <memory>
#include <random>
#include <set>
#include <sstream>
#include <string>
#include <sys/stat.h>
#include <thread>
#include <vector>

#include "../../audio/AudioInput.h"
using namespace ShaderCandy::Audio;

using namespace ShaderCandy::Platform::Linux;

static std::string getHomeDir() {
  const char *home = getenv("HOME");
  if (home)
    return std::string(home);
  return std::string(".");
}

volatile sig_atomic_t running = 1;

void signalHandler(int sig) { running = 0; }

// Uniform structure
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

// Wallpaper engine
class WallpaperEngine {
public:
  Display *display = nullptr;
  Window rootWindow = 0;
  Window renderWindow = 0;
  GLXContext context = nullptr;

  int width = 1920;
  int height = 1080;

  GLuint vao = 0, vbo = 0;
  GLuint program = 0;
  GLuint ubo = 0;
  Colormap colormap = 0;
  Uniforms uniforms;
  int frameCount = 0;
  std::chrono::steady_clock::time_point startTime;
  std::chrono::steady_clock::time_point lastFrame;

  std::string currentShaderPath;

  // Shader rotation
  std::vector<std::string> shaderPaths;
  size_t currentShaderIndex = 0;
  bool shuffleMode = false;
  float rotateInterval = 30.0f;
  std::chrono::steady_clock::time_point lastRotateTime;
  std::set<std::string> favorites;
  std::set<std::string> skipList;
  std::mt19937 rng{std::random_device{}()};

  // Audio
  std::unique_ptr<AudioInput> audioInput;
  // IPC
  std::unique_ptr<LinuxIPC> ipc;
  bool enableAudio = false;

  bool initialize(int argc, char **argv);
  void run();
  void cleanup();
  bool loadShader(const char *path);
  void render();
  void updateUniforms();
  void scanShaderDir(const std::string &dir);
  void rotateShader();
  std::string getNextShaderPath();
  void toggleFavorite();
  void skipCurrentShader();

private:
  std::string loadShaderWithIncludes(const char *path, int depth = 0);
  bool compileShader(const char *fragmentSource);
  bool findRootWindow();
  bool setupRenderWindow();
};

std::string WallpaperEngine::loadShaderWithIncludes(const char *path,
                                                     int depth) {
  return GLSLWrapper::loadShaderWithIncludes(path, depth);
}

bool WallpaperEngine::compileShader(const char *fragmentSource) {
  std::string vertexSourceStr = GLSLWrapper::getVertexShader();
  const char *vertexSource = vertexSourceStr.c_str();

  GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
  glShaderSource(vertexShader, 1, &vertexSource, nullptr);
  glCompileShader(vertexShader);

  GLint success = 0;
  glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
  if (!success) {
    char infoLog[512];
    glGetShaderInfoLog(vertexShader, 512, nullptr, infoLog);
    std::cerr << "WallpaperEngine: Vertex shader error: " << infoLog << std::endl;
    glDeleteShader(vertexShader);
    return false;
  }

  GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(fragmentShader, 1, &fragmentSource, nullptr);
  glCompileShader(fragmentShader);

  glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &success);
  if (!success) {
    char infoLog[512];
    glGetShaderInfoLog(fragmentShader, 512, nullptr, infoLog);
    std::cerr << "WallpaperEngine: Fragment shader error: " << infoLog << std::endl;
    glDeleteShader(vertexShader);
    return false;
  }

  if (program) {
    glDeleteProgram(program);
  }

  program = glCreateProgram();
  glAttachShader(program, vertexShader);
  glAttachShader(program, fragmentShader);
  glLinkProgram(program);

  glGetProgramiv(program, GL_LINK_STATUS, &success);
  if (!success) {
    char infoLog[512];
    glGetProgramInfoLog(program, 512, nullptr, infoLog);
    std::cerr << "WallpaperEngine: Program link error: " << infoLog << std::endl;
    glDeleteProgram(program);
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);
    program = 0;
    return false;
  }

  glDeleteShader(vertexShader);
  glDeleteShader(fragmentShader);

  if (!ubo) {
    glGenBuffers(1, &ubo);
  }
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

  startTime = std::chrono::steady_clock::now();
  lastFrame = startTime;

  return true;
}

bool WallpaperEngine::loadShader(const char *path) {
  std::string fragStr = loadShaderWithIncludes(path);
  if (fragStr.empty()) {
    std::cerr << "WallpaperEngine: Failed to load shader: " << path << std::endl;
    return false;
  }

  std::string wrappedFrag = GLSLWrapper::getPreamble();
  wrappedFrag += fragStr;

  currentShaderPath = path;
  std::cout << "Loading wallpaper shader: " << path << std::endl;
  return compileShader(wrappedFrag.c_str());
}

bool WallpaperEngine::findRootWindow() {
  int screen = DefaultScreen(display);
  rootWindow = RootWindow(display, screen);

  // Get root window size
  XWindowAttributes attr{};
  XGetWindowAttributes(display, rootWindow, &attr);
  width = attr.width;
  height = attr.height;

  std::cout << "Root window size: " << width << "x" << height << std::endl;
  return true;
}

bool WallpaperEngine::setupRenderWindow() {
  int screen = DefaultScreen(display);

  // Check for composite extension
  int eventBase, errorBase;
  if (!XCompositeQueryExtension(display, &eventBase, &errorBase)) {
    std::cerr << "XComposite extension not available" << std::endl;
    // Continue anyway - might still work on some setups
  }

  // Create framebuffer config
  static int visualAttribs[] = {GLX_X_RENDERABLE,
                                True,
                                GLX_DRAWABLE_TYPE,
                                GLX_WINDOW_BIT | GLX_PIXMAP_BIT,
                                GLX_RENDER_TYPE,
                                GLX_RGBA_BIT,
                                GLX_X_VISUAL_TYPE,
                                GLX_TRUE_COLOR,
                                GLX_RED_SIZE,
                                8,
                                GLX_GREEN_SIZE,
                                8,
                                GLX_BLUE_SIZE,
                                8,
                                GLX_ALPHA_SIZE,
                                8,
                                GLX_DEPTH_SIZE,
                                24,
                                GLX_STENCIL_SIZE,
                                8,
                                None};

  int fbcount;
  GLXFBConfig *fbc =
      glXChooseFBConfig(display, screen, visualAttribs, &fbcount);
  if (!fbc || fbcount < 1) {
    std::cerr << "Failed to get framebuffer config" << std::endl;
    return false;
  }

  XVisualInfo *vi = glXGetVisualFromFBConfig(display, fbc[0]);
  if (!vi) {
    std::cerr << "Failed to get visual info" << std::endl;
    XFree(fbc);
    return false;
  }

  // Create a window as child of root
  XSetWindowAttributes swa;
  swa.colormap = XCreateColormap(display, rootWindow, vi->visual, AllocNone);
  colormap = swa.colormap;
  swa.event_mask = StructureNotifyMask;
  swa.override_redirect = True; // Bypass window manager

  renderWindow = XCreateWindow(
      display, rootWindow, 0, 0, width, height, 0, vi->depth, InputOutput,
      vi->visual, CWColormap | CWEventMask | CWOverrideRedirect, &swa);

  if (!renderWindow) {
    std::cerr << "Failed to create render window" << std::endl;
    XFree(fbc);
    XFree(vi);
    return false;
  }

  // Set window properties
  Atom wmState = XInternAtom(display, "_NET_WM_STATE", False);
  Atom wmStateBelow = XInternAtom(display, "_NET_WM_STATE_BELOW", False);
  Atom wmStateSticky = XInternAtom(display, "_NET_WM_STATE_STICKY", False);
  Atom wmStateSkipTaskbar =
      XInternAtom(display, "_NET_WM_STATE_SKIP_TASKBAR", False);
  Atom wmStateSkipPager =
      XInternAtom(display, "_NET_WM_STATE_SKIP_PAGER", False);
  Atom wmWindowType = XInternAtom(display, "_NET_WM_WINDOW_TYPE", False);
  Atom wmWindowTypeDesktop =
      XInternAtom(display, "_NET_WM_WINDOW_TYPE_DESKTOP", False);

  // Set window type to desktop
  XChangeProperty(display, renderWindow, wmWindowType, XA_ATOM, 32,
                  PropModeReplace, (unsigned char *)&wmWindowTypeDesktop, 1);

  // Set window states
  Atom states[] = {wmStateBelow, wmStateSticky, wmStateSkipTaskbar,
                   wmStateSkipPager};
  XChangeProperty(display, renderWindow, wmState, XA_ATOM, 32, PropModeReplace,
                  (unsigned char *)states, 4);

  // Map the window
  XMapWindow(display, renderWindow);
  XLowerWindow(display, renderWindow); // Put it behind everything

  // Create OpenGL context
  context = glXCreateNewContext(display, fbc[0], GLX_RGBA_TYPE, nullptr, True);
  if (!context) {
    std::cerr << "Failed to create OpenGL context" << std::endl;
    XDestroyWindow(display, renderWindow);
    renderWindow = 0;
    XFree(fbc);
    XFree(vi);
    return false;
  }

  glXMakeCurrent(display, renderWindow, context);

  XFree(fbc);
  XFree(vi);

  // Initialize OpenGL
  glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
  glDisable(GL_DEPTH_TEST);

  // Create fullscreen quad
  float vertices[] = {-1.0f, -1.0f, 0.0f, 0.0f, 1.0f,  -1.0f, 1.0f, 0.0f,
                      -1.0f, 1.0f,  0.0f, 1.0f, -1.0f, 1.0f,  0.0f, 1.0f,
                      1.0f,  -1.0f, 1.0f, 0.0f, 1.0f,  1.0f,  1.0f, 1.0f};

  glGenVertexArrays(1, &vao);
  glGenBuffers(1, &vbo);

  glBindVertexArray(vao);
  glBindBuffer(GL_ARRAY_BUFFER, vbo);
  glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void *)0);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float),
                        (void *)(2 * sizeof(float)));
  glEnableVertexAttribArray(1);

  std::cout << "Render window created successfully" << std::endl;
  return true;
}

bool WallpaperEngine::initialize(int argc, char **argv) {
  std::string shaderPath;
  std::vector<std::string> shaderDirs;

  // Parse arguments
  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "-shader") == 0 && i + 1 < argc) {
      shaderPath = argv[++i];
    } else if (strcmp(argv[i], "-dir") == 0 && i + 1 < argc) {
      shaderDirs.push_back(argv[++i]);
    } else if (strcmp(argv[i], "-rotate") == 0 && i + 1 < argc) {
      rotateInterval = std::stof(argv[++i]);
    } else if (strcmp(argv[i], "-shuffle") == 0) {
      shuffleMode = true;
    } else if (strcmp(argv[i], "-audio") == 0) {
      enableAudio = true;
    }
  }

  // Scan shader directories
  for (const auto &dir : shaderDirs) {
    scanShaderDir(dir);
  }

  // If no explicit shader and no dirs found, scan defaults
  if (shaderPath.empty() && shaderPaths.empty()) {
    scanShaderDir("./shaders");
    scanShaderDir(getHomeDir() + "/.local/share/shadercandy/shaders");
  }

  // Default shader if no rotation pool
  if (shaderPath.empty()) {
    if (!shaderPaths.empty()) {
      shaderPath = shaderPaths[0];
    } else {
      shaderPath = "./shaders/nebula.frag";
    }
  }

  // Open display
  display = XOpenDisplay(nullptr);
  if (!display) {
    std::cerr << "Failed to open X display" << std::endl;
    return false;
  }

  if (!findRootWindow()) {
    XCloseDisplay(display);
    display = nullptr;
    return false;
  }

  if (!setupRenderWindow()) {
    XCloseDisplay(display);
    display = nullptr;
    return false;
  }

  // Load shader
  if (!loadShader(shaderPath.c_str())) {
    std::cerr << "Failed to load shader: " << shaderPath << std::endl;
    cleanup();
    return false;
  }

  // Initialize audio if requested
  if (enableAudio) {
    audioInput = std::make_unique<AudioInput>();
    if (audioInput->initialize()) {
      if (audioInput->autoSelectDevice()) {
        audioInput->start();
        std::cout << "Audio input initialized" << std::endl;
      } else {
        std::cerr << "Failed to select audio device" << std::endl;
        audioInput.reset();
      }
    } else {
      std::cerr << "Failed to initialize audio" << std::endl;
      audioInput.reset();
    }
  }

  // Initialize IPC
  ipc = std::make_unique<LinuxIPC>();
  if (!ipc->isValid()) {
    std::cerr << "Warning: IPC initialization failed, running without IPC"
              << std::endl;
  }

  std::cout << "Wallpaper engine initialized with IPC" << std::endl;
  return true;
}

void WallpaperEngine::updateUniforms() {
  auto now = std::chrono::steady_clock::now();

  uniforms.time = std::chrono::duration<float>(now - startTime).count();
  uniforms.resolution[0] = static_cast<float>(width);
  uniforms.resolution[1] = static_cast<float>(height);
  uniforms.frame = frameCount++;
  uniforms.deltaTime = std::chrono::duration<float>(now - lastFrame).count();

  time_t t = time(nullptr);
  struct tm tm_buf;
  tm *lt = localtime_r(&t, &tm_buf);
  uniforms.date[0] = static_cast<float>(lt->tm_year + 1900);
  uniforms.date[1] = static_cast<float>(lt->tm_mon + 1);
  uniforms.date[2] = static_cast<float>(lt->tm_mday);
  uniforms.date[3] =
      static_cast<float>(lt->tm_hour * 3600 + lt->tm_min * 60 + lt->tm_sec);

  if (IPCData *data = ipc->getData()) {
    if (data->updateNeeded) {
      if (std::strlen(data->currentShader) > 0) {
        loadShader(data->currentShader);
        std::memset(data->currentShader, 0, 256);
      }
      uniforms.speed = data->speed;
      uniforms.intensity = data->intensity;
      data->updateNeeded = false;
    }
    if (data->quit)
      running = 0;
  }

  // Update audio uniforms
  if (audioInput && audioInput->isRunning()) {
    AudioData audioData = audioInput->getCurrentData();
    uniforms.volume = audioData.volume;
    uniforms.bass = audioData.bass;
    uniforms.mid = audioData.mid;
    uniforms.treble = audioData.treble;
    uniforms.beat = audioData.beat ? 1.0f : 0.0f;

    int samplesToCopy = std::min(256, (int)audioData.spectrum.size());
    for (int i = 0; i < samplesToCopy; ++i) {
      uniforms.audioData[i] = audioData.spectrum[i];
    }
  }

  glBindBuffer(GL_UNIFORM_BUFFER, ubo);
  glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(Uniforms), &uniforms);

  lastFrame = now;
}

void WallpaperEngine::render() {
  glClear(GL_COLOR_BUFFER_BIT);

  if (program) {
    glUseProgram(program);
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, ubo);
    updateUniforms();
    glDrawArrays(GL_TRIANGLES, 0, 6);
  }

  glXSwapBuffers(display, renderWindow);
}

void WallpaperEngine::scanShaderDir(const std::string &dir) {
  namespace fs = std::filesystem;
  if (!fs::exists(dir) || !fs::is_directory(dir))
    return;

  for (const auto &entry : fs::directory_iterator(dir)) {
    if (!entry.is_regular_file())
      continue;
    auto ext = entry.path().extension().string();
    if (ext == ".frag" || ext == ".glsl") {
      shaderPaths.push_back(entry.path().string());
    }
  }

  std::sort(shaderPaths.begin(), shaderPaths.end());
  std::cout << "Found " << shaderPaths.size() << " shaders in " << dir
            << std::endl;
}

std::string WallpaperEngine::getNextShaderPath() {
  if (shaderPaths.empty())
    return "";

  if (shuffleMode) {
    std::uniform_int_distribution<size_t> dist(0, shaderPaths.size() - 1);
    return shaderPaths[dist(rng)];
  }

  size_t attempts = 0;
  do {
    currentShaderIndex = (currentShaderIndex + 1) % shaderPaths.size();
    attempts++;
  } while (skipList.count(shaderPaths[currentShaderIndex]) &&
           attempts < shaderPaths.size());

  return shaderPaths[currentShaderIndex];
}

void WallpaperEngine::rotateShader() {
  if (shaderPaths.empty())
    return;

  std::string nextPath = getNextShaderPath();
  if (nextPath.empty())
    return;

  std::cout << "Rotating to shader: " << nextPath << std::endl;
  loadShader(nextPath.c_str());
}

void WallpaperEngine::toggleFavorite() {
  if (currentShaderPath.empty())
    return;
  auto it = favorites.find(currentShaderPath);
  if (it != favorites.end()) {
    favorites.erase(it);
    std::cout << "Removed from favorites: " << currentShaderPath << std::endl;
  } else {
    favorites.insert(currentShaderPath);
    std::cout << "Added to favorites: " << currentShaderPath << std::endl;
  }
}

void WallpaperEngine::skipCurrentShader() {
  if (currentShaderPath.empty())
    return;
  skipList.insert(currentShaderPath);
  std::cout << "Skipped: " << currentShaderPath << std::endl;
  rotateShader();
}

void WallpaperEngine::run() {
  XEvent event;
  lastRotateTime = std::chrono::steady_clock::now();

  while (running) {
    // Process X11 events (non-blocking)
    while (XPending(display) > 0) {
      XNextEvent(display, &event);
      if (event.type == ConfigureNotify) {
        // Handle resize
        if (event.xconfigure.width != width ||
            event.xconfigure.height != height) {
          width = event.xconfigure.width;
          height = event.xconfigure.height;
          glViewport(0, 0, width, height);
        }
      }
    }

    // Auto-rotate shaders
    if (rotateInterval > 0.0f && !shaderPaths.empty()) {
      auto now = std::chrono::steady_clock::now();
      float elapsed =
          std::chrono::duration<float>(now - lastRotateTime).count();
      if (elapsed >= rotateInterval) {
        rotateShader();
        lastRotateTime = now;
      }
    }

    render();

    // Limit to ~60fps
    std::this_thread::sleep_for(std::chrono::milliseconds(16));
  }
}

void WallpaperEngine::cleanup() {
  ipc.reset();
  audioInput.reset();

  if (vbo) {
    glDeleteBuffers(1, &vbo);
    vbo = 0;
  }
  if (vao) {
    glDeleteVertexArrays(1, &vao);
    vao = 0;
  }
  if (program) {
    glDeleteProgram(program);
    program = 0;
  }
  if (ubo) {
    glDeleteBuffers(1, &ubo);
    ubo = 0;
  }

  if (context) {
    glXMakeCurrent(display, None, nullptr);
    glXDestroyContext(display, context);
    context = nullptr;
  }

  if (renderWindow) {
    XDestroyWindow(display, renderWindow);
    renderWindow = 0;
  }

  if (colormap && display) {
    XFreeColormap(display, colormap);
    colormap = 0;
  }

  if (display) {
    XCloseDisplay(display);
    display = nullptr;
  }
}

void printUsage(const char *program) {
  std::cout
      << "ShaderCandy Linux Wallpaper\n"
      << "Usage: " << program << " [options]\n"
      << "Options:\n"
      << "  -shader <path>     Path to shader file\n"
      << "  -dir <path>        Add shader directory (can be used multiple times)\n"
      << "  -rotate <seconds>  Auto-rotate interval (default: 30, 0 = off)\n"
      << "  -shuffle           Enable shuffle mode\n"
      << "  -audio             Enable audio reactivity\n"
      << "\nNote: This requires a compositor that supports desktop windows.\n"
      << "      For best results, use with xwinwrap or a similar tool.\n"
      << "\nExample with xwinwrap:\n"
      << "  xwinwrap -ov -fs -- " << program
      << " -dir ./shaders -rotate 20 -shuffle\n";
}

int main(int argc, char **argv) {
  if (argc > 1 &&
      (strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0)) {
    printUsage(argv[0]);
    return 0;
  }

  // Setup signal handlers
  signal(SIGINT, signalHandler);
  signal(SIGTERM, signalHandler);

  WallpaperEngine engine;

  if (!engine.initialize(argc, argv)) {
    std::cerr << "Failed to initialize wallpaper engine" << std::endl;
    return 1;
  }

  engine.run();
  engine.cleanup();

  return 0;
}
