#include "GLRenderer.h"

#include <iostream>
#include <fstream>
#include <sstream>
#include <cmath>
#include <ctime>
#include <sys/stat.h>

#if defined(__APPLE__)
    #include <OpenGL/gl3.h>
    #define GL_PROFILE "3.3"
#elif defined(__linux__)
    #include <GL/gl.h>
    #include <GL/glew.h>
    #define GL_PROFILE "3.3"
#else
    #include <GL/gl.h>
    #define GL_PROFILE "3.3"
#endif

#include "../platform/linux/GLSLWrapper.h"

namespace ShaderCandy {
namespace Platform {
namespace Linux {

GLRenderer::GLRenderer() = default;

GLRenderer::~GLRenderer() {
    shutdown();
}

bool GLRenderer::initialize(void* display, void* window, bool isGLES) {
    if (initialized_) {
        return true;
    }

    display_ = display;
    window_ = window;
    isGLES_ = isGLES;

    glVersion_ = "4.6";
    glslVersion_ = isGLES_ ? "300 es" : "330 core";

    setupQuad();

    initialized_ = true;
    return true;
}

void GLRenderer::shutdown() {
    if (!initialized_) {
        return;
    }

    for (auto& program : shaderPrograms_) {
        if (program.second) {
            glDeleteProgram(program.second);
        }
    }
    shaderPrograms_.clear();

    if (bloomProgram_) {
        glDeleteProgram(bloomProgram_);
    }

    if (fbo_) {
        glDeleteFramebuffers(1, &fbo_);
    }
    if (fboTexture_) {
        glDeleteTextures(1, &fboTexture_);
    }
    if (rbo_) {
        glDeleteRenderbuffers(1, &rbo_);
    }

    if (vao_) {
        glDeleteVertexArrays(1, &vao_);
    }
    if (vbo_) {
        glDeleteBuffers(1, &vbo_);
    }

    initialized_ = false;
}

std::string GLRenderer::getGLVersion() const {
    return glVersion_;
}

std::string GLRenderer::getGLSLVersion() const {
    return glslVersion_;
}

void GLRenderer::setupQuad() {
    float vertices[] = {
        -1.0f, -1.0f, 0.0f, 0.0f,
         1.0f, -1.0f, 1.0f, 0.0f,
         1.0f,  1.0f, 1.0f, 1.0f,
        -1.0f,  1.0f, 0.0f, 1.0f
    };

    unsigned int indices[] = { 0, 1, 2, 0, 2, 3 };

    glGenVertexArrays(1, &vao_);
    glGenBuffers(1, &vbo_);

    glBindVertexArray(vao_);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));

    unsigned int ebo;
    glGenBuffers(1, &ebo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);

    glBindVertexArray(0);
}

unsigned int GLRenderer::compileShader(const std::string& source, unsigned int type) {
    unsigned int shader = glCreateShader(type);
    const char* src = source.c_str();
    glShaderSource(shader, 1, &src, nullptr);
    glCompileShader(shader);

    int success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);

    if (!success) {
        char infoLog[512];
        glGetShaderInfoLog(shader, 512, nullptr, infoLog);
        setError(GLRendererErrorCode::ShaderCompilationFailed,
                 "Shader compilation failed: " + std::string(infoLog),
                 "", infoLog);
        glDeleteShader(shader);
        return 0;
    }

    return shader;
}

unsigned int GLRenderer::linkProgram(unsigned int vs, unsigned int fs) {
    unsigned int program = glCreateProgram();
    glAttachShader(program, vs);
    glAttachShader(program, fs);
    glLinkProgram(program);

    int success;
    glGetProgramiv(program, GL_LINK_STATUS, &success);

    if (!success) {
        char infoLog[512];
        glGetProgramInfoLog(program, 512, nullptr, infoLog);
        setError(GLRendererErrorCode::ProgramLinkFailed,
                 "Program linking failed: " + std::string(infoLog), "", infoLog);
        glDeleteProgram(program);
        return 0;
    }

    return program;
}

