#pragma once

#include <GL/glew.h>
#include <GLFW/glfw3.h>
#include <vector>
#include <string>
#include <chrono>
#include <thread>
#include <fstream>
#include <sstream>
#include <iostream>
#include <cstring>
#include <sys/stat.h>
#include <algorithm>
#include <thread>

// Forward declarations
class AudioInput;
struct AudioData;

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
    
    // Audio data
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

    // User settings
    float speed = 1.0f;
    float intensity = 1.0f;
    float timeScale = 1.0f;
    bool showHelp = false;
    bool showStats = true;
    bool autoReload = false;
    bool paused = false;

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
    void reloadCurrentShader();
    void updateUniforms();
    void renderText(const std::string& text, float x, float y, float scale);

    static void keyCallback(GLFWwindow* window, int key, int scancode, int action, int mods);
    static void mouseButtonCallback(GLFWwindow* window, int button, int action, int mods);
    static void cursorPosCallback(GLFWwindow* window, double xpos, double ypos);
    static void scrollCallback(GLFWwindow* window, double xoffset, double yoffset);
    static void charCallback(GLFWwindow* window, unsigned int codepoint);

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