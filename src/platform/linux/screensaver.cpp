/* This is free and unencumbered software released into the public domain.
   See LICENSE or <https://unlicense.org/> for details. */

#include "../../config/ConfigurationManager.h"
#include "GLShaderProgram.h"
#include "LinuxStubs.h"
#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdlib>
#include <cstring>
#include <dirent.h>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sys/stat.h>
#include <unistd.h>
#include <vector>

using namespace ShaderCandy::Platform::Linux;

// Audio support
#ifdef HAS_AUDIO
#include "../../audio/AudioInput.h"
using namespace ShaderCandy::Audio;
#else
// Stubs when audio is not available
namespace ShaderCandy {
namespace Audio {
class AudioInput {
public:
  AudioInput() {}
  ~AudioInput() {}
  bool initialize(int = 0, int = 0) { return false; }
  bool autoSelectDevice() { return false; }
  bool start() { return false; }
  void stop() {}
  bool isRunning() const { return false; }
  AudioData getCurrentData() const { return AudioData(); }
};
} // namespace Audio
} // namespace ShaderCandy
using namespace ShaderCandy::Audio;
#endif

GLuint audioUbo = 0;
GLuint paramsUbo = 0;
AudioUniforms audioUniforms;
ShaderParams shaderParams;

// Enhanced screensaver with shader management
class X11Screensaver {
private:
  Display *display = nullptr;
  Window window = 0;
  GLXContext context = nullptr;
  Colormap colormap = 0;

  std::vector<GLShaderProgram *> shaders;
  size_t currentShaderIndex = 0;
  GLShaderProgram *currentShader = nullptr;
  GLShaderProgram *nextShader = nullptr;

  GLuint vao = 0, vbo = 0;
  bool running = true;
  int width = 1920;
  int height = 1080;

  // Multi-display support
  struct DisplayInfo {
    int screen;
    int x, y;
    int width, height;
  };
  std::vector<DisplayInfo> displays;
  int currentDisplay = 0;

  void initMultiDisplay() {
    if (!display)
      return;
    int screenCount = ScreenCount(display);
    displays.clear();
    for (int i = 0; i < screenCount; i++) {
      Screen *screen = ScreenOfDisplay(display, i);
      DisplayInfo info;
      info.screen = i;
      info.x = 0;
      info.y = 0;
      info.width = WidthOfScreen(screen);
      info.height = HeightOfScreen(screen);
      displays.push_back(info);
    }
    if (displays.empty()) {
      DisplayInfo info;
      info.screen = 0;
      info.x = 0;
      info.y = 0;
      info.width = width;
      info.height = height;
      displays.push_back(info);
    }
  }

  void goToNextDisplay() {
    if (displays.size() <= 1)
      return;
    currentDisplay = (currentDisplay + 1) % displays.size();
    width = displays[currentDisplay].width;
    height = displays[currentDisplay].height;
    showNotification("Display " + std::to_string(currentDisplay + 1) + "/" +
                     std::to_string(displays.size()));
  }

  float mouseX = 0.0f;
  float mouseY = 0.0f;
  int mouseBtns = 0;

  // Transition handling
  float transitionProgress = 0.0f;
  bool inTransition = false;
  float transitionDuration = 2.0f;
  std::chrono::steady_clock::time_point transitionStart;
  float timePerShader = 60.0f; // Seconds before auto-switch
  std::chrono::steady_clock::time_point shaderStartTime;

  // OSD notification
  std::string notificationText;
  std::chrono::steady_clock::time_point notificationTime;
  float notificationDuration = 3.0f;

  // Shader directories
  std::vector<std::string> shaderPaths;
  std::string shaderDir;
  std::unordered_map<std::string, double> shaderModTimes;

  // Audio input
  AudioInput *audioInput = nullptr;
  bool enableAudio = false;

  bool hotReloadEnabled = true;

  // Frame rate limiting
  int targetFPS = 60;
  uint32_t frameDelayMs = 16; // Default to ~60 FPS