std::string GLRenderer::loadShaderSource(const std::string& path) {
    std::ifstream file(path);
    if (!file.is_open()) {
        return "";
    }

    std::stringstream buffer;
    buffer << file.rdbuf();
    return buffer.str();
}

bool GLRenderer::loadShader(const std::string& name, const std::string& path) {
    std::string source = loadShaderSource(path);
    if (source.empty()) {
        setError(GLRendererErrorCode::ShaderCompilationFailed,
                 "Failed to load shader file: " + path, name);
        return false;
    }

    std::string preamble = GLSLWrapper::getPreamble(isGLES_);
    std::string vertSrc = GLSLWrapper::getVertexShader(isGLES_);
    std::string fragSrc = preamble + source;

    unsigned int vs = compileShader(vertSrc, GL_VERTEX_SHADER);
    unsigned int fs = compileShader(fragSrc, GL_FRAGMENT_SHADER);

    if (!vs || !fs) {
        if (vs) glDeleteShader(vs);
        if (fs) glDeleteShader(fs);
        return false;
    }

    unsigned int program = linkProgram(vs, fs);
    glDeleteShader(vs);
    glDeleteShader(fs);

    if (!program) {
        return false;
    }

    if (shaderPrograms_.count(name)) {
        glDeleteProgram(shaderPrograms_[name]);
    }

    shaderPrograms_[name] = program;

    struct stat st;
    if (stat(path.c_str(), &st) == 0) {
        shaderModTimes_[name] = st.st_mtime;
    }

    return true;
}

bool GLRenderer::reloadCurrentShader() {
    if (currentShader_.empty()) {
        return false;
    }

    auto it = shaderPrograms_.find(currentShader_);
    if (it == shaderPrograms_.end()) {
        return false;
    }

    return true;
}

std::vector<std::string> GLRenderer::availableShaderNames() const {
    std::vector<std::string> names;
    for (const auto& shader : shaderPrograms_) {
        names.push_back(shader.first);
    }
    return names;
}

bool GLRenderer::setActiveShader(const std::string& name) {
    auto it = shaderPrograms_.find(name);
    if (it == shaderPrograms_.end()) {
        setError(GLRendererErrorCode::InvalidState,
                 "Shader not found: " + name, name);
        return false;
    }

    currentShader_ = name;
    currentProgram_ = it->second;

    uniformsLocation_ = glGetUniformBlockIndex(currentProgram_, "Uniforms");

    return true;
}

