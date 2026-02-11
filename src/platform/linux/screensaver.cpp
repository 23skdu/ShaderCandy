// Minimal GL function loader for OpenGL 3.3
// In production, use GLEW or GLAD
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

// Simple GL shader program
class GLShaderProgram {
public:
    GLuint program = 0;
    GLuint vertexShader = 0;
    GLuint fragmentShader = 0;
    
    struct Uniforms {
        float time;
        float resolution[2];
        float mouse[2];
        float date[4];
        int frame;
        float deltaTime;
        float padding[2];
    } uniforms;
    
    GLuint ubo = 0;
    int frameCount = 0;
    std::chrono::steady_clock::time_point startTime;
    std::chrono::steady_clock::time_point lastFrame;
    
    ~GLShaderProgram() {
        cleanup();
    }
    
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
        
        // Bind UBO to binding point 0
        GLuint blockIndex = glGetUniformBlockIndex(program, "Uniforms");
        if (blockIndex != GL_INVALID_INDEX) {
            glUniformBlockBinding(program, blockIndex, 0);
        }
        
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
        
        // Simple vertex shader
        const char* vertexSource = R"(#version 330 core
            layout(location = 0) in vec2 aPos;
            layout(location = 1) in vec2 aTex;
            out vec2 vTexCoord;
            void main() {
                gl_Position = vec4(aPos, 0.0, 1.0);
                vTexCoord = aTex;
            }
        )";
        
        // Wrap fragment shader with preamble
        std::string wrappedFrag = R"(#version 330 core
            in vec2 vTexCoord;
            out vec4 fragColor;
            
            layout(std140) uniform Uniforms {
                float time;
                vec2 resolution;
                vec2 mouse;
                vec4 date;
                int frame;
                float deltaTime;
                vec2 padding;
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
            
            vec3 hsv2rgb(vec3 c) {
                vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
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
        )";
        
        wrappedFrag += fragStr;
        
        return loadShader(vertexSource, wrappedFrag.c_str());
    }
    
    void use() {
        glUseProgram(program);
        glBindBufferBase(GL_UNIFORM_BUFFER, 0, ubo);
    }
    
    void updateUniforms(int width, int height) {
        auto now = std::chrono::steady_clock::now();
        
        uniforms.time = std::chrono::duration<float>(now - startTime).count();
        uniforms.resolution[0] = static_cast<float>(width);
        uniforms.resolution[1] = static_cast<float>(height);
        uniforms.frame = frameCount++;
        uniforms.deltaTime = std::chrono::duration<float>(now - lastFrame).count();
        
        // Update date
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

// Simple screensaver class
class X11Screensaver {
private:
    Display* display = nullptr;
    Window window = 0;
    GLXContext context = nullptr;
    GLShaderProgram* shader = nullptr;
    GLuint vao = 0, vbo = 0;
    bool running = true;
    int width = 1920;
    int height = 1080;
    
public:
    X11Screensaver() = default;
    ~X11Screensaver() {
        cleanup();
    }
    
    bool initialize(int argc, char** argv) {
        // Parse arguments
        Window parent = 0;
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "-window-id") == 0 && i + 1 < argc) {
                parent = strtoul(argv[i + 1], nullptr, 0);
            } else if (strcmp(argv[i], "-root") == 0) {
                // Run on root window (preview mode)
            }
        }
        
        // Open display
        display = XOpenDisplay(nullptr);
        if (!display) {
            std::cerr << "Failed to open X display" << std::endl;
            return false;
        }
        
        int screen = DefaultScreen(display);
        
        // Get parent window
        if (!parent) {
            parent = RootWindow(display, screen);
        }
        
        // Get window size
        XWindowAttributes parentAttr;
        XGetWindowAttributes(display, parent, &parentAttr);
        width = parentAttr.width;
        height = parentAttr.height;
        
        // Choose visual
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
        
        // Get visual info
        XVisualInfo* vi = glXGetVisualFromFBConfig(display, fbc[0]);
        
        // Create colormap
        Colormap cmap = XCreateColormap(display, parent, vi->visual, AllocNone);
        
        // Set window attributes
        XSetWindowAttributes swa;
        swa.colormap = cmap;
        swa.event_mask = ExposureMask | KeyPressMask | ButtonPressMask | StructureNotifyMask;
        
        // Create window
        window = XCreateWindow(display, parent, 0, 0, width, height, 0,
                              vi->depth, InputOutput, vi->visual,
                              CWColormap | CWEventMask, &swa);
        
        XMapWindow(display, window);
        
        // Create OpenGL context
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
            // Position    // TexCoord
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
        
        // Load shader
        shader = new GLShaderProgram();
        
        // Try to load default shader
        const char* shaderPath = argc > 1 ? argv[argc - 1] : nullptr;
        if (shaderPath && strstr(shaderPath, ".frag")) {
            shader->loadShaderFromFile(shaderPath);
        } else {
            // Load default nebula shader
            std::ifstream shaderFile("/usr/local/share/shadercandy/shaders/nebula.frag");
            if (!shaderFile.is_open()) {
                // Try local path
                shaderFile.open("./shaders/effects/nebula.frag");
            }
            
            if (shaderFile.is_open()) {
                shaderFile.close();
                shader->loadShaderFromFile("./shaders/effects/nebula.frag");
            } else {
                // Create simple fallback shader
                const char* fallbackFrag = R"(#version 330 core
                    uniform Uniforms { float time; vec2 resolution; };
                    void main() {
                        vec2 uv = gl_FragCoord.xy / resolution;
                        float c = sin(uv.x * 10.0 + time) * sin(uv.y * 10.0 + time);
                        gl_FragColor = vec4(c, c * 0.5, 1.0 - c, 1.0);
                    }
                )";
                const char* fallbackVert = R"(#version 330 core
                    layout(location = 0) in vec2 aPos;
                    void main() { gl_Position = vec4(aPos, 0.0, 1.0); }
                )";
                shader->loadShader(fallbackVert, fallbackFrag);
            }
        }
        
        XFree(fbc);
        XFree(vi);
        
        return true;
    }
    
    void run() {
        XEvent event;
        
        while (running) {
            // Handle events (non-blocking)
            while (XPending(display) > 0) {
                XNextEvent(display, &event);
                handleEvent(event);
            }
            
            // Render
            render();
            
            // Frame rate limit to ~60fps
            usleep(16000);
        }
    }
    
    void cleanup() {
        if (shader) {
            delete shader;
            shader = nullptr;
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
    void handleEvent(const XEvent& event) {
        switch (event.type) {
            case KeyPress:
            case ButtonPress:
                running = false;
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
        
        if (shader && shader->program) {
            shader->use();
            shader->updateUniforms(width, height);
            
            glBindVertexArray(vao);
            glDrawArrays(GL_TRIANGLES, 0, 6);
        }
        
        glXSwapBuffers(display, window);
    }
};

int main(int argc, char** argv) {
    X11Screensaver saver;
    
    if (!saver.initialize(argc, argv)) {
        return 1;
    }
    
    saver.run();
    
    return 0;
}
