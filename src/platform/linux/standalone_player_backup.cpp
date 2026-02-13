// ShaderCandy Linux Standalone Player
// A windowed application for browsing and viewing shaders

#define GL_GLEXT_PROTOTYPES

#include <GLFW/glfw3.h>
#include <GL/gl.h>
#include <GL/glext.h>
#include <iostream>
#include <vector>
#include <string>
#include <algorithm>
#include <chrono>
#include <thread>
#include <cstring>
#include <sys/stat.h>
#include <fstream>
#include <sstream>

// Audio support
#include "AudioInput.h"
using namespace ShaderCandy::Audio;

// Uniform structure matching ShaderInterop.h
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

// Simple shader program class
class ShaderProgram {
public:
    GLuint program = 0;
    GLuint ubo = 0;
    Uniforms uniforms;
    std::string name;
    std::string path;
    int frameCount = 0;
    std::chrono::steady_clock::time_point startTime;
    std::chrono::steady_clock::time_point lastFrame;

    ~ShaderProgram() { cleanup(); }

    void cleanup() {
        if (program) { glDeleteProgram(program); program = 0; }
        if (ubo) { glDeleteBuffers(1, &ubo); ubo = 0; }
    }

    bool loadFromFile(const char* fragmentPath);
    void use();
    void updateUniforms(int width, int height, float mouseX, float mouseY,
                        float mouseBtns, const AudioData* audioData);

private:
    std::string loadWithIncludes(const char* path, int depth = 0);
    bool compile(const char* fragmentSource);
};

// Standalone player application
class StandalonePlayer {
public:
    GLFWwindow* window = nullptr;
    std::vector<ShaderProgram*> shaders;
    size_t currentShaderIndex = 0;
    ShaderProgram* currentShader = nullptr;

    GLuint vao = 0, vbo = 0;
    bool running = true;
    int width = 1280;
    int height = 720;
    bool fullscreen = false;

    float mouseX = 0.0f;
    float mouseY = 0.0f;
    float mouseBtns = 0.0f;

    // Audio
    AudioInput* audioInput = nullptr;
    bool enableAudio = false;

    // Performance
    float currentFPS = 60.0f;
    std::chrono::steady_clock::time_point lastFrameTime;

    bool initialize(int argc, char** argv);
    void run();
    void cleanup();
    void loadShaders();
    void nextShader();
    void previousShader();
    void selectShader(size_t index);
    void toggleFullscreen();
    void render();
    void updateFPS();

    static void keyCallback(GLFWwindow* window, int key, int scancode, int action, int mods);
    static void mouseButtonCallback(GLFWwindow* window, int button, int action, int mods);
    static void cursorPosCallback(GLFWwindow* window, double xpos, double ypos);
    static void scrollCallback(GLFWwindow* window, double xoffset, double yoffset);
    static void framebufferSizeCallback(GLFWwindow* window, int w, int h);

    // Window state for fullscreen toggle
    static int windowedX;
    static int windowedY;
    static int windowedWidth;
    static int windowedHeight;
};

// Static member definitions
int StandalonePlayer::windowedX = 100;
int StandalonePlayer::windowedY = 100;
int StandalonePlayer::windowedWidth = 1280;
int StandalonePlayer::windowedHeight = 720;

