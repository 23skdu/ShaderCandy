// ShaderCandy Linux Wallpaper Mode
// Renders shaders as the desktop wallpaper using X11 root window

#define GL_GLEXT_PROTOTYPES

#include "GLSLWrapper.h"
#include "LinuxIPC.h"
#include <GL/gl.h>
#include <GL/glext.h>
#include <GL/glx.h>
#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/extensions/Xcomposite.h>
#include <X11/extensions/Xrender.h>
#include <chrono>
#include <csignal>
#include <cstring>
#include <iostream>
#include <string>
#include <sys/stat.h>
#include <thread>
#include <vector>

using namespace ShaderCandy::Platform::Linux;

// Audio support
#include "AudioInput.h"
using namespace ShaderCandy::Audio;

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
  Uniforms uniforms;
  int frameCount = 0;
  std::chrono::steady_clock::time_point startTime;
  std::chrono::steady_clock::time_point lastFrame;

  std::string currentShaderPath;

  // Audio
  AudioInput *audioInput = nullptr;
  // IPC
  LinuxIPC *ipc = nullptr;
  bool enableAudio = false;

  bool initialize(int argc, char **argv);
  void run();
  void cleanup();
  bool loadShader(const char *path);
  void render();
  void updateUniforms();

private:
  std::string loadShaderWithIncludes(const char *path, int depth = 0);
  bool compileShader(const char *fragmentSource);
  bool findRootWindow();
  bool setupRenderWindow();
};

std::string WallpaperEngine::loadShaderWithIncludes(const char *path,
                                                    int depth) {
  if (depth > 10) {
    std::cerr << "Include depth exceeded for: " << path << std::endl;
    return "";
  }

  std::ifstream file(path);
  if (!file.is_open()) {
    return "";
  }

  std::string dir = path;
  size_t lastSlash = dir.find_last_of("/\\");
  if (lastSlash != std::string::npos) {
    dir = dir.substr(0, lastSlash + 1);
  } else {
    dir = "./";
  }

  std::stringstream result;
  std::string line;
  while (std::getline(file, line)) {
    size_t versionPos = line.find("#version");
    if (versionPos != std::string::npos) {
      continue;
    }

    size_t includePos = line.find("#include");
    if (includePos != std::string::npos) {
      size_t start = line.find('"', includePos);
      size_t end = std::string::npos;
      if (start != std::string::npos) {
        end = line.find('"', start + 1);
      }

      if (start != std::string::npos && end != std::string::npos) {
        std::string includePath = line.substr(start + 1, end - start - 1);
        std::string fullPath;
        if (includePath[0] == '/') {
          fullPath = includePath;
        } else if (includePath.substr(0, 3) == "../") {
          std::string parentDir = dir;
          if (parentDir.length() > 0 &&
              (parentDir.back() == '/' || parentDir.back() == '\\')) {
            parentDir.pop_back();
          }
          size_t parentSlash = parentDir.find_last_of("/\\");
          if (parentSlash != std::string::npos) {
            parentDir = parentDir.substr(0, parentSlash + 1);
          }
          fullPath = parentDir + includePath.substr(3);
        } else if (includePath.substr(0, 2) == "./") {
          fullPath = dir + includePath.substr(2);
        } else {
          fullPath = dir + includePath;
        }

        std::string includeContent =
            loadShaderWithIncludes(fullPath.c_str(), depth + 1);
        if (!includeContent.empty()) {
          result << includeContent << "\n";
        }
        continue;
      }
    }
    result << line << "\n";
  }

  return result.str();
}

bool WallpaperEngine::compileShader(const char *fragmentSource) {
  const char *vertexSource = GLSLWrapper::getVertexShader().c_str();
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
  XWindowAttributes attr;
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

  // Create a window as child of root
  XSetWindowAttributes swa;
  swa.colormap = XCreateColormap(display, rootWindow, vi->visual, AllocNone);
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

  // Parse arguments
  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "-shader") == 0 && i + 1 < argc) {
      shaderPath = argv[++i];
    } else if (strcmp(argv[i], "-audio") == 0) {
      enableAudio = true;
    }
  }

  // Default shader
  if (shaderPath.empty()) {
    shaderPath = "./shaders/nebula.frag";
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
    audioInput = new AudioInput();
    if (audioInput->initialize()) {
      if (audioInput->autoSelectDevice()) {
        audioInput->start();
        std::cout << "Audio input initialized" << std::endl;
      } else {
        std::cerr << "Failed to select audio device" << std::endl;
        delete audioInput;
        audioInput = nullptr;
      }
    } else {
      std::cerr << "Failed to initialize audio" << std::endl;
      delete audioInput;
      audioInput = nullptr;
    }
  }

  // Initialize IPC
  ipc = new LinuxIPC();

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
  tm *lt = localtime(&t);
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

void WallpaperEngine::run() {
  XEvent event;

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

    render();

    // Limit to ~60fps
    std::this_thread::sleep_for(std::chrono::milliseconds(16));
  }
}

void WallpaperEngine::cleanup() {
  if (ipc) {
    delete ipc;
    ipc = nullptr;
  }
  if (audioInput) {
    delete audioInput;
    audioInput = nullptr;
  }

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
      << "  -shader <path>     Path to shader file (default: "
         "./shaders/nebula.frag)\n"
      << "  -audio             Enable audio reactivity\n"
      << "\nNote: This requires a compositor that supports desktop windows.\n"
      << "      For best results, use with xwinwrap or a similar tool.\n"
      << "\nExample with xwinwrap:\n"
      << "  xwinwrap -ov -fs -- " << program
      << " -shader ./shaders/plasma.frag\n";
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
