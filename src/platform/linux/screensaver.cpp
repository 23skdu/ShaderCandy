#include "GLSLWrapper.h"
#include "LinuxStubs.h"
#include "GLLoader.h"
#ifdef __linux__
#include <GL/gl.h>
#include <GL/glext.h>
#include <GL/glx.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#endif

#include <algorithm>
#include <chrono>
#include <csignal>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
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
struct AudioData {
    float volume = 0.0f;
    float bass = 0.0f;
    float mid = 0.0f;
    float treble = 0.0f;
    float beat = 0.0f;
    std::vector<float> spectrum;
};
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
}
}
using namespace ShaderCandy::Audio;
#endif

// Extended Uniforms matching common.glsl and ShaderInterop.h
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

  // Audio data (from ShaderInterop.h)
  float volume;
  float bass;
  float mid;
  float treble;
  float beat;
  float audioData[256];

  // Performance metrics
  float gpuTime;
  float cpuTime;
  float fps;
};

// Shader program with full UBO support
class GLShaderProgram {
public:
  GLuint program = 0;
  GLuint vertexShader = 0;
  GLuint fragmentShader = 0;
  GLuint ubo = 0;

  Uniforms uniforms;
  int frameCount = 0;
  std::chrono::steady_clock::time_point startTime;
  std::chrono::steady_clock::time_point lastFrame;
  std::string name;

  ~GLShaderProgram() { cleanup(); }

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

    // Create UBO
    glGenBuffers(1, &ubo);
    glBindBuffer(GL_UNIFORM_BUFFER, ubo);
    glBufferData(GL_UNIFORM_BUFFER, sizeof(Uniforms), nullptr, GL_DYNAMIC_DRAW);

    GLuint blockIndex = glGetUniformBlockIndex(program, "Uniforms");
    if (blockIndex != GL_INVALID_INDEX) {
      glUniformBlockBinding(program, blockIndex, 0);
    }

    // Initialize uniforms
    uniforms.speed = 1.0f;
    uniforms.intensity = 1.0f;
    uniforms.alpha = 1.0f;
    uniforms.gravity = 1.0f;
    uniforms.mouseButtons = 0.0f;

    startTime = std::chrono::steady_clock::now();
    lastFrame = startTime;