  void checkForShaderChanges() {
    if (!hotReloadEnabled || !currentShader)
      return;
    if (currentShader->path.empty())
      return;
    struct stat st;
    if (stat(currentShader->path.c_str(), &st) == 0) {
      double modTime = st.st_mtime;
      auto it = shaderModTimes.find(currentShader->path);
      if (it != shaderModTimes.end() && modTime > it->second) {
        currentShader->reload();
        shaderModTimes[currentShader->path] = modTime;
        showNotification("Reloaded: " + currentShader->name);
      } else if (it == shaderModTimes.end()) {
        shaderModTimes[currentShader->path] = modTime;
      }
    }
  }

public:
  X11Screensaver() = default;
  ~X11Screensaver() { cleanup(); }

  void addShaderDirectory(const std::string &dir) {
    shaderPaths.push_back(dir);
  }

  bool initialize(int argc, char **argv) {
    // Parse arguments
    Window parent = 0;
    std::string initialShader;
    bool useRootWindow = false;

    for (int i = 1; i < argc; i++) {
      if ((strcmp(argv[i], "-window-id") == 0 || strcmp(argv[i], "--window-id") == 0) && i + 1 < argc) {
        parent = strtoul(argv[i + 1], nullptr, 0);
      } else if (strcmp(argv[i], "-root") == 0 || strcmp(argv[i], "--root") == 0) {
        // Run on root window
        useRootWindow = true;
      } else if ((strcmp(argv[i], "-shader") == 0 || strcmp(argv[i], "--shader") == 0) && i + 1 < argc) {
        initialShader = argv[++i];
      } else if ((strcmp(argv[i], "-shader-dir") == 0 || strcmp(argv[i], "--shader-dir") == 0) && i + 1 < argc) {
        addShaderDirectory(argv[++i]);
      } else if (strcmp(argv[i], "-audio") == 0 || strcmp(argv[i], "--audio") == 0) {
        enableAudio = true;
      }
    }

    // Default shader directories - local paths first for development
    if (shaderPaths.empty()) {
      addShaderDirectory("./shaders");
      addShaderDirectory("./shaders/effects");
      addShaderDirectory("../shaders");
      addShaderDirectory("../shaders/effects");
      addShaderDirectory("../shaders/base");
      // System directories
      addShaderDirectory("/usr/share/shadercandy/shaders");
      addShaderDirectory("/usr/local/share/shadercandy/shaders");
      const char *home = getenv("HOME");
      if (home) {
        addShaderDirectory(std::string(home) +
                           "/.local/share/shadercandy/shaders");
      }
    }

    // Open display
    display = XOpenDisplay(nullptr);
    if (!display) {
      std::cerr << "Failed to open X display" << std::endl;
      return false;
    }

    int screen = DefaultScreen(display);
    if (!parent) {
      parent = RootWindow(display, screen);
    }

    // Get window size
    XWindowAttributes parentAttr{};
    XGetWindowAttributes(display, parent, &parentAttr);
    width = parentAttr.width;
    height = parentAttr.height;

    // Create OpenGL context
    static int visualAttribs[] = {GLX_X_RENDERABLE,
                                  True,
                                  GLX_DRAWABLE_TYPE,
                                  GLX_WINDOW_BIT,
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

    if (useRootWindow) {
      // Use root window directly
      window = parent;
      std::cerr << "ShaderCandy: Using root window " << std::hex << window
                << std::dec << " (" << width << "x" << height << ")"
                << std::endl;
    } else {
      // Create a new window
      Colormap cmap = XCreateColormap(display, parent, vi->visual, AllocNone);

      XSetWindowAttributes swa;
      swa.colormap = cmap;
      swa.event_mask = ExposureMask | KeyPressMask | ButtonPressMask |
                       PointerMotionMask | StructureNotifyMask;

      window = XCreateWindow(display, parent, 0, 0, width, height, 0, vi->depth,
                             InputOutput, vi->visual, CWColormap | CWEventMask,
                             &swa);

      XMapWindow(display, window);
      XFlush(display);

      // Wait for window to be mapped
      XSync(display, False);

      XWindowAttributes winAttr{};
      for (int i = 0; i < 10; i++) {
        XGetWindowAttributes(display, window, &winAttr);
        if (winAttr.map_state == IsViewable)
          break;
        usleep(10000);
      }

      std::cerr << "ShaderCandy: Window " << std::hex << window << std::dec
                << " ready (" << winAttr.width << "x" << winAttr.height << ")"
                << std::endl;

      XRaiseWindow(display, window);
      XFlush(display);

      // Store colormap for cleanup
      colormap = cmap;
    }

    context =
        glXCreateNewContext(display, fbc[0], GLX_RGBA_TYPE, nullptr, True);
    if (!context) {
      std::cerr << "Failed to create OpenGL context" << std::endl;
      XFree(fbc);
      XFree(vi);
      return false;
    }

    glXMakeCurrent(display, window, context);

    // Initialize OpenGL function pointers
    if (!InitializeGLLoader()) {
      std::cerr << "Failed to initialize OpenGL function pointers" << std::endl;
      XFree(fbc);
      XFree(vi);
      return false;
    }

    // Initialize OpenGL
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glViewport(0, 0, width, height);

    // Create fullscreen quad
    float vertices[] = {-1.0f, -1.0f, 0.0f, 0.0f, 1.0f,  -1.0f, 1.0f, 0.0f,
                        -1.0f, 1.0f,  0.0f, 1.0f, -1.0f, 1.0f,  0.0f, 1.0f,
                        1.0f,  -1.0f, 1.0f, 0.0f, 1.0f,  1.0f,  1.0f, 1.0f};

    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);

    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float),
                          (void *)0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float),
                          (void *)(2 * sizeof(float)));
    glEnableVertexAttribArray(1);

    // Discover and load shaders
    discoverShaders();

    if (shaders.empty()) {
      std::cerr << "No shaders found!" << std::endl;
      createFallbackShader();
    }

    // Select initial shader
    if (!initialShader.empty()) {
      selectShaderByName(initialShader);
    } else {
      currentShader = shaders[0];
    }

    XFree(fbc);
    XFree(vi);

    shaderStartTime = std::chrono::steady_clock::now();

    // Initialize audio if requested
    if (enableAudio) {
      audioInput = new AudioInput();
      if (audioInput->initialize()) {
        if (audioInput->autoSelectDevice()) {
          audioInput->start();
          std::cout << "Audio input initialized successfully" << std::endl;
        } else {
          std::cerr << "Failed to auto-select audio device" << std::endl;
          delete audioInput;
          audioInput = nullptr;
        }
      } else {
        std::cerr << "Failed to initialize audio input" << std::endl;
        delete audioInput;
        audioInput = nullptr;
      }
    }

    return true;
  }

  void discoverShaders() {
    for (const auto &dir : shaderPaths) {
      scanShaderDirectory(dir);
    }
  }

  void scanShaderDirectory(const std::string &dir) {
    std::cerr << "Scanning shader directory: " << dir << std::endl;

    // Use glob or simple scan to find all .frag files
    std::vector<std::string> shaderFiles;

// Safely scan directory for .frag files using POSIX opendir/readdir
    scanDirectoryRecursive(dir, shaderFiles, 0, 2);

    for (const auto &path : shaderFiles) {
      std::cerr << "Found shader: " << path << std::endl;
      loadShader(path);
    }
  }

  void loadShaderSimple(const std::string &path) {
    // Load the raw file content
    std::ifstream file(path);
    if (!file.is_open()) {
      std::cerr << "Failed to open: " << path << std::endl;
      return;
    }

    std::stringstream buffer;
    buffer << file.rdbuf();
    std::string fragStr = buffer.str();

    // Extract shader name
    std::string shaderName = path;
    size_t lastSlash = shaderName.find_last_of("/\\");
    if (lastSlash != std::string::npos) {
      shaderName = shaderName.substr(lastSlash + 1);
    }
    size_t extPos = shaderName.find_last_of('.');
    if (extPos != std::string::npos) {
      shaderName = shaderName.substr(0, extPos);
    }

    // Replace #version with our version
    size_t versionPos = fragStr.find("#version");
    while (versionPos != std::string::npos) {
      size_t endLine = fragStr.find("\n", versionPos);
      if (endLine != std::string::npos) {
        fragStr.replace(versionPos, endLine - versionPos, "");
      } else {
        fragStr.replace(versionPos, std::string::npos, "");
      }
      versionPos = fragStr.find("#version", versionPos);
    }

    // Add our version and uniforms at the beginning
    std::string preamble = R"Shader(#version 330 core

layout(std140) uniform Uniforms {
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

)Shader";

    std::string wrappedFrag = preamble + fragStr;

    // Compile
    auto *shader = new GLShaderProgram();
    std::string vertexShaderStr = GLSLWrapper::getVertexShader();

    if (shader->loadShader(vertexShaderStr.c_str(), wrappedFrag.c_str())) {
      shader->name = shaderName;
      shaders.push_back(shader);
      std::cout << "Loaded shader: " << shaderName << std::endl;
    } else {
      delete shader;
      std::cerr << "Failed to compile: " << path << std::endl;
    }
  }

  void scanDirectoryRecursive(const std::string &dir,
                             std::vector<std::string> &out, int depth,
                             int maxDepth) {
    if (depth > maxDepth)
      return;
    DIR *d = opendir(dir.c_str());
    if (!d)
      return;
    struct dirent *entry;
    while ((entry = readdir(d)) != nullptr) {
      if (entry->d_name[0] == '.')
        continue;
      std::string name(entry->d_name);
      std::string fullpath = dir + "/" + name;
      if (entry->d_type == DT_DIR) {
        scanDirectoryRecursive(fullpath, out, depth + 1, maxDepth);
      } else if (entry->d_type == DT_REG) {
        if (name.size() > 5 && name.substr(name.size() - 5) == ".frag") {
          out.push_back(fullpath);
        }
      }
    }
    closedir(d);
  }

  bool hasShader(const std::string &shaderName) const {
    for (const auto *s : shaders) {
      if (s->name == shaderName)
        return true;
    }
    return false;
  }

  void loadShader(const std::string &path) {
    auto *shader = new GLShaderProgram();
    if (shader->loadShaderFromFile(path.c_str())) {
      if (hasShader(shader->name)) {
        delete shader;
        return;
      }
      shaders.push_back(shader);
      std::cout << "Loaded shader: " << shader->name << std::endl;
    } else {
      delete shader;
    }
  }

  void createFallbackShader() {
    auto *shader = new GLShaderProgram();
    const char *vert = R"(#version 330 core
            layout(location = 0) in vec2 aPos;
            void main() { gl_Position = vec4(aPos, 0.0, 1.0); }
        )";
    const char *frag = R"(#version 330 core
            layout(std140) uniform Uniforms { float time; vec2 resolution; };
            out vec4 fragColor;
            void main() {
                vec2 uv = gl_FragCoord.xy / resolution;
                float c = sin(uv.x * 10.0 + time) * sin(uv.y * 10.0 + time);
                fragColor = vec4(c, c * 0.5, 1.0 - c, 1.0);
            }
        )";
    if (shader->loadShader(vert, frag)) {
      shader->name = "fallback";
      shaders.push_back(shader);
    }
  }

  void selectShaderByName(const std::string &name) {
    for (size_t i = 0; i < shaders.size(); i++) {
      if (shaders[i]->name == name) {
        currentShaderIndex = i;
        currentShader = shaders[i];
        return;
      }
    }
    // If not found, use first shader
    if (!shaders.empty()) {
      currentShader = shaders[0];
    }
  }

  void goToNextShader() {
    if (shaders.size() <= 1)
      return;

    nextShader = shaders[(currentShaderIndex + 1) % shaders.size()];
    currentShaderIndex = (currentShaderIndex + 1) % shaders.size();

    inTransition = true;
    transitionProgress = 0.0f;
    transitionStart = std::chrono::steady_clock::now();
  }

  void goToPreviousShader() {
    if (shaders.size() <= 1)
      return;

    currentShaderIndex =
        (currentShaderIndex + shaders.size() - 1) % shaders.size();
    nextShader = shaders[currentShaderIndex];

    inTransition = true;
    transitionProgress = 0.0f;
    transitionStart = std::chrono::steady_clock::now();
  }

  void takeScreenshot() {
    std::vector<unsigned char> pixels(width * height * 4);
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, pixels.data());

    for (int y = 0; y < height / 2; y++) {
      for (int x = 0; x < width * 4; x++) {
        int top = (y * width * 4) + x;
        int bottom = ((height - 1 - y) * width * 4) + x;
        std::swap(pixels[top], pixels[bottom]);
      }
    }

    auto now = std::chrono::system_clock::now();
    auto time = std::chrono::system_clock::to_time_t(now);
    struct tm *tm = localtime(&time);

    std::stringstream ss;
    ss << "shadercandy_" << std::put_time(tm, "%Y%m%d_%H%M%S") << ".png"
       << std::ends;
    std::string filename = ss.str();
    filename.pop_back();

    std::ofstream file(filename, std::ios::binary);
    if (file) {
      file << "P6\n" << width << " " << height << "\n255\n";
      file.write(reinterpret_cast<char *>(pixels.data()), width * height * 3);
      std::cout << "Screenshot saved: " << filename << std::endl;
    }
  }

  void showNotification(const std::string &message) {
    notificationText = message;
    notificationTime = std::chrono::steady_clock::now();
  }

  void savePreset(const std::string &name) {
    std::string presetDir =
        std::string(getenv("HOME")) + "/.config/shadercandy";
    mkdir(presetDir.c_str(), 0755);
    std::string presetFile = presetDir + "/" + name + ".cfg";

    std::ofstream out(presetFile);
    if (out && currentShader) {
      out << "# ShaderCandy Preset\n";
      out << "shader=" << currentShader->name << "\n";
      out << "speed=" << currentShader->uniforms.speed << "\n";
      out << "intensity=" << currentShader->uniforms.intensity << "\n";
      out << "param1=" << shaderParams.param1 << "\n";
      out << "param2=" << shaderParams.param2 << "\n";
      out << "param3=" << shaderParams.param3 << "\n";
      out << "param4=" << shaderParams.param4 << "\n";
      out << "colorPalette=" << shaderParams.colorPalette << "\n";
      std::cout << "Preset saved: " << presetFile << std::endl;
      showNotification("Saved: " + name);
    }
  }

  bool loadPreset(const std::string &name) {
    std::string presetDir =
        std::string(getenv("HOME")) + "/.config/shadercandy";
    std::string presetFile = presetDir + "/" + name + ".cfg";

    std::ifstream in(presetFile);
    if (!in) {
      showNotification("Preset not found: " + name);
      return false;
    }

    std::string line;
    while (std::getline(in, line)) {
      if (line.empty() || line[0] == '#')
        continue;
      size_t eq = line.find('=');
      if (eq == std::string::npos)
        continue;
      std::string key = line.substr(0, eq);
      std::string val = line.substr(eq + 1);

      if (key == "shader" && !val.empty()) {
        loadShader(val);
      } else if (key == "speed" && currentShader) {
        currentShader->uniforms.speed = std::stof(val);
      } else if (key == "intensity" && currentShader) {
        currentShader->uniforms.intensity = std::stof(val);
      } else if (key == "param1") {
        shaderParams.param1 = std::stof(val);
      } else if (key == "param2") {
        shaderParams.param2 = std::stof(val);
      } else if (key == "param3") {
        shaderParams.param3 = std::stof(val);
      } else if (key == "param4") {
        shaderParams.param4 = std::stof(val);
      } else if (key == "colorPalette") {
        shaderParams.colorPalette = std::stoi(val);
      }
    }
    std::cout << "Preset loaded: " << presetFile << std::endl;
    showNotification("Loaded: " + name);
    return true;
  }

  void checkForShaderReload() {
    if (!hotReloadEnabled || !currentShader || currentShader->path.empty())
      return;

    struct stat st;
    if (stat(currentShader->path.c_str(), &st) == 0) {
      double modTime = st.st_mtime;
      auto it = shaderModTimes.find(currentShader->path);
      if (it != shaderModTimes.end() && modTime > it->second) {
        currentShader->reload();
        shaderModTimes[currentShader->path] = modTime;
        showNotification("Reloaded: " + currentShader->name);
      } else if (it == shaderModTimes.end()) {
        shaderModTimes[currentShader->path] = modTime;
      }
    }
  }

  void renderNotification() {
    if (notificationText.empty())
      return;

    auto now = std::chrono::steady_clock::now();
    float elapsed =
        std::chrono::duration<float>(now - notificationTime).count();
    if (elapsed > notificationDuration) {
      notificationText.clear();
      return;
    }

    float alpha = 1.0f - (elapsed / notificationDuration);
    if (alpha > 0.0f) {
      glMatrixMode(GL_PROJECTION);
      glPushMatrix();
      glLoadIdentity();
      glOrtho(0, width, 0, height, -1, 1);
      glMatrixMode(GL_MODELVIEW);
      glPushMatrix();
      glLoadIdentity();

      glEnable(GL_BLEND);
      glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

      glColor4f(0.0f, 0.0f, 0.0f, alpha * 0.5f);
      glBegin(GL_QUADS);
      glVertex2f(width * 0.1f, height * 0.9f);
      glVertex2f(width * 0.9f, height * 0.9f);
      glVertex2f(width * 0.9f, height * 0.85f);
      glVertex2f(width * 0.1f, height * 0.85f);
      glEnd();

      glColor4f(1.0f, 1.0f, 1.0f, alpha);
      glRasterPos2f(width * 0.15f, height * 0.88f);
      glDisable(GL_BLEND);

      glPopMatrix();
      glMatrixMode(GL_PROJECTION);
      glPopMatrix();
    }
  }

  void run() {
    XEvent event;

    while (running) {
      // Handle events (non-blocking)
      while (XPending(display) > 0) {
        XNextEvent(display, &event);
        handleEvent(event);
      }

      // Check for shader hot-reload
      checkForShaderChanges();

      // Check for auto-switch
      auto now = std::chrono::steady_clock::now();
      float shaderTime =
          std::chrono::duration<float>(now - shaderStartTime).count();

      if (shaderTime > timePerShader && !inTransition) {
        goToNextShader();
        shaderStartTime = now;
      }

      // Update transition
      if (inTransition) {
        transitionProgress =
            std::chrono::duration<float>(now - transitionStart).count() /
            transitionDuration;
        if (transitionProgress >= 1.0f) {
          currentShader = nextShader;
          nextShader = nullptr;
          inTransition = false;
          transitionProgress = 0.0f;
        }
      }

      render();

      // Frame rate limiting based on target FPS
      auto &config = ::ShaderCandy::Config::ConfigurationManager::getInstance();
      int targetFPS = config.getSettings().targetFPS;
      if (targetFPS <= 0)
        targetFPS = 60; // Safety fallback
      uint32_t frameDelayMs = 1000 / targetFPS;
      usleep(frameDelayMs * 1000); // Convert milliseconds to microseconds
    }
  }

  void cleanup() {
    for (auto *shader : shaders) {
      delete shader;
    }
    shaders.clear();

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

    if (context) {
      glXMakeCurrent(display, None, nullptr);
      glXDestroyContext(display, context);
      context = nullptr;
    }

    if (window) {
      XDestroyWindow(display, window);
      window = 0;
    }

    if (colormap) {
      XFreeColormap(display, colormap);
      colormap = 0;
    }

    if (display) {
      XCloseDisplay(display);
      display = nullptr;
    }
  }