// Shader loading implementation
std::string ShaderProgram::loadWithIncludes(const char* path, int depth) {
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
                    if (parentDir.length() > 0 && (parentDir.back() == '/' || parentDir.back() == '\\')) {
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

                std::string includeContent = loadWithIncludes(fullPath.c_str(), depth + 1);
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

bool ShaderProgram::compile(const char* fragmentSource) {
    const char* vertexSource = R"(#version 330 core
        layout(location = 0) in vec2 aPos;
        layout(location = 1) in vec2 aTex;
        out vec2 vTexCoord;
        out vec2 vScreenPos;
        void main() {
            gl_Position = vec4(aPos, 0.0, 1.0);
            vTexCoord = aTex;
            vScreenPos = aPos;
        }
    )";

    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexSource, nullptr);
    glCompileShader(vertexShader);

    GLint success;
    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
    if (!success) {
        char infoLog[512];
        glGetShaderInfoLog(vertexShader, 512, nullptr, infoLog);
        std::cerr << "Vertex shader error: " << infoLog << std::endl;
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
        std::cerr << "Fragment shader error: " << infoLog << std::endl;
        glDeleteShader(vertexShader);
        glDeleteShader(fragmentShader);
        return false;
    }

    program = glCreateProgram();
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    glLinkProgram(program);

    glGetProgramiv(program, GL_LINK_STATUS, &success);
    if (!success) {
        char infoLog[512];
        glGetProgramInfoLog(program, 512, nullptr, infoLog);
        std::cerr << "Shader link error: " << infoLog << std::endl;
        glDeleteProgram(program);
        glDeleteShader(vertexShader);
        glDeleteShader(fragmentShader);
        program = 0;
        return false;
    }

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    // Create UBO
    glGenBuffers(1, &ubo);
    glBindBuffer(GL_UNIFORM_BUFFER, ubo);
    glBufferData(GL_UNIFORM_BUFFER, sizeof(Uniforms), nullptr, GL_DYNAMIC_DRAW);

    GLuint blockIndex = glGetUniformBlockIndex(program, "Uniforms");
    if (blockIndex != GL_INVALID_INDEX) {
        glUniformBlockBinding(program, blockIndex, 0);
    }

    // Initialize defaults
    uniforms.speed = 1.0f;
    uniforms.intensity = 1.0f;
    uniforms.alpha = 1.0f;
    uniforms.gravity = 1.0f;
    uniforms.mouseButtons = 0.0f;

    startTime = std::chrono::steady_clock::now();
    lastFrame = startTime;

    return true;
}