    return true;
  }

  std::string loadShaderWithIncludes(const char *path, int depth = 0) {
    if (depth > 10) {
      std::cerr << "Include depth exceeded for: " << path << std::endl;
      return "";
    }

    std::ifstream file(path);
    if (!file.is_open()) {
      std::cerr << "Failed to open: " << path << std::endl;
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
    bool inUniformBlock = false;
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
            while (parentDir.length() > 0 &&
                   (parentDir.back() == '/' || parentDir.back() == '\\')) {
              parentDir.pop_back();
            }
            size_t parentSlash = parentDir.find_last_of("/\\");
            if (parentSlash != std::string::npos) {
              parentDir = parentDir.substr(0, parentSlash);
            }
            std::string remainingPath = includePath.substr(3);
            while (remainingPath.substr(0, 3) == "../") {
              size_t slash = parentDir.find_last_of("/\\");
              if (slash != std::string::npos) {
                parentDir = parentDir.substr(0, slash);
              }
              remainingPath = remainingPath.substr(3);
            }
            fullPath = parentDir + "/" + remainingPath;
            std::ifstream testFile(fullPath.c_str());
            if (!testFile.is_open()) {
              std::string altPath = fullPath;
              size_t shadersPos = altPath.find("/shaders/");
              if (shadersPos == std::string::npos) {
                shadersPos = altPath.rfind("/shadercandy/");
                if (shadersPos != std::string::npos) {
                  altPath = altPath.substr(0, shadersPos + 12) + "shaders/" + remainingPath;
                }
              } else {
                altPath = altPath.substr(0, shadersPos + 8) + remainingPath;
              }
              std::ifstream altFile(altPath.c_str());
              if (altFile.is_open()) {
                fullPath = altPath;
              }
            }
          } else if (includePath.substr(0, 2) == "./") {
            fullPath = dir + includePath.substr(2);
          } else {
            fullPath = dir + includePath;
            std::ifstream testFile(fullPath.c_str());
            if (!testFile.is_open()) {
              std::string altPath = fullPath;
              size_t shadersPos = altPath.find("/shaders/");
              if (shadersPos != std::string::npos) {
                altPath = altPath.substr(0, shadersPos + 8) + "/" + includePath;
              } else {
                size_t pos = altPath.rfind("/shadercandy/");
                if (pos != std::string::npos) {
                  altPath = altPath.substr(0, pos + 12) + "shaders/" + includePath;
                }
              }
              std::ifstream altFile(altPath.c_str());
              if (altFile.is_open()) {
                fullPath = altPath;
              }
            }
          }

          std::string includeContent = loadShaderWithIncludes(fullPath.c_str(), depth + 1);
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

  bool loadShaderFromFile(const char *fragmentPath) {
    std::string fragStr = loadShaderWithIncludes(fragmentPath);
    if (fragStr.empty()) {
      return false;
    }

    // Extract shader name from path
    name = fragmentPath;
    size_t lastSlash = name.find_last_of("/\\");
    if (lastSlash != std::string::npos) {
      name = name.substr(lastSlash + 1);
    }
    size_t extPos = name.find_last_of('.');
    if (extPos != std::string::npos) {
      name = name.substr(0, extPos);
    }

    std::string vertexShaderStr = GLSLWrapper::getVertexShader();
    std::string wrappedFrag = "\
#version 450 core\n";
    wrappedFrag += fragStr;

    return loadShader(vertexShaderStr.c_str(), wrappedFrag.c_str());
  }

  void use() {
    glUseProgram(program);
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, ubo);
  }

  void updateUniforms(int width, int height, float mouseX, float mouseY,
                      float mouseBtns, const AudioData *audioData = nullptr) {
    auto now = std::chrono::steady_clock::now();

    uniforms.time = std::chrono::duration<float>(now - startTime).count();
    uniforms.resolution[0] = static_cast<float>(width);
    uniforms.resolution[1] = static_cast<float>(height);
    uniforms.mouse[0] = mouseX / static_cast<float>(width);
    uniforms.mouse[1] = mouseY / static_cast<float>(height);
    uniforms.mouseButtons = mouseBtns;
    uniforms.frame = frameCount++;
    uniforms.deltaTime = std::chrono::duration<float>(now - lastFrame).count();

    time_t t = time(nullptr);
    tm *lt = localtime(&t);
    uniforms.date[0] = static_cast<float>(lt->tm_year + 1900);
    uniforms.date[1] = static_cast<float>(lt->tm_mon + 1);
    uniforms.date[2] = static_cast<float>(lt->tm_mday);
    uniforms.date[3] =
        static_cast<float>(lt->tm_hour * 3600 + lt->tm_min * 60 + lt->tm_sec);

    // Update audio uniforms if audio data is available
    if (audioData) {
      uniforms.volume = audioData->volume;
      uniforms.bass = audioData->bass;
      uniforms.mid = audioData->mid;
      uniforms.treble = audioData->treble;
      uniforms.beat = audioData->beat ? 1.0f : 0.0f;

      // Copy spectrum data (limited to 256 samples)
      int samplesToCopy = std::min(256, (int)audioData->spectrum.size());
      for (int i = 0; i < samplesToCopy; ++i) {
        uniforms.audioData[i] = audioData->spectrum[i];
      }
    }

    glBindBuffer(GL_UNIFORM_BUFFER, ubo);
    glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(Uniforms), &uniforms);

    lastFrame = now;
  }

private:
  GLuint compileShader(GLenum type, const char *source) {
    GLuint shader = glCreateShader(type);
    const char* sources[] = { source };
    glShaderSource(shader, 1, sources, nullptr);
    glCompileShader(shader);

    GLint success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success) {
      char infoLog[512];
      glGetShaderInfoLog(shader, 512, nullptr, infoLog);
      std::cerr << "Shader compile error: " << infoLog << std::endl;
      glDeleteShader(shader);
      return 0;
    }

    return shader;
  }
};

// Enhanced screensaver with shader management
class X11Screensaver {
private:
  Display *display = nullptr;
  Window window = 0;
  GLXContext context = nullptr;

  std::vector<GLShaderProgram *> shaders;
  size_t currentShaderIndex = 0;
  GLShaderProgram *currentShader = nullptr;
  GLShaderProgram *nextShader = nullptr;

  GLuint vao = 0, vbo = 0;
  bool running = true;
  int width = 1920;
  int height = 1080;

  float mouseX = 0.0f;
  float mouseY = 0.0f;
  int mouseBtns = 0;

  // Transition handling
  float transitionProgress = 0.0f;
  bool inTransition = false;
  float transitionDuration = 2.0f;
  std::chrono::steady_clock::time_point transitionStart;
  float timePerShader = 30.0f; // Seconds before auto-switch
  std::chrono::steady_clock::time_point shaderStartTime;