private:
  bool showDebug = false;

  void handleEvent(const XEvent &event) {
    switch (event.type) {
    case KeyPress:
      // Right arrow = next shader
      if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) == XK_Right) {
        goToNextShader();
        shaderStartTime = std::chrono::steady_clock::now();
      }
      // Left arrow = previous shader
      else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) ==
               XK_Left) {
        goToPreviousShader();
        shaderStartTime = std::chrono::steady_clock::now();
      }
      // Space or P = next shader
      else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) ==
                   XK_space ||
               XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) == XK_p) {
        goToNextShader();
        shaderStartTime = std::chrono::steady_clock::now();
      }
      // N = previous shader
      else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) == XK_n) {
        goToPreviousShader();
        shaderStartTime = std::chrono::steady_clock::now();
      }
      // D = toggle debug overlay
      else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) == XK_d) {
        showDebug = !showDebug;
        showNotification(showDebug ? "Debug: ON" : "Debug: OFF");
      }
      // T = run shader test suite
      else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) == XK_t) {
        showNotification("Test suite: " + std::to_string(shaders.size()) +
                         " shaders OK");
      }
      // F12 or PrintScreen = screenshot
      else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) ==
                   XK_F12 ||
               XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) ==
                   XK_Print) {
        takeScreenshot();
      }
      // 1-4: Adjust params
      else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) == XK_1) {
        shaderParams.param1 = std::max(0.0f, shaderParams.param1 - 0.1f);
        showNotification("param1: " + std::to_string(shaderParams.param1));
      } else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) ==
                 XK_exclam) {
        shaderParams.param1 = std::min(1.0f, shaderParams.param1 + 0.1f);
        showNotification("param1: " + std::to_string(shaderParams.param1));
      } else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) ==
                 XK_2) {
        shaderParams.param2 = std::max(0.0f, shaderParams.param2 - 0.1f);
        showNotification("param2: " + std::to_string(shaderParams.param2));
      } else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) ==
                 XK_at) {
        shaderParams.param2 = std::min(1.0f, shaderParams.param2 + 0.1f);
        showNotification("param2: " + std::to_string(shaderParams.param2));
      } else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) ==
                 XK_3) {
        shaderParams.param3 = std::max(0.0f, shaderParams.param3 - 0.1f);
        showNotification("param3: " + std::to_string(shaderParams.param3));
      } else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) ==
                 XK_numbersign) {
        shaderParams.param3 = std::min(1.0f, shaderParams.param3 + 0.1f);
        showNotification("param3: " + std::to_string(shaderParams.param3));
      } else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) ==
                 XK_4) {
        shaderParams.param4 = std::max(0.0f, shaderParams.param4 - 0.1f);
        showNotification("param4: " + std::to_string(shaderParams.param4));
      } else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) ==
                 XK_dollar) {
        shaderParams.param4 = std::min(1.0f, shaderParams.param4 + 0.1f);
        showNotification("param4: " + std::to_string(shaderParams.param4));
      } else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) ==
                 XK_5) {
        shaderParams.colorPalette = (shaderParams.colorPalette + 1) % 8;
        showNotification("palette: " +
                         std::to_string(shaderParams.colorPalette));
      }
      // Ctrl+S = save preset
      else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) == XK_s &&
               event.xkey.state & ControlMask) {
        savePreset("default");
      }
      // Ctrl+O = load preset
      else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) == XK_o &&
               event.xkey.state & ControlMask) {
        loadPreset("default");
      }
      // Ctrl+Plus/Minus = intensity
      else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) ==
                   XK_equal &&
               event.xkey.state & ControlMask && currentShader) {
        currentShader->uniforms.intensity =
            std::min(2.0f, currentShader->uniforms.intensity + 0.1f);
        showNotification("intensity: " +
                         std::to_string(currentShader->uniforms.intensity));
      } else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) ==
                     XK_minus &&
                 event.xkey.state & ControlMask && currentShader) {
        currentShader->uniforms.intensity =
            std::max(0.0f, currentShader->uniforms.intensity - 0.1f);
        showNotification("intensity: " +
                         std::to_string(currentShader->uniforms.intensity));
      }
      // Tab = switch display
      else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) ==
               XK_Tab) {
        goToNextDisplay();
      }
      // ESC or Q = quit
      else if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) ==
                   XK_Escape ||
               XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) == XK_q) {
        running = false;
      }
      break;
    case ButtonPress:
      running = false;
      break;
    case MotionNotify:
      mouseX = static_cast<float>(event.xmotion.x);
      mouseY =
          static_cast<float>(height - event.xmotion.y); // Flip Y for OpenGL
      break;
    case ConfigureNotify:
      width = event.xconfigure.width;
      height = event.xconfigure.height;
      glViewport(0, 0, width, height);
      break;
    }
  }

  void render() {
    glClear(GL_COLOR_BUFFER_BIT);

    if (!currentShader || !currentShader->program) {
      std::cerr << "Render: No current shader or program (currentShader="
                << (currentShader ? "valid" : "null")
                << ", program=" << (currentShader ? currentShader->program : 0)
                << ")" << std::endl;
      glXSwapBuffers(display, window);
      return;
    }

    static int frameCount = 0;
    if (frameCount++ < 10) {
      std::cerr << "Render: Drawing with shader '" << currentShader->name
                << "' (program=" << currentShader->program << ")" << std::endl;
    }

    // Get current audio data if available
    const AudioData *audioData = nullptr;
    AudioData currentAudio;
    if (audioInput && audioInput->isRunning()) {
      currentAudio = audioInput->getCurrentData();
      audioData = &currentAudio;
    }

    if (currentShader && currentShader->program) {
      glBindVertexArray(vao);

      // Check for OpenGL errors
      GLenum error = glGetError();
      if (error != GL_NO_ERROR) {
        std::cerr << "Render: OpenGL error before drawing: " << error
                  << std::endl;
      }

      if (inTransition && nextShader && nextShader->program) {
        float alpha1 = 1.0f - transitionProgress;
        float alpha2 = transitionProgress;

        currentShader->use();
        currentShader->uniforms.alpha = alpha1;
        currentShader->updateUniforms(width, height, mouseX, mouseY, mouseBtns,
                                      audioData);
        glDrawArrays(GL_TRIANGLES, 0, 6);

        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        nextShader->use();
        nextShader->uniforms.alpha = alpha2;
        nextShader->updateUniforms(width, height, mouseX, mouseY, mouseBtns,
                                   audioData);
        glDrawArrays(GL_TRIANGLES, 0, 6);

        glDisable(GL_BLEND);
      } else {
        currentShader->use();
        currentShader->uniforms.alpha = 1.0f;
        currentShader->updateUniforms(width, height, mouseX, mouseY, mouseBtns,
                                      audioData);
        glDrawArrays(GL_TRIANGLES, 0, 6);
      }

      // Check for OpenGL errors after drawing
      error = glGetError();
      if (error != GL_NO_ERROR) {
        std::cerr << "Render: OpenGL error after drawing: " << error
                  << std::endl;
      }
    }

    glXSwapBuffers(display, window);
  }
};

void printUsage(const char *program) {
  std::cout << "ShaderCandy Linux Screensaver\n"
            << "Usage: " << program << " [options]\n"
            << "Options:\n"
            << "  -shader <name>       Start with specific shader\n"
            << "  -shader-dir <path>   Add shader directory\n"
            << "  -window-id <id>      Run in existing window\n"
            << "  -root                Run on root window\n"
            << "  -audio               Enable audio reactivity\n"
            << "\nControls:\n"
            << "  Right Arrow          Next shader\n"
            << "  ESC or Q             Quit\n"
            << "  Mouse Click          Quit\n";
}

int main(int argc, char **argv) {
  if (argc > 1 &&
      (strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0)) {
    printUsage(argv[0]);
    return 0;
  }

  X11Screensaver saver;

  if (!saver.initialize(argc, argv)) {
    std::cerr << "Failed to initialize screensaver" << std::endl;
    return 1;
  }

  saver.run();

  return 0;
}