bool ShaderProgram::loadFromFile(const char* fragmentPath) {
    path = fragmentPath;
    std::string fragStr = loadWithIncludes(fragmentPath);
    if (fragStr.empty()) {
        return false;
    }

    // Extract name
    name = fragmentPath;
    size_t lastSlash = name.find_last_of("/\\");
    if (lastSlash != std::string::npos) {
        name = name.substr(lastSlash + 1);
    }
    size_t extPos = name.find_last_of('.');
    if (extPos != std::string::npos) {
        name = name.substr(0, extPos);
    }

    // Wrap with common utilities
    std::string wrappedFrag = R"(#version 330 core
        in vec2 vTexCoord;
        in vec2 vScreenPos;
        out vec4 fragColor;

        #define PI 3.14159265359
        #define TWO_PI 6.28318530718

        float hash(float n) { return fract(sin(n) * 43758.5453123); }
        float fract(float x) { return x - floor(x); }
        vec2 fract(vec2 x) { return x - floor(x); }
        vec3 fract(vec3 x) { return x - floor(x); }
        vec4 fract(vec4 x) { return x - floor(x); }

        vec2 hash2(vec2 p) {
            vec3 p3 = fract(vec3(p.xyx) * 0.1031);
            p3 += dot(p3, p3.yzx + 33.33);
            return fract((p3.xx + p3.yz) * p3.zy);
        }

        vec3 hash3(vec2 p) {
            vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
            p3 += dot(p3, p3.yxz + 33.33);
            return fract((p3.xxy + p3.yzz) * p3.zyx);
        }

        vec3 hsv2rgb(vec3 c) {
            vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
            vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
            return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
        }

        vec3 rgb2hsv(vec3 c) {
            vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
            vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
            vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
            float d = q.x - min(q.w, q.y);
            float e = 1.0e-10;
            return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
        }

        vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
        vec4 mod289(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
        vec4 permute(vec4 x) { return mod289(((x * 34.0) + 1.0) * x); }
        vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

        float snoise(vec3 v) {
            const vec2 C = vec2(1.0/6.0, 1.0/3.0);
            const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
            vec3 i = floor(v + dot(v, C.yyy));
            vec3 x0 = v - i + dot(i, C.xxx);
            vec3 g = step(x0.yzx, x0.xyz);
            vec3 l = 1.0 - g;
            vec3 i1 = min(g.xyz, l.zxy);
            vec3 i2 = max(g.xyz, l.zxy);
            vec3 x1 = x0 - i1 + C.xxx;
            vec3 x2 = x0 - i2 + C.yyy;
            vec3 x3 = x0 - D.yyy;
            i = mod289(i);
            vec4 p = permute(permute(permute(
                i.z + vec4(0.0, i1.z, i2.z, 1.0))
                + i.y + vec4(0.0, i1.y, i2.y, 1.0))
                + i.x + vec4(0.0, i1.x, i2.x, 1.0));
            float n_ = 0.142857142857;
            vec3 ns = n_ * D.wyz - D.xzx;
            vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
            vec4 x_ = floor(j * ns.z);
            vec4 y_ = floor(j - 7.0 * x_);
            vec4 x = x_ * ns.x + ns.yyyy;
            vec4 y = y_ * ns.x + ns.yyyy;
            vec4 h = 1.0 - abs(x) - abs(y);
            vec4 b0 = vec4(x.xy, y.xy);
            vec4 b1 = vec4(x.zw, y.zw);
            vec4 s0 = floor(b0) * 2.0 + 1.0;
            vec4 s1 = floor(b1) * 2.0 + 1.0;
            vec4 sh = -step(h, vec4(0.0));
            vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
            vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
            vec3 p0 = vec3(a0.xy, h.x);
            vec3 p1 = vec3(a0.zw, h.y);
            vec3 p2 = vec3(a1.xy, h.z);
            vec3 p3 = vec3(a1.zw, h.w);
            vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
            p0 *= norm.x;
            p1 *= norm.y;
            p2 *= norm.z;
            p3 *= norm.w;
            vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
            m = m * m;
            return 42.0 * dot(m*m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
        }

        float fbm(vec3 x, int octaves) {
            float v = 0.0;
            float a = 0.5;
            vec3 shift = vec3(100.0);
            for (int i = 0; i < octaves; ++i) {
                v += a * snoise(x);
                x = x * 2.0 + shift;
                a *= 0.5;
            }
            return v;
        }

        float sdSphere(vec3 p, float r) { return length(p) - r; }
        float sdBox(vec3 p, vec3 b) {
            vec3 d = abs(p) - b;
            return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
        }
        float sdTorus(vec3 p, vec2 t) {
            vec2 q = vec2(length(p.xz) - t.x, p.y);
            return length(q) - t.y;
        }
        float opUnion(float d1, float d2) { return min(d1, d2); }
        float opSubtraction(float d1, float d2) { return max(-d1, d2); }
        float opIntersection(float d1, float d2) { return max(d1, d2); }
        float opSmoothUnion(float d1, float d2, float k) {
            float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
            return mix(d2, d1, h) - k * h * (1.0 - h);
        }
        vec3 rotateX(vec3 p, float a) {
            float s = sin(a), c = cos(a);
            return vec3(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
        }
        vec3 rotateY(vec3 p, float a) {
            float s = sin(a), c = cos(a);
            return vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
        }
        vec3 rotateZ(vec3 p, float a) {
            float s = sin(a), c = cos(a);
            return vec3(c * p.x - s * p.y, s * p.x + c * p.y, p.z);
        }
    )";

    wrappedFrag += fragStr;

    return compile(wrappedFrag.c_str());
}

void ShaderProgram::use() {
    glUseProgram(program);
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, ubo);
}

void ShaderProgram::updateUniforms(int width, int height, float mouseX, float mouseY,
                                   float mouseBtns, const AudioData* audioData) {
    auto now = std::chrono::steady_clock::now();

    uniforms.time = std::chrono::duration<float>(now - startTime).count();
    uniforms.resolution[0] = static_cast<float>(width);
    uniforms.resolution[1] = static_cast<float>(height);
    uniforms.mouse[0] = mouseX / static_cast<float>(width);
    uniforms.mouse[1] = 1.0f - (mouseY / static_cast<float>(height)); // Flip Y for OpenGL
    uniforms.mouseButtons = mouseBtns;
    uniforms.frame = frameCount++;
    uniforms.deltaTime = std::chrono::duration<float>(now - lastFrame).count();

    time_t t = time(nullptr);
    tm* lt = localtime(&t);
    uniforms.date[0] = static_cast<float>(lt->tm_year + 1900);
    uniforms.date[1] = static_cast<float>(lt->tm_mon + 1);
    uniforms.date[2] = static_cast<float>(lt->tm_mday);
    uniforms.date[3] = static_cast<float>(lt->tm_hour * 3600 + lt->tm_min * 60 + lt->tm_sec);

    if (audioData) {
        uniforms.volume = audioData->volume;
        uniforms.bass = audioData->bass;
        uniforms.mid = audioData->mid;
        uniforms.treble = audioData->treble;
        uniforms.beat = audioData->beat ? 1.0f : 0.0f;

        int samplesToCopy = std::min(256, (int)audioData->spectrum.size());
        for (int i = 0; i < samplesToCopy; ++i) {
            uniforms.audioData[i] = audioData->spectrum[i];
        }
    }

    glBindBuffer(GL_UNIFORM_BUFFER, ubo);
    glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(Uniforms), &uniforms);

    lastFrame = now;
}