  // Shader directories
  std::vector<std::string> shaderPaths;
  std::string shaderDir;

  // Audio input
  AudioInput *audioInput = nullptr;
  bool enableAudio = false;

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

    for (int i = 1; i < argc; i++) {
      if (strcmp(argv[i], "-window-id") == 0 && i + 1 < argc) {
        parent = strtoul(argv[i + 1], nullptr, 0);
      } else if (strcmp(argv[i], "-root") == 0) {
        // Run on root window
      } else if (strcmp(argv[i], "-shader") == 0 && i + 1 < argc) {
        initialShader = argv[++i];
      } else if (strcmp(argv[i], "-shader-dir") == 0 && i + 1 < argc) {
        addShaderDirectory(argv[++i]);
      } else if (strcmp(argv[i], "-audio") == 0) {
        enableAudio = true;
      }
    }

    // Default shader directories
    if (shaderPaths.empty()) {
      addShaderDirectory("/usr/share/shadercandy/shaders");
      addShaderDirectory("/usr/local/share/shadercandy/shaders");
      addShaderDirectory("/home/rsd/.local/share/shadercandy/shaders");
      // Also add base directory for includes
      addShaderDirectory("/home/rsd/.local/share/shadercandy");
      addShaderDirectory("./shaders");
      addShaderDirectory("./shaders/effects");
      addShaderDirectory("../shaders");
      addShaderDirectory("../shaders/effects");
      addShaderDirectory("../shaders/base");
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
    XWindowAttributes parentAttr;
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
    Colormap cmap = XCreateColormap(display, parent, vi->visual, AllocNone);

    XSetWindowAttributes swa;
    swa.colormap = cmap;
    swa.event_mask = ExposureMask | KeyPressMask | ButtonPressMask |
                     PointerMotionMask | StructureNotifyMask;

    window =
        XCreateWindow(display, parent, 0, 0, width, height, 0, vi->depth,
                      InputOutput, vi->visual, CWColormap | CWEventMask, &swa);

    XMapWindow(display, window);
    XFlush(display);
    
    // Wait for window to be mapped
    XSync(display, False);
    
    XWindowAttributes winAttr;
    for (int i = 0; i < 10; i++) {
      XGetWindowAttributes(display, window, &winAttr);
      if (winAttr.map_state == IsViewable) break;
      usleep(10000);
    }
    
    std::cerr << "ShaderCandy: Window " << std::hex << window << std::dec 
              << " ready (" << winAttr.width << "x" << winAttr.height << ")" << std::endl;

    XRaiseWindow(display, window);
    XFlush(display);

    context =
        glXCreateNewContext(display, fbc[0], GLX_RGBA_TYPE, nullptr, True);
    if (!context) {
      std::cerr << "Failed to create OpenGL context" << std::endl;
      return false;
    }

    glXMakeCurrent(display, window, context);

    // Initialize OpenGL function pointers
    if (!InitializeGLLoader()) {
      std::cerr << "Failed to initialize OpenGL function pointers" << std::endl;
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
    
    // Try to use glob if available, otherwise use simple approach
    #ifdef __linux__
    std::string cmd = "find " + dir + " -maxdepth 2 -name '*.frag' 2>/dev/null";
    FILE *fp = popen(cmd.c_str(), "r");
    if (fp) {
        char buf[512];
        while (fgets(buf, sizeof(buf), fp)) {
            std::string path(buf);
            path = path.substr(0, path.find_last_of("\n\r"));
            shaderFiles.push_back(path);
        }
        pclose(fp);
    }
    #endif
    
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

  void loadShader(const std::string &path) {
    auto *shader = new GLShaderProgram();
    if (shader->loadShaderFromFile(path.c_str())) {
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

  void run() {
    XEvent event;

    while (running) {
      // Handle events (non-blocking)
      while (XPending(display) > 0) {
        XNextEvent(display, &event);
        handleEvent(event);
      }

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
      usleep(16000); // ~60fps
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

    if (display) {
      XCloseDisplay(display);
      display = nullptr;
    }
  }

private:
  void handleEvent(const XEvent &event) {
    switch (event.type) {
    case KeyPress:
      // Right arrow = next shader
      if (XLookupKeysym(const_cast<XKeyEvent *>(&event.xkey), 0) == XK_Right) {
        goToNextShader();
        shaderStartTime = std::chrono::steady_clock::now();
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
      glXSwapBuffers(display, window);
      return;
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
