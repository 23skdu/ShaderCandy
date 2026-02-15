#include "GLShaderCompiler.h"

#include <fstream>
#include <sstream>

#if defined(__APPLE__)
    #include <OpenGL/gl3.h>
    #define GL_SILENCE_DEPRECATION
#elif defined(__linux__)
    #include <GL/gl.h>
    #include <GL/glext.h>
    #include "../platform/linux/GLLoader.h"
#endif

namespace ShaderCandy {
namespace Platform {
namespace Linux {

GLShaderCompiler::GLShaderCompiler() = default;

GLShaderCompiler::~GLShaderCompiler() {
    shutdown();
}

bool GLShaderCompiler::initialize() {
    if (initialized_) {
        return true;
    }

    preamble_ = R"(
        #version 330 core
        precision highp float;
        
        #define PI 3.14159265359
        #define TWO_PI 6.28318530718
    )";

    initialized_ = true;
    return true;
}

void GLShaderCompiler::shutdown() {
    initialized_ = false;
}

bool GLShaderCompiler::compileFromFile(const std::string& shaderPath, unsigned int& outProgram) {
    std::ifstream file(shaderPath);
    if (!file.is_open()) {
        lastError_ = "Failed to open shader file: " + shaderPath;
        return false;
    }

    std::stringstream buffer;
    buffer << file.rdbuf();
    std::string fragmentSource = buffer.str();

    std::string vertexSource = R"(
        #version 330 core
        layout(location = 0) in vec2 aPos;
        layout(location = 1) in vec2 aTexCoord;
        out vec2 vTexCoord;
        void main() {
            gl_Position = vec4(aPos, 0.0, 1.0);
            vTexCoord = aTexCoord;
        }
    )";

    return compileFromSource(vertexSource, fragmentSource, outProgram);
}

bool GLShaderCompiler::compileFromSource(const std::string& vertexSource,
                                         const std::string& fragmentSource,
                                         unsigned int& outProgram) {
    clearError();

    unsigned int vs = compileShaderSource(vertexSource, GL_VERTEX_SHADER);
    if (!vs) {
        return false;
    }

    std::string fullFragmentSource = preamble_ + "\n" + fragmentSource;
    unsigned int fs = compileShaderSource(fullFragmentSource, GL_FRAGMENT_SHADER);
    if (!fs) {
        glDeleteShader(vs);
        return false;
    }

    outProgram = glCreateProgram();
    glAttachShader(outProgram, vs);
    glAttachShader(outProgram, fs);
    glLinkProgram(outProgram);

    glDeleteShader(vs);
    glDeleteShader(fs);

    if (!checkProgramErrors(outProgram)) {
        return false;
    }

    return true;
}

unsigned int GLShaderCompiler::compileShaderSource(const std::string& source, unsigned int type) {
    unsigned int shader = glCreateShader(type);
    const char* src = source.c_str();
    glShaderSource(shader, 1, &src, nullptr);
    glCompileShader(shader);

    if (!checkShaderErrors(shader)) {
        glDeleteShader(shader);
        return 0;
    }

    return shader;
}

bool GLShaderCompiler::checkShaderErrors(unsigned int shader) {
    int success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);

    if (!success) {
        char infoLog[512];
        glGetShaderInfoLog(shader, 512, nullptr, infoLog);
        lastError_ = "Shader compilation error: " + std::string(infoLog);
        return false;
    }

    return true;
}

bool GLShaderCompiler::checkProgramErrors(unsigned int program) {
    int success;
    glGetProgramiv(program, GL_LINK_STATUS, &success);

    if (!success) {
        char infoLog[512];
        glGetProgramInfoLog(program, 512, nullptr, infoLog);
        lastError_ = "Program linking error: " + std::string(infoLog);
        return false;
    }

    return true;
}

} // namespace Linux
} // namespace Platform
} // namespace ShaderCandy