void GLRenderer::render(float time) {
    if (!initialized_ || currentProgram_ == 0) {
        return;
    }

    double currentTime = clock() / (double)CLOCKS_PER_SEC;
    if (lastFrameTime_ > 0) {
        double delta = currentTime - lastFrameTime_;
        metrics_.frameTimeMs = delta * 1000.0;
        metrics_.currentFPS = 1.0 / delta;

        fpsAccumulator_ += metrics_.currentFPS;
        frameCount_++;

        if (frameCount_ >= 60) {
            metrics_.averageFPS = fpsAccumulator_ / frameCount_;
            fpsAccumulator_ = 0.0;
            frameCount_ = 0;
        }
    }
    lastFrameTime_ = currentTime;

    uniforms_.time = time;
    uniforms_.frame++;

    glUseProgram(currentProgram_);

    if (uniformsLocation_ >= 0) {
        glUniformBlockBinding(currentProgram_, uniformsLocation_, 0);
    }

    auto locTime = glGetUniformLocation(currentProgram_, "time");
    auto locSpeed = glGetUniformLocation(currentProgram_, "speed");
    auto locIntensity = glGetUniformLocation(currentProgram_, "intensity");
    auto locResolution = glGetUniformLocation(currentProgram_, "resolution");
    auto locMouse = glGetUniformLocation(currentProgram_, "mouse");
    auto locMouseButtons = glGetUniformLocation(currentProgram_, "mouseButtons");
    auto locAlpha = glGetUniformLocation(currentProgram_, "alpha");
    auto locGravity = glGetUniformLocation(currentProgram_, "gravity");

    if (locTime >= 0) glUniform1f(locTime, uniforms_.time);
    if (locSpeed >= 0) glUniform1f(locSpeed, uniforms_.speed);
    if (locIntensity >= 0) glUniform1f(locIntensity, uniforms_.intensity);
    if (locResolution >= 0) glUniform2f(locResolution, uniforms_.resolution.x, uniforms_.resolution.y);
    if (locMouse >= 0) glUniform2f(locMouse, uniforms_.mouse.x, uniforms_.mouse.y);
    if (locMouseButtons >= 0) glUniform1i(locMouseButtons, (int)uniforms_.mouseButtons);
    if (locAlpha >= 0) glUniform1f(locAlpha, uniforms_.alpha);
    if (locGravity >= 0) glUniform1f(locGravity, uniforms_.gravity);

    if (audioReactivityEnabled_) {
        auto locVolume = glGetUniformLocation(currentProgram_, "volume");
        auto locBass = glGetUniformLocation(currentProgram_, "bass");
        auto locMid = glGetUniformLocation(currentProgram_, "mid");
        auto locTreble = glGetUniformLocation(currentProgram_, "treble");
        auto locBeat = glGetUniformLocation(currentProgram_, "beat");
        
        if (locVolume >= 0) glUniform1f(locVolume, uniforms_.volume);
        if (locBass >= 0) glUniform1f(locBass, uniforms_.bass);
        if (locMid >= 0) glUniform1f(locMid, uniforms_.mid);
        if (locTreble >= 0) glUniform1f(locTreble, uniforms_.treble);
        if (locBeat >= 0) glUniform1f(locBeat, uniforms_.beat);
    }

    glBindVertexArray(vao_);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    glBindVertexArray(0);

    glUseProgram(0);
}

void GLRenderer::resize(int width, int height) {
    if (width > 0 && height > 0) {
        metrics_.memoryUsageBytes = width * height * 4;
        uniforms_.resolution[0] = (float)width;
        uniforms_.resolution[1] = (float)height;
    }
}

void GLRenderer::setMouse(float x, float y, int buttons) {
    uniforms_.mouse[0] = x;
    uniforms_.mouse[1] = y;
    uniforms_.mouseButtons = (float)buttons;
}

void GLRenderer::setAudioData(float volume, float bass, float mid, float treble, float beat) {
    uniforms_.volume = volume;
    uniforms_.bass = bass;
    uniforms_.mid = mid;
    uniforms_.treble = treble;
    uniforms_.beat = beat;
}

void GLRenderer::setBloomEnabled(bool enabled) {
    bloomConfig_.enabled = enabled;
}

void GLRenderer::setBloomQuality(GLBloomQuality quality) {
    bloomConfig_.quality = quality;
}

void GLRenderer::setBloomIntensity(float intensity) {
    bloomConfig_.intensity = intensity;
}

void GLRenderer::setBloomThreshold(float threshold) {
    bloomConfig_.threshold = threshold;
}

void GLRenderer::setParticlesEnabled(bool enabled) {
}

void GLRenderer::setParticleCount(int count) {
}

void GLRenderer::setParticleGravity(float gravity) {
}

void GLRenderer::setToneMapping(GLToneMapping toneMapping) {
    toneMapping_ = toneMapping;
}

GLPerformanceMetrics GLRenderer::getMetrics() {
    return metrics_;
}

void GLRenderer::resetMetrics() {
    metrics_ = GLPerformanceMetrics();
    fpsAccumulator_ = 0.0;
    frameCount_ = 0;
    lastFrameTime_ = 0.0;
}

void GLRenderer::checkForShaderReload() {
    if (!hotReloadEnabled_ || currentShader_.empty()) {
        return;
    }
}

void GLRenderer::setError(GLRendererErrorCode code, const std::string& msg,
                          const std::string& shader, const std::string& compileError) {
    lastError_ = {code, msg, shader, compileError, 0};
}

} // namespace Linux
} // namespace Platform
} // namespace ShaderCandy