// Player implementation
bool StandalonePlayer::initialize(int argc, char** argv) {
    // Parse arguments
    std::string initialShader;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-shader") == 0 && i + 1 < argc) {
            initialShader = argv[++i];
        } else if (strcmp(argv[i], "-fullscreen") == 0) {
            fullscreen = true;
        } else if (strcmp(argv[i], "-audio") == 0) {
            enableAudio = true;
        } else if (strcmp(argv[i], "-width") == 0 && i + 1 < argc) {
            width = atoi(argv[++i]);
        } else if (strcmp(argv[i], "-height") == 0 && i + 1 < argc) {
            height = atoi(argv[++i]);
        }
    }

    // Initialize GLFW
    if (!glfwInit()) {
        std::cerr << "Failed to initialize GLFW" << std::endl;
        return false;
    }

    // Configure OpenGL
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    // Create window
    GLFWmonitor* monitor = fullscreen ? glfwGetPrimaryMonitor() : nullptr;
    window = glfwCreateWindow(width, height, "ShaderCandy Player", monitor, nullptr);
    if (!window) {
        std::cerr << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return false;
    }

    glfwMakeContextCurrent(window);
    glfwSwapInterval(1); // Enable vsync

    // Set callbacks
    glfwSetWindowUserPointer(window, this);
    glfwSetKeyCallback(window, keyCallback);
    glfwSetMouseButtonCallback(window, mouseButtonCallback);
    glfwSetCursorPosCallback(window, cursorPosCallback);
    glfwSetScrollCallback(window, scrollCallback);
    glfwSetFramebufferSizeCallback(window, framebufferSizeCallback);

    // Initialize OpenGL
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glDisable(GL_DEPTH_TEST);

    // Create fullscreen quad
    float vertices[] = {
        -1.0f, -1.0f,  0.0f, 0.0f,
         1.0f, -1.0f,  1.0f, 0.0f,
        -1.0f,  1.0f,  0.0f, 1.0f,
        -1.0f,  1.0f,  0.0f, 1.0f,
         1.0f, -1.0f,  1.0f, 0.0f,
         1.0f,  1.0f,  1.0f, 1.0f
    };

    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);

    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));
    glEnableVertexAttribArray(1);

    // Load shaders
    loadShaders();

    if (shaders.empty()) {
        std::cerr << "No shaders found!" << std::endl;
        glfwDestroyWindow(window);
        glfwTerminate();
        return false;
    }

    // Select initial shader
    if (!initialShader.empty()) {
        for (size_t i = 0; i < shaders.size(); i++) {
            if (shaders[i]->name == initialShader) {
                selectShader(i);
                break;
            }
        }
    }
    if (!currentShader) {
        selectShader(0);
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

    lastFrameTime = std::chrono::steady_clock::now();

    std::cout << "ShaderCandy Player initialized" << std::endl;
    std::cout << "Loaded " << shaders.size() << " shaders" << std::endl;
    std::cout << "Controls:" << std::endl;
    std::cout << "  Arrow Keys    - Change shader" << std::endl;
    std::cout << "  F             - Toggle fullscreen" << std::endl;
    std::cout << "  Space         - Pause/Resume" << std::endl;
    std::cout << "  ESC           - Quit" << std::endl;

    return true;
}

