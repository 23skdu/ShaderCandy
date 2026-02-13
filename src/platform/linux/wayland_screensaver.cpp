// Linux Wayland Screensaver for ShaderCandy
// Supports sway, GNOME, KDE Plasma, and other wlroots-based compositors

#include <wayland-client.h>
#include <wayland-egl.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>

#include <cstring>
#include <cstdlib>
#include <csignal>
#include <chrono>
#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <string>
#include <algorithm>
#include <functional>
#include <mutex>
#include <thread>
#include <atomic>
#include <dirent.h>
#include <sys/stat.h>

// Try to include wlroots, but make it optional
#ifdef WLR_FOUND
#include <wlr/util/log.h>
#include <wlr/backend.h>
#include <wlr/backend/session.h>
#include <wlr/render/allocator.h>
#include <wlr/render/wlr_renderer.h>
#include <wlr/types/wlr_output.h>
#include <wlr/types/wlr_input_device.h>
#include <wlr/types/wlr_keyboard.h>
#include <wlr/types/wlr_pointer.h>
#include <wlr/types/wlr_layer_shell_v1.h>
#include <wlr/types/wlr_xdg_shell.h>
#endif

// Audio support
#include "AudioInput.h"
using namespace ShaderCandy::Audio;

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
    
    Uniforms uniforms;
    int frameCount = 0;
    std::chrono::steady_clock::time_point startTime;
    std::chrono::steady_clock::time_point lastFrame;
    std::string name;
    
    ~GLESShaderProgram() {
        cleanup();
    }
    
    void cleanup() {
        if (program) { glDeleteProgram(program); program = 0; }
        if (vertexShader) { glDeleteShader(vertexShader); vertexShader = 0; }
        if (fragmentShader) { glDeleteShader(fragmentShader); fragmentShader = 0; }
        if (ubo) { glDeleteBuffers(1, &ubo); ubo = 0; }
    }
    
    bool loadShader(const char* vertexSource, const char* fragmentSource) {
        vertexShader = compileShader(GL_VERTEX_SHADER, vertexSource);
        if (!vertexShader) return false;
        
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
    
    std::string loadShaderWithIncludes(const char* path, int depth = 0) {
        if (depth > 10) return "";
        
        std::ifstream file(path);
        if (!file.is_open()) return "";
        
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
                    std::string included = loadShaderWithIncludes(includePath.c_str(), depth + 1);
                    buffer << included << "\n";
                }
            } else {
                buffer << line << "\n";
            }
        }
        
        return buffer.str();
    }
    
    bool loadFromFile(const char* path) {
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
    
    bool loadSingleFile(const char* path) {
        std::ifstream file(path);
        if (!file.is_open()) return false;
        
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
                // Assume it's a fragment shader, wrap with vertex
                fragSource = source;
                vertSource = R"(
                    #version 300 es
                    precision highp float;
                    in vec2 position;
                    out vec2 uv;
                    void main() {
                        uv = position * 0.5 + 0.5;
                        gl_Position = vec4(position, 0.0, 1.0);
                    }
                )";
            }
        } else {
            // Legacy single shader
            fragSource = R"(
                #version 300 es
                precision highp float;
                in vec2 position;
                out vec2 uv;
                void main() {
                    uv = position * 0.5 + 0.5;
                    gl_Position = vec4(position, 0.0, 1.0);
                }
            )" + source;
        }
        
        return loadShader(vertSource.c_str(), fragSource.c_str());
    }
    
    void update(float deltaTime, int width, int height, float mouseX, float mouseY) {
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
    GLuint compileShader(GLenum type, const char* source) {
        GLuint shader = glCreateShader(type);
        glShaderSource(shader, 1, &source, nullptr);
        glCompileShader(shader);
        
        GLint success;
        glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
        if (!success) {
            char infoLog[512];
            glGetShaderInfoLog(shader, 512, nullptr, infoLog);
            std::cerr << "Shader compile error (" << (type == GL_VERTEX_SHADER ? "vertex" : "fragment") 
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
static GLESShaderProgram* g_shader = nullptr;
static float g_mouseX = 0, g_mouseY = 0;
static int g_width = 1920, g_height = 1080;
static EGLDisplay g_eglDisplay = EGL_NO_DISPLAY;
static EGLSurface g_eglSurface = EGL_NO_SURFACE;
static EGLContext g_eglContext = EGL_NO_CONTEXT;
static std::unique_ptr<AudioInput> g_audioInput;

// Wayland globals
static struct wl_display* g_wlDisplay = nullptr;
static struct wl_registry* g_wlRegistry = nullptr;
static struct wl_compositor* g_wlCompositor = nullptr;
static struct wl_subcompositor* g_wlSubcompositor = nullptr;
static struct xdg_wm_base* g_xdgWmBase = nullptr;
static struct zwlr_layer_shell_v1* g_layerShell = nullptr;
static struct wl_output* g_wlOutput = nullptr;

static void handleGlobal(void* data, struct wl_registry* registry, uint32_t name, const char* interface, uint32_t version) {
    if (strcmp(interface, wl_compositor_interface.name) == 0) {
        g_wlCompositor = (wl_compositor*)wl_registry_bind(registry, name, &wl_compositor_interface, 4);
    } else if (strcmp(interface, wl_subcompositor_interface.name) == 0) {
        g_wlSubcompositor = (wl_subcompositor*)wl_registry_bind(registry, name, &wl_subcompositor_interface, 1);
    } else if (strcmp(interface, xdg_wm_base_interface.name) == 0) {
        g_xdgWmBase = (xdg_wm_base*)wl_registry_bind(registry, name, &xdg_wm_base_interface, 1);
    } else if (strcmp(interface, zwlr_layer_shell_v1_interface.name) == 0) {
        g_layerShell = (zwlr_layer_shell_v1*)wl_registry_bind(registry, name, &zwlr_layer_shell_v1_interface, 4);
    } else if (strcmp(interface, wl_output_interface.name) == 0) {
        g_wlOutput = (wl_output*)wl_registry_bind(registry, name, &wl_output_interface, 2);
    }
}

static void handleGlobalRemove(void* data, struct wl_registry* registry, uint32_t name) {
}

static const struct wl_registry_listener registryListener = {
    .global = handleGlobal,
    .global_remove = handleGlobalRemove
};

static bool initEGL(WaylandOutput* output) {
    // Get EGL extensions
    const char* clientExtensions = eglQueryString(EGL_NO_DISPLAY, EGL_EXTENSIONS);
    
    // Initialize EGL
    PFNEGLGETPLATFORMDISPLAYEXTPROC eglGetPlatformDisplay = 
        (PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");
    
    if (eglGetPlatformDisplay && clientExtensions && 
        strstr(clientExtensions, "EGL_EXT_platform_wayland")) {
        g_eglDisplay = eglGetPlatformDisplay(EGL_PLATFORM_WAYLAND_EXT, 
                                             (void*)g_wlDisplay, nullptr);
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
    EGLint configAttribs[] = {
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
        EGL_DEPTH_SIZE, 0,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
        EGL_NONE
    };
    
    EGLConfig config;
    EGLint numConfigs;
    if (!eglChooseConfig(g_eglDisplay, configAttribs, &config, 1, &numConfigs) || numConfigs == 0) {
        std::cerr << "Failed to choose EGL config" << std::endl;
        return false;
    }
    
    // Bind OpenGL ES
    if (!eglBindAPI(EGL_OPENGL_ES_API)) {
        std::cerr << "Failed to bind OpenGL ES API" << std::endl;
        return false;
    }
    
    // Create context
    EGLint contextAttribs[] = {
        EGL_CONTEXT_CLIENT_VERSION, 2,
        EGL_NONE
    };
    
    g_eglContext = eglCreateContext(g_eglDisplay, config, EGL_NO_CONTEXT, contextAttribs);
    if (g_eglContext == EGL_NO_CONTEXT) {
        std::cerr << "Failed to create EGL context" << std::endl;
        return false;
    }
    
    // Create surface (will be created per-output)
    
    std::cout << "EGL initialized: " << major << "." << minor << std::endl;
    return true;
}

static bool initOpenGLES() {
    glewInit = (PFNGLGETPROCADDRESSARBPROC)eglGetProcAddress;
    
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
    if (!g_shader) return;
    
    glClear(GL_COLOR_BUFFER_BIT);
    
    g_shader->update(1.0f/60.0f, g_width, g_height, g_mouseX, g_mouseY);
    
    glUseProgram(g_shader->program);
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    
    // Draw fullscreen quad
    float vertices[] = {
        -1.0f, -1.0f,
         1.0f, -1.0f,
        -1.0f,  1.0f,
         1.0f,  1.0f
    };
    
    GLint posLoc = glGetAttribLocation(g_shader->program, "position");
    if (posLoc >= 0) {
        glEnableVertexAttribArray(posLoc);
        glVertexAttribPointer(posLoc, 2, GL_FLOAT, GL_FALSE, 0, vertices);
    }
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

static void handleSignal(int signum) {
    g_running = false;
}

static std::vector<std::string> discoverShaders(const std::string& dir) {
    std::vector<std::string> shaders;
    
    // Check various shader directories
    std::vector<std::string> dirs = {
        dir,
        "./shaders",
        "./shaders/effects",
        "/usr/local/share/shadercandy/shaders",
        "/usr/share/shadercandy/shaders"
    };
    
    for (const auto& shaderDir : dirs) {
        DIR* d = opendir(shaderDir.c_str());
        if (!d) continue;
        
        struct dirent* entry;
        while ((entry = readdir(d))) {
            std::string name = entry->d_name;
            if (name.length() > 5 && 
                (name.substr(name.length() - 5) == ".frag" || 
                 name.substr(name.length() - 6) == ".metal" ||
                 name.substr(name.length() - 5) == ".glsl")) {
                shaders.push_back(shaderDir + "/" + name);
            }
        }
        closedir(d);
    }
    
    return shaders;
}

static bool loadShader(const std::string& path) {
    if (g_shader) {
        delete g_shader;
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

static void printUsage(const char* prog) {
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

int main(int argc, char* argv[]) {
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
        std::cerr << "Make sure WAYLAND_DISPLAY is set or running in a Wayland session" << std::endl;
        return 1;
    }
    
    // Get registry
    g_wlRegistry = wl_display_get_registry(g_wlRegistry);
    wl_registry_add_listener(g_wlRegistry, &registryListener, nullptr);
    wl_display_roundtrip(g_wlDisplay);
    
    if (!g_wlCompositor) {
        std::cerr << "No Wayland compositor found" << std::endl;
        return 1;
    }
    
    // Initialize EGL
    if (!initEGL(nullptr)) {
        return 1;
    }
    
    // Initialize OpenGL ES
    if (!initOpenGLES()) {
        return 1;
    }
    
    // List shaders if requested
    if (listShaders) {
        auto shaders = discoverShaders(".");
        std::cout << "Available shaders:\n";
        for (const auto& s : shaders) {
            std::cout << "  " << s << "\n";
        }
        return 0;
    }
    
    // Load initial shader
    if (shaderPath.empty()) {
        // Try default shaders
        std::vector<std::string> defaults = {
            "./shaders/plasma.glsl",
            "./shaders/plasma.frag",
            "./shaders/effects/plasma.glsl",
            "/usr/local/share/shadercandy/shaders/plasma.glsl"
        };
        for (const auto& s : defaults) {
            if (loadShader(s)) break;
        }
    } else {
        loadShader(shaderPath);
    }
    
    if (!g_shader) {
        std::cerr << "Failed to load any shader" << std::endl;
        return 1;
    }
    
    // Main event loop
    while (g_running) {
        // Handle Wayland events
        wl_display_dispatch_pending(g_wlDisplay);
        
        // Render
        renderFrame();
        
        // Swap buffers
        eglSwapBuffers(g_eglDisplay, g_eglSurface);
        
        // Frame rate limiting (~60fps)
        std::this_thread::sleep_for(std::chrono::milliseconds(16));
    }
    
    // Cleanup
    if (g_shader) delete g_shader;
    
    if (g_eglContext != EGL_NO_CONTEXT) {
        eglDestroyContext(g_eglDisplay, g_eglContext);
    }
    if (g_eglSurface != EGL_NO_SURFACE) {
        eglDestroySurface(g_eglDisplay, g_eglSurface);
    }
    if (g_eglDisplay != EGL_NO_DISPLAY) {
        eglTerminate(g_eglDisplay);
    }
    
    if (g_layerShell) zwlr_layer_shell_v1_destroy(g_layerShell);
    if (g_xdgWmBase) xdg_wm_base_destroy(g_xdgWmBase);
    if (g_wlSubcompositor) wl_subcompositor_destroy(g_wlSubcompositor);
    if (g_wlCompositor) wl_compositor_destroy(g_wlCompositor);
    if (g_wlRegistry) wl_registry_destroy(g_wlRegistry);
    if (g_wlDisplay) wl_display_disconnect(g_wlDisplay);
    
    std::cout << "Wayland screensaver terminated" << std::endl;
    return 0;
}
