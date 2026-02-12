// Enhanced Linux OpenGL Screensaver for ShaderCandy
// Supports multiple shaders, transitions, and full uniform compatibility
#define GL_GLEXT_PROTOTYPES

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#include <GL/glx.h>
#include <GL/gl.h>
#include <GL/glext.h>
#include <cstring>
#include <cstdlib>
#include <unistd.h>
#include <csignal>
#include <chrono>
#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <string>
#include <algorithm>
#include <sys/stat.h>

// Extended Uniforms matching common.glsl
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
    
    ~GLShaderProgram() {
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
    
    bool loadShaderFromFile(const char* fragmentPath) {
        std::ifstream fragFile(fragmentPath);
        if (!fragFile.is_open()) {
            std::cerr << "Failed to open shader: " << fragmentPath << std::endl;
            return false;
        }
        
        std::stringstream fragStream;
        fragStream << fragFile.rdbuf();
        std::string fragStr = fragStream.str();
        
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
        
        std::string wrappedFrag = R"(#version 330 core
            in vec2 vTexCoord;
            in vec2 vScreenPos;
            out vec4 fragColor;
            
            layout(std140) uniform Uniforms {
                float time;
                float speed;
                vec2 resolution;
                vec2 mouse;
                float mouseButtons;
                float intensity;
                vec4 date;
                int frame;
                float deltaTime;
                float alpha;
                float gravity;
            };
            
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
        
        return loadShader(vertexSource, wrappedFrag.c_str());
    }
    
    void use() {
        glUseProgram(program);
        glBindBufferBase(GL_UNIFORM_BUFFER, 0, ubo);
    }
    
    void updateUniforms(int width, int height, float mouseX, float mouseY, float mouseBtns) {
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
        tm* lt = localtime(&t);
        uniforms.date[0] = static_cast<float>(lt->tm_year + 1900);
        uniforms.date[1] = static_cast<float>(lt->tm_mon + 1);
        uniforms.date[2] = static_cast<float>(lt->tm_mday);
        uniforms.date[3] = static_cast<float>(lt->tm_hour * 3600 + lt->tm_min * 60 + lt->tm_sec);
        
        glBindBuffer(GL_UNIFORM_BUFFER, ubo);
        glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(Uniforms), &uniforms);
        
        lastFrame = now;
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
    Display* display = nullptr;
    Window window = 0;
    GLXContext context = nullptr;
    
    std::vector<GLShaderProgram*> shaders;
    size_t currentShaderIndex = 0;
    GLShaderProgram* currentShader = nullptr;
    GLShaderProgram* nextShader = nullptr;
    
    GLuint vao = 0, vbo = 0;
    bool running = true;
    int width = 1920;
    int height = 1080;
    
    float mouseX = 0.0f;
    float mouseY = 0.0f;
    float mouseBtns = 0.0f;
    
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
    
public:
    X11Screensaver() = default;
    ~X11Screensaver() {
        cleanup();
    }
    
    void addShaderDirectory(const std::string& dir) {
        shaderPaths.push_back(dir);
    }
    
    bool initialize(int argc, char** argv) {
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
            }
        }
        
        // Default shader directories
        if (shaderPaths.empty()) {
            addShaderDirectory("/usr/share/shadercandy/shaders");
            addShaderDirectory("/usr/local/share/shadercandy/shaders");
            addShaderDirectory("./shaders");
            addShaderDirectory("./shaders/effects");
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
        static int visualAttribs[] = {
            GLX_X_RENDERABLE    , True,
            GLX_DRAWABLE_TYPE   , GLX_WINDOW_BIT,
            GLX_RENDER_TYPE     , GLX_RGBA_BIT,
            GLX_X_VISUAL_TYPE   , GLX_TRUE_COLOR,
            GLX_RED_SIZE        , 8,
            GLX_GREEN_SIZE      , 8,
            GLX_BLUE_SIZE       , 8,
            GLX_ALPHA_SIZE      , 8,
            GLX_DEPTH_SIZE      , 24,
            GLX_STENCIL_SIZE    , 8,
            None
        };
        
        int fbcount;
        GLXFBConfig* fbc = glXChooseFBConfig(display, screen, visualAttribs, &fbcount);
        if (!fbc || fbcount < 1) {
            std::cerr << "Failed to get framebuffer config" << std::endl;
            return false;
        }
        
        XVisualInfo* vi = glXGetVisualFromFBConfig(display, fbc[0]);
        Colormap cmap = XCreateColormap(display, parent, vi->visual, AllocNone);
        
        XSetWindowAttributes swa;
        swa.colormap = cmap;
        swa.event_mask = ExposureMask | KeyPressMask | ButtonPressMask | 
                        PointerMotionMask | StructureNotifyMask;
        
        window = XCreateWindow(display, parent, 0, 0, width, height, 0,
                              vi->depth, InputOutput, vi->visual,
                              CWColormap | CWEventMask, &swa);
        
        XMapWindow(display, window);
        
        context = glXCreateNewContext(display, fbc[0], GLX_RGBA_TYPE, nullptr, True);
        if (!context) {
            std::cerr << "Failed to create OpenGL context" << std::endl;
            return false;
        }
        
        glXMakeCurrent(display, window, context);
        
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
        
        return true;
    }
    
    void discoverShaders() {
        for (const auto& dir : shaderPaths) {
            scanShaderDirectory(dir);
        }
    }
    
    void scanShaderDirectory(const std::string& dir) {
        std::vector<std::string> extensions = {".frag", ".glsl"};
        
        // Try to load shaders from directory
        std::vector<std::string> shaderFiles = {
            "nebula.frag",
            "mandelbrot_set.frag",
            "julia_set.frag",
            "mandelbulb_3d.frag",
            "julia_3d.frag",
            "starfield_warp.frag",
            "voronoi_cells.frag",
            "neon_pulse.frag",
            "kaleidoscopic_tunnel.frag",
            "reaction_diffusion.frag",
            "fractal_zoom.frag",
            "liquid_gradient.frag",
            "bloom.frag",
            "raymarch_sculpture.frag",
            "dna_helix.frag",
            "quantum_field.frag",
            "fluid_dynamics.frag",
            "audio_spectrum.frag",
            "plasma.frag",
            "tunnel.frag",
            "spiral.frag",
            "ripples.frag",
            "checkerboard.frag",
            "gradient_waves.frag",
            "flying_toasters.frag"
        };
        
        for (const auto& file : shaderFiles) {
            std::string fullPath = dir + "/" + file;
            struct stat buffer;
            if (stat(fullPath.c_str(), &buffer) == 0) {
                loadShader(fullPath);
            }
        }
    }
    
    void loadShader(const std::string& path) {
        auto* shader = new GLShaderProgram();
        if (shader->loadShaderFromFile(path.c_str())) {
            shaders.push_back(shader);
            std::cout << "Loaded shader: " << shader->name << std::endl;
        } else {
            delete shader;
        }
    }
    
    void createFallbackShader() {
        auto* shader = new GLShaderProgram();
        const char* vert = R"(#version 330 core
            layout(location = 0) in vec2 aPos;
            void main() { gl_Position = vec4(aPos, 0.0, 1.0); }
        )";
        const char* frag = R"(#version 330 core
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
    
    void selectShaderByName(const std::string& name) {
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
        if (shaders.size() <= 1) return;
        
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
            float shaderTime = std::chrono::duration<float>(now - shaderStartTime).count();
            
            if (shaderTime > timePerShader && !inTransition) {
                goToNextShader();
                shaderStartTime = now;
            }
            
            // Update transition
            if (inTransition) {
                transitionProgress = std::chrono::duration<float>(now - transitionStart).count() / transitionDuration;
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
        for (auto* shader : shaders) {
            delete shader;
        }
        shaders.clear();
        
        if (vbo) { glDeleteBuffers(1, &vbo); vbo = 0; }
        if (vao) { glDeleteVertexArrays(1, &vao); vao = 0; }
        
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
    void handleEvent(const XEvent& event) {
        switch (event.type) {
            case KeyPress:
                // Right arrow = next shader
                if (XLookupKeysym(const_cast<XKeyEvent*>(&event.xkey), 0) == XK_Right) {
                    goToNextShader();
                    shaderStartTime = std::chrono::steady_clock::now();
                }
                // ESC or Q = quit
                else if (XLookupKeysym(const_cast<XKeyEvent*>(&event.xkey), 0) == XK_Escape ||
                         XLookupKeysym(const_cast<XKeyEvent*>(&event.xkey), 0) == XK_q) {
                    running = false;
                }
                break;
            case ButtonPress:
                running = false;
                break;
            case MotionNotify:
                mouseX = static_cast<float>(event.xmotion.x);
                mouseY = static_cast<float>(height - event.xmotion.y); // Flip Y for OpenGL
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
        
        if (currentShader && currentShader->program) {
            if (inTransition && nextShader && nextShader->program) {
                // Render transition between shaders
                float alpha1 = 1.0f - transitionProgress;
                float alpha2 = transitionProgress;
                
                // Render current shader
                currentShader->use();
                currentShader->uniforms.alpha = alpha1;
                currentShader->updateUniforms(width, height, mouseX, mouseY, mouseBtns);
                glDrawArrays(GL_TRIANGLES, 0, 6);
                
                // Render next shader with blending
                glEnable(GL_BLEND);
                glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
                
                nextShader->use();
                nextShader->uniforms.alpha = alpha2;
                nextShader->updateUniforms(width, height, mouseX, mouseY, mouseBtns);
                glDrawArrays(GL_TRIANGLES, 0, 6);
                
                glDisable(GL_BLEND);
            } else {
                // Normal rendering
                currentShader->use();
                currentShader->uniforms.alpha = 1.0f;
                currentShader->updateUniforms(width, height, mouseX, mouseY, mouseBtns);
                glDrawArrays(GL_TRIANGLES, 0, 6);
            }
        }
        
        glXSwapBuffers(display, window);
    }
};

void printUsage(const char* program) {
    std::cout << "ShaderCandy Linux Screensaver\n"
              << "Usage: " << program << " [options]\n"
              << "Options:\n"
              << "  -shader <name>       Start with specific shader\n"
              << "  -shader-dir <path>   Add shader directory\n"
              << "  -window-id <id>      Run in existing window\n"
              << "  -root                Run on root window\n"
              << "\nControls:\n"
              << "  Right Arrow          Next shader\n"
              << "  ESC or Q             Quit\n"
              << "  Mouse Click          Quit\n";
}

int main(int argc, char** argv) {
    if (argc > 1 && (strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0)) {
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