void StandalonePlayer::loadShaders() {
    std::vector<std::string> shaderPaths = {
        "./shaders",
        "./shaders/effects",
        "/usr/share/shadercandy/shaders",
        "/usr/local/share/shadercandy/shaders"
    };

    std::vector<std::string> shaderFiles = {
        "nebula.frag", "mandelbrot_set.frag", "julia_set.frag",
        "mandelbulb_3d.frag", "julia_3d.frag", "starfield_warp.frag",
        "voronoi_cells.frag", "neon_pulse.frag", "kaleidoscopic_tunnel.frag",
        "reaction_diffusion.frag", "fractal_zoom.frag", "liquid_gradient.frag",
        "bloom.frag", "raymarch_sculpture.frag", "dna_helix.frag",
        "quantum_field.frag", "fluid_dynamics.frag", "audio_spectrum.frag",
        "plasma.frag", "tunnel.frag", "spiral.frag", "ripples.frag",
        "checkerboard.frag", "gradient_waves.frag", "flying_toasters.frag"
    };

    for (const auto& dir : shaderPaths) {
        for (const auto& file : shaderFiles) {
            std::string fullPath = dir + "/" + file;
            struct stat buffer;
            if (stat(fullPath.c_str(), &buffer) == 0) {
                ShaderProgram* shader = new ShaderProgram();
                if (shader->loadFromFile(fullPath.c_str())) {
                    shaders.push_back(shader);
                } else {
                    delete shader;
                }
            }
        }
    }
}

void StandalonePlayer::run() {
    while (!glfwWindowShouldClose(window) && running) {
        glfwPollEvents();
        updateFPS();
        render();
        glfwSwapBuffers(window);
    }
}

void StandalonePlayer::updateFPS() {
    auto now = std::chrono::steady_clock::now();
    float deltaTime = std::chrono::duration<float>(now - lastFrameTime).count();
    lastFrameTime = now;

    if (deltaTime > 0) {
        float fps = 1.0f / deltaTime;
        currentFPS = currentFPS * 0.9f + fps * 0.1f; // Smooth FPS
    }
}

void StandalonePlayer::render() {
    glClear(GL_COLOR_BUFFER_BIT);

    if (currentShader) {
        const AudioData* audioData = nullptr;
        AudioData currentAudio;
        if (audioInput && audioInput->isRunning()) {
            currentAudio = audioInput->getCurrentData();
            audioData = &currentAudio;
        }

        currentShader->use();
        currentShader->uniforms.alpha = 1.0f;
        currentShader->updateUniforms(width, height, mouseX, mouseY, mouseBtns, audioData);
        glDrawArrays(GL_TRIANGLES, 0, 6);
    }
}

void StandalonePlayer::cleanup() {
    for (auto* shader : shaders) {
        delete shader;
    }
    shaders.clear();

    if (audioInput) {
        delete audioInput;
        audioInput = nullptr;
    }

    if (vbo) glDeleteBuffers(1, &vbo);
    if (vao) glDeleteVertexArrays(1, &vao);

    if (window) {
        glfwDestroyWindow(window);
        window = nullptr;
    }

    glfwTerminate();
}

void StandalonePlayer::nextShader() {
    if (shaders.size() <= 1) return;
    selectShader((currentShaderIndex + 1) % shaders.size());
}

void StandalonePlayer::previousShader() {
    if (shaders.size() <= 1) return;
    selectShader((currentShaderIndex + shaders.size() - 1) % shaders.size());
}

void StandalonePlayer::selectShader(size_t index) {
    if (index >= shaders.size()) return;
    currentShaderIndex = index;
    currentShader = shaders[index];
    std::cout << "Selected shader: " << currentShader->name << std::endl;

    // Update window title
    std::string title = "ShaderCandy Player - " + currentShader->name +
                       " (" + std::to_string(index + 1) + "/" + std::to_string(shaders.size()) + ")";
    glfwSetWindowTitle(window, title.c_str());
}

void StandalonePlayer::toggleFullscreen() {
    fullscreen = !fullscreen;

    GLFWmonitor* monitor = glfwGetWindowMonitor(window);
    if (fullscreen) {
        // Save windowed position and size
        glfwGetWindowPos(window, &windowedX, &windowedY);
        glfwGetWindowSize(window, &windowedWidth, &windowedHeight);

        // Get primary monitor
        monitor = glfwGetPrimaryMonitor();
        const GLFWvidmode* mode = glfwGetVideoMode(monitor);
        glfwSetWindowMonitor(window, monitor, 0, 0, mode->width, mode->height, mode->refreshRate);
    } else {
        glfwSetWindowMonitor(window, nullptr, windowedX, windowedY, windowedWidth, windowedHeight, 0);
    }
}

