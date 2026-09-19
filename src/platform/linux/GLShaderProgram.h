/* This is free and unencumbered software released into the public domain.
   See LICENSE or <https://unlicense.org/> for details. */

#pragma once

#include "GLLoader.h"
#include "GLSLWrapper.h"
#include <chrono>
#include <cstring>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <sys/stat.h>
#include <vector>

namespace ShaderCandy {
namespace Platform {
namespace Linux {

struct vec2 {
  float x, y;
  float &operator[](int i) { return i == 0 ? x : y; }
  float operator[](int i) const { return i == 0 ? x : y; }
};

struct vec4 {
  float x, y, z, w;
  float &operator[](int i) {
    return i == 0 ? x : (i == 1 ? y : (i == 2 ? z : w));
  }
  float operator[](int i) const {
    return i == 0 ? x : (i == 1 ? y : (i == 2 ? z : w));
  }
};

// Extended Uniforms matching common.glsl and ShaderInterop.h
struct Uniforms {
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

struct AudioUniforms {
  float audioVolume;
  float audioBass;
  float audioMid;
  float audioTreble;
  float audioBeat;
  float audioBands[8];
  float audioSpectrum[64];
};

struct ShaderParams {
  float param1 = 0.5f;
  float param2 = 0.5f;
  float param3 = 0.5f;
  float param4 = 0.5f;
  int colorPalette = 0;
  int effectFlags = 0;
  float param5 = 0.5f;
  float param6 = 0.5f;
  float color1[3] = {1.0f, 0.5f, 0.2f};
  float color2[3] = {0.2f, 0.5f, 1.0f};
};

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
  std::string path;
  double lastModTime = 0.0;

  ~GLShaderProgram() { cleanup(); }

  void cleanup();
  bool loadShader(const char *vertexSource, const char *fragmentSource);
  bool reload();
  std::string loadShaderWithIncludes(const char *path, int depth = 0);
  bool loadShaderFromFile(const char *fragmentPath);
  void use();
  void updateUniforms(int width, int height, float mouseX, float mouseY,
                      float mouseBtns, const void *audioData = nullptr);

private:
  GLuint compileShader(GLenum type, const char *source);
};

std::string loadShaderWithIncludes(const char *path, int depth = 0);

} // namespace Linux
} // namespace Platform
} // namespace ShaderCandy