// Static callbacks
void StandalonePlayer::keyCallback(GLFWwindow* window, int key, int scancode, int action, int mods) {
    if (action != GLFW_PRESS) return;

    StandalonePlayer* player = static_cast<StandalonePlayer*>(glfwGetWindowUserPointer(window));
    if (!player) return;

    switch (key) {
        case GLFW_KEY_ESCAPE:
            glfwSetWindowShouldClose(window, GLFW_TRUE);
            break;
        case GLFW_KEY_RIGHT:
        case GLFW_KEY_DOWN:
            player->nextShader();
            break;
        case GLFW_KEY_LEFT:
        case GLFW_KEY_UP:
            player->previousShader();
            break;
        case GLFW_KEY_F:
        case GLFW_KEY_F11:
            player->toggleFullscreen();
            break;
        case GLFW_KEY_SPACE:
            // Pause/Resume by toggling speed
            if (player->currentShader) {
                if (player->currentShader->uniforms.speed > 0.1f) {
                    player->currentShader->uniforms.speed = 0.0f;
                } else {
                    player->currentShader->uniforms.speed = 1.0f;
                }
            }
            break;
        case GLFW_KEY_R:
            // Reload current shader
            if (player->currentShader) {
                std::string path = player->currentShader->path;
                std::string name = player->currentShader->name;
                if (player->currentShader->loadFromFile(path.c_str())) {
                    player->currentShader->name = name;
                    std::cout << "Reloaded shader: " << name << std::endl;
                }
            }
            break;
    }
}

void StandalonePlayer::mouseButtonCallback(GLFWwindow* window, int button, int action, int mods) {
    StandalonePlayer* player = static_cast<StandalonePlayer*>(glfwGetWindowUserPointer(window));
    if (!player) return;

    if (button == GLFW_MOUSE_BUTTON_LEFT) {
        if (action == GLFW_PRESS) {
            player->mouseBtns |= 1;
        } else if (action == GLFW_RELEASE) {
            player->mouseBtns &= ~1;
        }
    } else if (button == GLFW_MOUSE_BUTTON_RIGHT) {
        if (action == GLFW_PRESS) {
            player->mouseBtns |= 2;
        } else if (action == GLFW_RELEASE) {
            player->mouseBtns &= ~2;
        }
    }
}

void StandalonePlayer::cursorPosCallback(GLFWwindow* window, double xpos, double ypos) {
    StandalonePlayer* player = static_cast<StandalonePlayer*>(glfwGetWindowUserPointer(window));
    if (!player) return;

    player->mouseX = static_cast<float>(xpos);
    player->mouseY = static_cast<float>(ypos);
}

void StandalonePlayer::scrollCallback(GLFWwindow* window, double xoffset, double yoffset) {
    StandalonePlayer* player = static_cast<StandalonePlayer*>(glfwGetWindowUserPointer(window));
    if (!player) return;

    if (yoffset > 0) {
        player->nextShader();
    } else if (yoffset < 0) {
        player->previousShader();
    }
}

void StandalonePlayer::framebufferSizeCallback(GLFWwindow* window, int w, int h) {
    StandalonePlayer* player = static_cast<StandalonePlayer*>(glfwGetWindowUserPointer(window));
    if (!player) return;

    player->width = w;
    player->height = h;
    glViewport(0, 0, w, h);
}

// Main entry point
void printUsage(const char* program) {
    std::cout << "ShaderCandy Linux Player\n"
              << "Usage: " << program << " [options]\n"
              << "Options:\n"
              << "  -shader <name>     Start with specific shader\n"
              << "  -fullscreen        Start in fullscreen mode\n"
              << "  -audio             Enable audio reactivity\n"
              << "  -width <w>         Window width (default: 1280)\n"
              << "  -height <h>        Window height (default: 720)\n"
              << "\nControls:\n"
              << "  Arrow Keys        - Change shader\n"
              << "  Mouse Wheel       - Change shader\n"
              << "  F / F11           - Toggle fullscreen\n"
              << "  Space             - Pause/Resume animation\n"
              << "  R                 - Reload current shader\n"
              << "  ESC               - Quit\n";
}

int main(int argc, char** argv) {
    if (argc > 1 && (strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0)) {
        printUsage(argv[0]);
        return 0;
    }

    StandalonePlayer player;

    if (!player.initialize(argc, argv)) {
        std::cerr << "Failed to initialize player" << std::endl;
        return 1;
    }

    player.run();
    player.cleanup();

    return 0;
}
