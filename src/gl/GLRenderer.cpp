#include "GLRenderer.h"

#include <algorithm>
#include <cmath>
#include <ctime>
#include <fstream>
#include <iostream>
#include <sstream>
#include <sys/stat.h>

#if defined(__APPLE__)
#include <OpenGL/gl3.h>
#define GL_SILENCE_DEPRECATION
#elif defined(__linux__)
#include "../platform/linux/GLLoader.h"
#include <GL/gl.h>
#include <GL/glext.h>
#include <sys/inotify.h>
#include <unistd.h>
#endif

#include "../platform/linux/GLSLWrapper.h"

namespace ShaderCandy {
namespace Platform {
namespace Linux {

GLRenderer::GLRenderer() : rng_(std::random_device{}()) {}

GLRenderer::~GLRenderer() { shutdown(); }

bool GLRenderer::initialize(void *display, void *window, bool isGLES) {
  if (initialized_) {
    return true;
  }

#if defined(__linux__)
  InitializeGLLoader();
#endif

  display_ = display;
  window_ = window;
  isGLES_ = isGLES;

  glVersion_ = "4.6";
  glslVersion_ = isGLES_ ? "300 es" : "330 core";

  setupQuad();
  initToneMapping();

  // Initialize blit program for FBO → screen passthrough
  {
    const char *blitVertSrc = R"(
      #version 330 core
      layout(location = 0) in vec2 aPosition;
      layout(location = 1) in vec2 aTexCoord;
      out vec2 vTexCoord;
      void main() {
        gl_Position = vec4(aPosition, 0.0, 1.0);
        vTexCoord = aTexCoord;
      }
    )";
    const char *blitFragSrc = R"(
      #version 330 core
      in vec2 vTexCoord;
      out vec4 fragColor;
      uniform sampler2D screenTexture;
      void main() {
        fragColor = texture(screenTexture, vTexCoord);
      }
    )";
    unsigned int bvs = compileShader(blitVertSrc, GL_VERTEX_SHADER);
    unsigned int bfs = compileShader(blitFragSrc, GL_FRAGMENT_SHADER);
    if (bvs && bfs) {
      blitProgram_ = linkProgram(bvs, bfs);
    }
    if (bvs) glDeleteShader(bvs);
    if (bfs) glDeleteShader(bfs);
  }

  renderWidth_ = 1920;
  renderHeight_ = 1080;
  initPostProcessingFBO();
  initBloom();
  initPostProcessShader();

  if (hotReloadEnabled_) {
    startFileWatcher();
  }

  initialized_ = true;
  return true;
}

void GLRenderer::shutdown() {
  if (!initialized_) {
    return;
  }

  stopFileWatcher();

  {
    std::lock_guard<std::mutex> lock(shaderMutex_);
    for (auto &program : shaderPrograms_) {
      if (program.second) {
        glDeleteProgram(program.second);
      }
    }
    shaderPrograms_.clear();
  }

  if (bloomProgram_) {
    glDeleteProgram(bloomProgram_);
  }

  if (blitProgram_) {
    glDeleteProgram(blitProgram_);
    blitProgram_ = 0;
  }

  if (postProcessProgram_) {
    glDeleteProgram(postProcessProgram_);
    postProcessProgram_ = 0;
  }

  if (toneMapProgram_) {
    glDeleteProgram(toneMapProgram_);
  }
  if (toneMapFBO_) {
    glDeleteFramebuffers(1, &toneMapFBO_);
  }
  if (toneMapTexture_) {
    glDeleteTextures(1, &toneMapTexture_);
  }
  if (toneMapQuadVAO_) {
    glDeleteVertexArrays(1, &toneMapQuadVAO_);
  }
  if (toneMapQuadVBO_) {
    glDeleteBuffers(1, &toneMapQuadVBO_);
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
  if (ebo_) {
    glDeleteBuffers(1, &ebo_);
  }

  for (int i = 0; i < 2; i++) {
    if (bloomFBO_[i]) {
      glDeleteFramebuffers(1, &bloomFBO_[i]);
      bloomFBO_[i] = 0;
    }
    if (bloomTexture_[i]) {
      glDeleteTextures(1, &bloomTexture_[i]);
      bloomTexture_[i] = 0;
    }
  }

  if (particleVAO_) {
    glDeleteVertexArrays(1, &particleVAO_);
    particleVAO_ = 0;
  }
  if (particleVBO_) {
    glDeleteBuffers(1, &particleVBO_);
    particleVBO_ = 0;
  }
  particles_.clear();

  initialized_ = false;
}

std::string GLRenderer::getGLVersion() const { return glVersion_; }

std::string GLRenderer::getGLSLVersion() const { return glslVersion_; }

void GLRenderer::setupQuad() {
  float vertices[] = {-1.0f, -1.0f, 0.0f, 0.0f, 1.0f,  -1.0f, 1.0f, 0.0f,
                      1.0f,  1.0f,  1.0f, 1.0f, -1.0f, 1.0f,  0.0f, 1.0f};

  unsigned int indices[] = {0, 1, 2, 0, 2, 3};

  glGenVertexArrays(1, &vao_);
  glGenBuffers(1, &vbo_);

  glBindVertexArray(vao_);
  glBindBuffer(GL_ARRAY_BUFFER, vbo_);
  glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void *)0);
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float),
                        (void *)(2 * sizeof(float)));

  glGenBuffers(1, &ebo_);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo_);
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices,
               GL_STATIC_DRAW);

  glBindVertexArray(0);
}

unsigned int GLRenderer::compileShader(const std::string &source,
                                       unsigned int type) {
  unsigned int shader = glCreateShader(type);
  const char *src = source.c_str();
  glShaderSource(shader, 1, &src, nullptr);
  glCompileShader(shader);

  int success;
  glGetShaderiv(shader, GL_COMPILE_STATUS, &success);

  if (!success) {
    char infoLog[512];
    glGetShaderInfoLog(shader, 512, nullptr, infoLog);
    setError(GLRendererErrorCode::ShaderCompilationFailed,
             "Shader compilation failed: " + std::string(infoLog), "", infoLog);
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

std::string GLRenderer::loadShaderSource(const std::string &path) {
  std::ifstream file(path);
  if (!file.is_open()) {
    return "";
  }

  std::stringstream buffer;
  buffer << file.rdbuf();
  return buffer.str();
}

bool GLRenderer::loadShader(const std::string &name, const std::string &path) {
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
    if (vs)
      glDeleteShader(vs);
    if (fs)
      glDeleteShader(fs);
    return false;
  }

  unsigned int program = linkProgram(vs, fs);
  glDeleteShader(vs);
  glDeleteShader(fs);

  if (!program) {
    return false;
  }

  GLuint oldProgram = 0;
  {
    std::lock_guard<std::mutex> lock(shaderMutex_);
    if (shaderPrograms_.count(name)) {
      oldProgram = shaderPrograms_[name];
    }
    shaderPrograms_[name] = program;
    shaderPaths_[name] = path;
  }
  if (oldProgram) {
    glDeleteProgram(oldProgram);
  }
  uniformUploader_.invalidate();

  struct stat st;
  if (stat(path.c_str(), &st) == 0) {
    std::lock_guard<std::mutex> lock(shaderMutex_);
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

  auto pathIt = shaderPaths_.find(currentShader_);
  if (pathIt == shaderPaths_.end()) {
    return false;
  }

  std::string source = loadShaderSource(pathIt->second);
  if (source.empty()) {
    setError(GLRendererErrorCode::ShaderCompilationFailed,
             "Failed to reload shader file: " + pathIt->second, currentShader_);
    return false;
  }

  std::string preamble = GLSLWrapper::getPreamble(isGLES_);
  std::string vertSrc = GLSLWrapper::getVertexShader(isGLES_);
  std::string fragSrc = preamble + source;

  unsigned int vs = compileShader(vertSrc, GL_VERTEX_SHADER);
  unsigned int fs = compileShader(fragSrc, GL_FRAGMENT_SHADER);

  if (!vs || !fs) {
    if (vs)
      glDeleteShader(vs);
    if (fs)
      glDeleteShader(fs);
    return false;
  }

  unsigned int program = linkProgram(vs, fs);
  glDeleteShader(vs);
  glDeleteShader(fs);

  if (!program) {
    return false;
  }

  glDeleteProgram(it->second);
  it->second = program;
  currentProgram_ = program;
  uniformUploader_.invalidate();

  struct stat st;
  if (stat(pathIt->second.c_str(), &st) == 0) {
    shaderModTimes_[currentShader_] = st.st_mtime;
  }

  uniformsLocation_ = glGetUniformBlockIndex(currentProgram_, "Uniforms");

  return true;
}

std::vector<std::string> GLRenderer::availableShaderNames() const {
  std::lock_guard<std::mutex> lock(shaderMutex_);
  std::vector<std::string> names;
  for (const auto &shader : shaderPrograms_) {
    names.push_back(shader.first);
  }
  return names;
}

bool GLRenderer::setActiveShader(const std::string &name) {
  auto it = shaderPrograms_.find(name);
  if (it == shaderPrograms_.end()) {
    setError(GLRendererErrorCode::InvalidState, "Shader not found: " + name,
             name);
    return false;
  }

  currentShader_ = name;
  currentProgram_ = it->second;

  uniformsLocation_ = glGetUniformBlockIndex(currentProgram_, "Uniforms");
  uniformUploader_.invalidate();

  if (shaderChangedCallback_) {
    shaderChangedCallback_(name);
  }

  return true;
}

void GLRenderer::render(float time) {
  if (!initialized_ || currentProgram_ == 0) {
    return;
  }

  double currentTime = clock() / (double)CLOCKS_PER_SEC;
  double delta = 0.0;
  if (lastFrameTime_ > 0) {
    delta = currentTime - lastFrameTime_;
    metrics_.frameTimeMs = delta * 1000.0;
    metrics_.currentFPS = 1.0 / delta;

    if (metrics_.currentFPS < metrics_.minFPS)
      metrics_.minFPS = metrics_.currentFPS;
    if (metrics_.currentFPS > metrics_.maxFPS)
      metrics_.maxFPS = metrics_.currentFPS;

    fpsAccumulator_ += metrics_.currentFPS;
    frameCount_++;

    if (frameCount_ >= 60) {
      metrics_.averageFPS = fpsAccumulator_ / frameCount_;
      fpsAccumulator_ = 0.0;
      frameCount_ = 0;
    }

    // Adaptive quality: scale resolution based on FPS
    if (adaptiveQualityConfig_.enabled) {
      float fps = (float)metrics_.currentFPS;
      if (fps < adaptiveQualityConfig_.lowFPS &&
          currentResolutionScale_ > adaptiveQualityConfig_.minResolutionScale) {
        currentResolutionScale_ =
            std::max(adaptiveQualityConfig_.minResolutionScale,
                     currentResolutionScale_ - 0.01f * adaptiveQualityConfig_.adaptationSpeed);
        int newW = (int)(1920 * currentResolutionScale_);
        int newH = (int)(1080 * currentResolutionScale_);
        if (newW != renderWidth_ || newH != renderHeight_) {
          renderWidth_ = newW;
          renderHeight_ = newH;
          initPostProcessingFBO();
          if (bloomConfig_.enabled) initBloom();
        }
      } else if (fps > adaptiveQualityConfig_.highFPS &&
                 currentResolutionScale_ < adaptiveQualityConfig_.maxResolutionScale) {
        currentResolutionScale_ =
            std::min(adaptiveQualityConfig_.maxResolutionScale,
                     currentResolutionScale_ + 0.005f * adaptiveQualityConfig_.adaptationSpeed);
        int newW = (int)(1920 * currentResolutionScale_);
        int newH = (int)(1080 * currentResolutionScale_);
        if (newW != renderWidth_ || newH != renderHeight_) {
          renderWidth_ = newW;
          renderHeight_ = newH;
          initPostProcessingFBO();
          if (bloomConfig_.enabled) initBloom();
        }
      }
    }
  }
  lastFrameTime_ = currentTime;

  uniforms_.time = time;
  uniforms_.frame++;

  // Update transition
  if (inTransition_) {
    updateTransition(static_cast<float>(delta));
    uniforms_.alpha = transitionProgress_;
  }

  // Update particles
  if (particleConfig_.enabled && !particles_.empty()) {
    updateParticles(static_cast<float>(delta));
  }

  // Bind post-processing FBO
  bool useFBO = (fbo_ != 0);
  if (useFBO) {
    glBindFramebuffer(GL_FRAMEBUFFER, fbo_);
    glViewport(0, 0, renderWidth_, renderHeight_);
  }

  glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

  glUseProgram(currentProgram_);

  if (uniformsLocation_ >= 0) {
    glUniformBlockBinding(currentProgram_, uniformsLocation_, 0);
  }

  uniformUploader_.upload(currentProgram_, uniforms_, shaderParams_, audioReactivityEnabled_);

  glBindVertexArray(vao_);
  glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);

  // Render particles on top of shader output
  if (particleConfig_.enabled && !particles_.empty()) {
    renderParticles();
  }

  glBindVertexArray(0);
  glUseProgram(0);

  // Post-processing chain: apply effects to FBO texture before blitting
  if (useFBO && postProcessProgram_) {
    renderPostProcess();
  }

  // Blit scene from FBO to screen
  if (useFBO) {
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(0, 0, renderWidth_, renderHeight_);
    renderToneMap();
  }

  // Composite bloom additively on top of scene
  if (bloomConfig_.enabled && bloomProgram_) {
    renderBloom();
  }
}

void GLRenderer::resize(int width, int height) {
  if (width > 0 && height > 0) {
    renderWidth_ = width;
    renderHeight_ = height;
    metrics_.memoryUsageBytes = width * height * 4;
    uniforms_.resolution.x = (float)width;
    uniforms_.resolution.y = (float)height;

    initPostProcessingFBO();

    if (bloomConfig_.enabled) {
      initBloom();
    }

    if (hdrEnabled_) {
      if (toneMapTexture_) {
        glDeleteTextures(1, &toneMapTexture_);
      }
      glGenTextures(1, &toneMapTexture_);
      glBindTexture(GL_TEXTURE_2D, toneMapTexture_);
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F, width, height, 0, GL_RGBA,
                   GL_FLOAT, nullptr);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

      if (toneMapFBO_) {
        glDeleteFramebuffers(1, &toneMapFBO_);
      }
      glGenFramebuffers(1, &toneMapFBO_);
      glBindFramebuffer(GL_FRAMEBUFFER, toneMapFBO_);
      glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D,
                           toneMapTexture_, 0);
      glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }
  }
}

void GLRenderer::setMouse(float x, float y, int buttons) {
  uniforms_.mouse.x = x;
  uniforms_.mouse.y = y;
  uniforms_.mouseButtons = (float)buttons;
}

void GLRenderer::setAudioData(float volume, float bass, float mid, float treble,
                              float beat) {
  uniforms_.volume = volume;
  uniforms_.bass = bass;
  uniforms_.mid = mid;
  uniforms_.treble = treble;
  uniforms_.beat = beat;
}

void GLRenderer::setBloomEnabled(bool enabled) {
  bloomConfig_.enabled = enabled;
  if (initialized_ && enabled) {
    initBloom();
  }
}

void GLRenderer::setBloomQuality(GLBloomQuality quality) {
  bloomConfig_.quality = quality;
  if (initialized_ && bloomConfig_.enabled) {
    initBloom();
  }
}

void GLRenderer::setBloomIntensity(float intensity) {
  bloomConfig_.intensity = intensity;
}

void GLRenderer::setBloomThreshold(float threshold) {
  bloomConfig_.threshold = threshold;
}

void GLRenderer::setParticlesEnabled(bool enabled) {
  particleConfig_.enabled = enabled;
  if (enabled && particles_.empty()) {
    initParticles();
  }
}

void GLRenderer::setParticleCount(int count) {
  particleConfig_.count = count;
  if (particleConfig_.enabled) {
    initParticles();
  }
}

void GLRenderer::setParticleGravity(float gravity) {
  particleConfig_.gravity = gravity;
}

void GLRenderer::initParticles() {
  particles_.clear();
  particles_.reserve(particleConfig_.count);

  for (int i = 0; i < particleConfig_.count; i++) {
    Particle p;
    p.x = (rand() % 2000 / 1000.0f) - 1.0f;
    p.y = (rand() % 2000 / 1000.0f) - 1.0f;
    p.vx = (rand() % 100 / 1000.0f) - 0.05f;
    p.vy = (rand() % 100 / 1000.0f) - 0.05f;
    p.life = rand() % 100 / 100.0f;
    p.maxLife = 1.0f + rand() % 100 / 100.0f;
    particles_.push_back(p);
  }

  if (particleVAO_ == 0) {
    glGenVertexArrays(1, &particleVAO_);
    glGenBuffers(1, &particleVBO_);
  }

  glBindVertexArray(particleVAO_);
  glBindBuffer(GL_ARRAY_BUFFER, particleVBO_);
  glBufferData(GL_ARRAY_BUFFER, particles_.size() * sizeof(Particle),
               particles_.data(), GL_DYNAMIC_DRAW);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(Particle),
                        (void *)offsetof(Particle, x));
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, sizeof(Particle),
                        (void *)offsetof(Particle, vx));
  glEnableVertexAttribArray(2);
  glVertexAttribPointer(2, 1, GL_FLOAT, GL_FALSE, sizeof(Particle),
                        (void *)offsetof(Particle, life));
  glBindVertexArray(0);
}

void GLRenderer::updateParticles(float deltaTime) {
  if (!particleConfig_.enabled || particles_.empty())
    return;

  float gravity = particleConfig_.gravity * deltaTime * 0.1f;
  float speed = particleConfig_.speed;

  for (auto &p : particles_) {
    p.vy -= gravity;
    p.x += p.vx * speed;
    p.y += p.vy * speed;
    p.life -= deltaTime;

    if (p.y < -1.0f || p.life <= 0.0f) {
      p.x = (rand() % 2000 / 1000.0f) - 1.0f;
      p.y = 1.0f;
      p.vx = (rand() % 100 / 1000.0f) - 0.05f;
      p.vy = -(rand() % 100 / 1000.0f) - 0.02f;
      p.life = p.maxLife;
    }
  }

  glBindBuffer(GL_ARRAY_BUFFER, particleVBO_);
  glBufferSubData(GL_ARRAY_BUFFER, 0, particles_.size() * sizeof(Particle),
                  particles_.data());
}

void GLRenderer::renderParticles() {
  if (!particleConfig_.enabled || particles_.empty())
    return;

  glBindVertexArray(particleVAO_);
  glDrawArrays(GL_POINTS, 0, static_cast<GLsizei>(particles_.size()));
  glBindVertexArray(0);
}

void GLRenderer::setToneMapping(GLToneMapping toneMapping) {
  toneMapping_ = toneMapping;
  if (initialized_) {
    if (toneMapProgram_) {
      glDeleteProgram(toneMapProgram_);
      toneMapProgram_ = 0;
    }
    initToneMapping();
  }
}

bool GLRenderer::initToneMapping() {
  if (!hdrEnabled_) {
    return true;
  }

  const char *vertexShader = R"(
    #version 330 core
    layout(location = 0) in vec2 aPosition;
    layout(location = 1) in vec2 aTexCoord;
    out vec2 vTexCoord;
    void main() {
      gl_Position = vec4(aPosition, 0.0, 1.0);
      vTexCoord = aTexCoord;
    }
  )";

  std::string fragShader = R"(
    #version 330 core
    in vec2 vTexCoord;
    out vec4 fragColor;
    uniform sampler2D hdrTexture;
    uniform int toneMapOperator;
    uniform float exposure;

    vec3 acesFilm(vec3 x) {
      float a = 2.51;
      float b = 0.03;
      float c = 2.43;
      float d = 0.59;
      float e = 0.14;
      return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
    }

    vec3 reinhard(vec3 x) {
      return x / (1.0 + x);
    }

    vec3 hable(vec3 x) {
      float a = 0.15;
      float b = 0.50;
      float c = 0.10;
      float d = 0.20;
      float e = 0.02;
      float w = 11.2;
      return ((x * (a * x + b)) / (x * (c * x + d) + e) / (x * (c * w + d) + e));
    }

    void main() {
      vec3 color = texture(hdrTexture, vTexCoord).rgb;
      color *= exposure;

      if (toneMapOperator == 0) {
        color = acesFilm(color);
      } else if (toneMapOperator == 1) {
        color = reinhard(color);
      } else if (toneMapOperator == 2) {
        color = hable(color);
      }

      fragColor = vec4(color, 1.0);
    }
  )";

  unsigned int vs = compileShader(vertexShader, GL_VERTEX_SHADER);
  if (!vs) {
    setError(GLRendererErrorCode::ShaderCompilationFailed,
           "Tone map vertex shader failed", "", "");
    return false;
  }

  unsigned int fs = compileShader(fragShader.c_str(), GL_FRAGMENT_SHADER);
  if (!fs) {
    glDeleteShader(vs);
    setError(GLRendererErrorCode::ShaderCompilationFailed,
           "Tone map fragment shader failed", "", "");
    return false;
  }

  toneMapProgram_ = linkProgram(vs, fs);
  glDeleteShader(vs);
  glDeleteShader(fs);

  if (!toneMapProgram_) {
    return false;
  }

  if (toneMapQuadVAO_) {
    glDeleteVertexArrays(1, &toneMapQuadVAO_);
  }
  if (toneMapQuadVBO_) {
    glDeleteBuffers(1, &toneMapQuadVBO_);
  }
  glGenVertexArrays(1, &toneMapQuadVAO_);
  glGenBuffers(1, &toneMapQuadVBO_);

  float quadVertices[] = {
    -1.0f, -1.0f, 0.0f, 0.0f,
     1.0f, -1.0f, 1.0f, 0.0f,
    -1.0f,  1.0f, 0.0f, 1.0f,
     1.0f,  1.0f, 1.0f, 1.0f,
  };

  glBindVertexArray(toneMapQuadVAO_);
  glBindBuffer(GL_ARRAY_BUFFER, toneMapQuadVBO_);
  glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), quadVertices, GL_STATIC_DRAW);
  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void *)0);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float),
                      (void *)(2 * sizeof(float)));
  glEnableVertexAttribArray(1);
  glBindVertexArray(0);

  glGenFramebuffers(1, &toneMapFBO_);
  glGenTextures(1, &toneMapTexture_);

  return true;
}

void GLRenderer::renderToneMap() {
  if (!hdrEnabled_ || toneMapProgram_ == 0) {
    // Fallback: blit fboTexture_ to default framebuffer via blit program
    if (fboTexture_ == 0 || blitProgram_ == 0)
      return;
    glUseProgram(blitProgram_);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, fboTexture_);
    glUniform1i(glGetUniformLocation(blitProgram_, "screenTexture"), 0);
    glBindVertexArray(vao_);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    glBindVertexArray(0);
    glUseProgram(0);
    return;
  }

  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  glUseProgram(toneMapProgram_);

  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, fboTexture_);
  glUniform1i(glGetUniformLocation(toneMapProgram_, "hdrTexture"), 0);
  glUniform1i(glGetUniformLocation(toneMapProgram_, "toneMapOperator"),
            static_cast<int>(toneMapping_));
  glUniform1f(glGetUniformLocation(toneMapProgram_, "exposure"), 1.0f);

  glBindVertexArray(toneMapQuadVAO_);
  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
  glBindVertexArray(0);

  glUseProgram(0);
}

GLPerformanceMetrics GLRenderer::getMetrics() { return metrics_; }

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

  std::string path;
  {
    std::lock_guard<std::mutex> lock(shaderMutex_);
    auto pathIt = shaderPaths_.find(currentShader_);
    if (pathIt == shaderPaths_.end()) {
      return;
    }
    path = pathIt->second;
  }

  struct stat st;
  if (stat(path.c_str(), &st) != 0) {
    return;
  }

  {
    std::lock_guard<std::mutex> lock(shaderMutex_);
    auto timeIt = shaderModTimes_.find(currentShader_);
    if (timeIt != shaderModTimes_.end() && st.st_mtime <= timeIt->second) {
      return;
    }
    shaderModTimes_[currentShader_] = st.st_mtime;
  }

  reloadCurrentShader();
}

void GLRenderer::setError(GLRendererErrorCode code, const std::string &msg,
                          const std::string &shader,
                          const std::string &compileError) {
  lastError_ = {code, msg, shader, compileError, 0};
  if (errorCallback_) {
    errorCallback_(lastError_);
  }
}

void GLRenderer::startFileWatcher() {
  if (fileWatcherRunning_)
    return;

#if defined(__linux__)
  int fd = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
  if (fd < 0)
    return;

  for (const auto &pair : shaderPaths_) {
    int wd = inotify_add_watch(fd, pair.second.c_str(), IN_MODIFY);
    if (wd >= 0) {
      watchDescriptors_[pair.first] = wd;
    }
  }

  fileWatcherRunning_ = true;
  fileWatcherThread_ = std::thread([this, fd]() {
    char buf[4096];
    while (fileWatcherRunning_) {
      int len = read(fd, buf, sizeof(buf));
      if (len > 0) {
        checkForShaderReload();
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
    for (auto &wd : watchDescriptors_) {
      inotify_rm_watch(fd, wd.second);
    }
    close(fd);
  });
#endif
}

void GLRenderer::stopFileWatcher() {
  fileWatcherRunning_ = false;
  if (fileWatcherThread_.joinable()) {
    fileWatcherThread_.join();
  }
  watchDescriptors_.clear();
}

void GLRenderer::initPostProcessingFBO() {
  if (renderWidth_ <= 0 || renderHeight_ <= 0)
    return;

  if (fbo_) {
    glDeleteFramebuffers(1, &fbo_);
    fbo_ = 0;
  }
  if (fboTexture_) {
    glDeleteTextures(1, &fboTexture_);
    fboTexture_ = 0;
  }
  if (rbo_) {
    glDeleteRenderbuffers(1, &rbo_);
    rbo_ = 0;
  }

  glGenFramebuffers(1, &fbo_);
  glBindFramebuffer(GL_FRAMEBUFFER, fbo_);

  glGenTextures(1, &fboTexture_);
  glBindTexture(GL_TEXTURE_2D, fboTexture_);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, renderWidth_, renderHeight_, 0,
               GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D,
                         fboTexture_, 0);

  glGenRenderbuffers(1, &rbo_);
  glBindRenderbuffer(GL_RENDERBUFFER, rbo_);
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, renderWidth_,
                        renderHeight_);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT,
                            GL_RENDERBUFFER, rbo_);

  if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
    setError(GLRendererErrorCode::InvalidState, "Post-processing FBO incomplete");
  }
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

void GLRenderer::initBloom() {
  if (bloomProgram_) {
    glDeleteProgram(bloomProgram_);
    bloomProgram_ = 0;
  }

  const char *bloomVertSrc = R"(
    #version 330 core
    layout(location = 0) in vec2 aPosition;
    layout(location = 1) in vec2 aTexCoord;
    out vec2 vTexCoord;
    void main() {
      gl_Position = vec4(aPosition, 0.0, 1.0);
      vTexCoord = aTexCoord;
    }
  )";

  std::string bloomFragSrc = R"(
    #version 330 core
    in vec2 vTexCoord;
    out vec4 fragColor;
    uniform sampler2D image;
    uniform vec2 texelSize;
    uniform int horizontal;
    uniform float threshold;
    uniform float intensity;

    void main() {
      vec3 result = vec3(0.0);
      float weights[5] = float[](0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);

      if (horizontal < 0) {
        vec4 color = texture(image, vTexCoord);
        float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
        if (brightness > threshold) {
          fragColor = vec4(color.rgb * intensity, color.a);
        } else {
          fragColor = vec4(0.0);
        }
        return;
      }

      vec2 offset = texelSize;
      result += texture(image, vTexCoord).rgb * weights[0];
      for (int i = 1; i < 5; i++) {
        vec2 off = offset * float(i) * 1.5;
        if (horizontal == 1) {
          result += texture(image, vTexCoord + vec2(off.x, 0.0)).rgb * weights[i];
          result += texture(image, vTexCoord - vec2(off.x, 0.0)).rgb * weights[i];
        } else {
          result += texture(image, vTexCoord + vec2(0.0, off.y)).rgb * weights[i];
          result += texture(image, vTexCoord - vec2(0.0, off.y)).rgb * weights[i];
        }
      }
      fragColor = vec4(result, 1.0);
    }
  )";

  unsigned int vs = compileShader(bloomVertSrc, GL_VERTEX_SHADER);
  std::string fragPrepend = isGLES_ ? "#version 300 es\nprecision mediump float;\n" : "";
  unsigned int fs = compileShader(fragPrepend + bloomFragSrc, GL_FRAGMENT_SHADER);

  if (vs && fs) {
    bloomProgram_ = linkProgram(vs, fs);
  }
  if (vs)
    glDeleteShader(vs);
  if (fs)
    glDeleteShader(fs);

  int bloomW = renderWidth_ / 2;
  int bloomH = renderHeight_ / 2;
  if (bloomW < 1) bloomW = 1;
  if (bloomH < 1) bloomH = 1;

  for (int i = 0; i < 2; i++) {
    if (bloomFBO_[i]) {
      glDeleteFramebuffers(1, &bloomFBO_[i]);
      bloomFBO_[i] = 0;
    }
    if (bloomTexture_[i]) {
      glDeleteTextures(1, &bloomTexture_[i]);
      bloomTexture_[i] = 0;
    }

    glGenFramebuffers(1, &bloomFBO_[i]);
    glBindFramebuffer(GL_FRAMEBUFFER, bloomFBO_[i]);

    glGenTextures(1, &bloomTexture_[i]);
    glBindTexture(GL_TEXTURE_2D, bloomTexture_[i]);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, bloomW, bloomH, 0, GL_RGBA,
                 GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D,
                           bloomTexture_[i], 0);
  }
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

void GLRenderer::renderBloom() {
  if (!bloomConfig_.enabled || !bloomProgram_ || !fboTexture_)
    return;

  int bloomW = renderWidth_ / 2;
  int bloomH = renderHeight_ / 2;
  if (bloomW < 1 || bloomH < 1)
    return;

  glUseProgram(bloomProgram_);
  glBindVertexArray(vao_);

  float texelW = 1.0f / bloomW;
  float texelH = 1.0f / bloomH;

  int passes = 4;
  if (bloomConfig_.quality == GLBloomQuality::Low) passes = 2;
  else if (bloomConfig_.quality == GLBloomQuality::High) passes = 6;
  else if (bloomConfig_.quality == GLBloomQuality::Ultra) passes = 8;

  glActiveTexture(GL_TEXTURE0);
  glUniform1i(glGetUniformLocation(bloomProgram_, "image"), 0);
  glUniform1f(glGetUniformLocation(bloomProgram_, "threshold"),
              bloomConfig_.threshold);
  glUniform1f(glGetUniformLocation(bloomProgram_, "intensity"),
              bloomConfig_.intensity);

  // Pass 0: threshold extract from scene
  glBindFramebuffer(GL_FRAMEBUFFER, bloomFBO_[0]);
  glViewport(0, 0, bloomW, bloomH);
  glBindTexture(GL_TEXTURE_2D, fboTexture_);
  glUniform1i(glGetUniformLocation(bloomProgram_, "horizontal"), -1);
  glUniform2f(glGetUniformLocation(bloomProgram_, "texelSize"), texelW, texelH);
  glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);

  // Ping-pong blur passes
  for (int i = 0; i < passes; i++) {
    int src = i % 2;
    int dst = 1 - src;
    glBindFramebuffer(GL_FRAMEBUFFER, bloomFBO_[dst]);
    glViewport(0, 0, bloomW, bloomH);
    glBindTexture(GL_TEXTURE_2D, bloomTexture_[src]);
    glUniform1i(glGetUniformLocation(bloomProgram_, "horizontal"), i % 2);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
  }

  // Composite: additive blend bloom onto default framebuffer
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  glViewport(0, 0, renderWidth_, renderHeight_);
  glEnable(GL_BLEND);
  glBlendFunc(GL_ONE, GL_ONE);
  glBindTexture(GL_TEXTURE_2D, bloomTexture_[passes % 2]);
  glUniform1i(glGetUniformLocation(bloomProgram_, "horizontal"), 1);
  glUniform2f(glGetUniformLocation(bloomProgram_, "texelSize"), texelW, texelH);
  glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
  glDisable(GL_BLEND);

  glBindVertexArray(0);
  glUseProgram(0);
}

void GLRenderer::setAudioDataArray(const float *audioData, int count) {
  int maxCount = std::min(count, 256);
  for (int i = 0; i < maxCount; i++) {
    uniforms_.audioData[i] = audioData[i];
  }
}

// ============================================================================
// Transition System
// ============================================================================

void GLRenderer::beginTransition(GLTransitionType type, GLEasingFunction easing,
                                 float duration) {
  if (inTransition_)
    return;

  transitionConfig_.type = type;
  transitionConfig_.easing = easing;
  transitionConfig_.duration = duration;
  transitionTime_ = 0.0f;
  transitionProgress_ = 0.0f;
  inTransition_ = true;
}

void GLRenderer::updateTransition(float deltaTime) {
  if (!inTransition_)
    return;

  transitionTime_ += deltaTime;
  float t = transitionTime_ / transitionConfig_.duration;
  if (t >= 1.0f) {
    t = 1.0f;
    inTransition_ = false;
    transitionProgress_ = 1.0f;
  } else {
    transitionProgress_ = applyEasing(t);
  }
}

float GLRenderer::applyEasing(float t) const {
  switch (transitionConfig_.easing) {
  case GLEasingFunction::Linear:
    return t;
  case GLEasingFunction::EaseIn:
    return t * t;
  case GLEasingFunction::EaseOut:
    return t * (2.0f - t);
  case GLEasingFunction::EaseInOut:
    return t < 0.5f ? 2.0f * t * t : -1.0f + (4.0f - 2.0f * t) * t;
  case GLEasingFunction::CubicIn:
    return t * t * t;
  case GLEasingFunction::CubicOut: {
    float f = t - 1.0f;
    return f * f * f + 1.0f;
  }
  case GLEasingFunction::CubicInOut:
    return t < 0.5f ? 4.0f * t * t * t
                     : (t - 1.0f) * (2.0f * t - 2.0f) * (2.0f * t - 2.0f) +
                           1.0f;
  case GLEasingFunction::ExponentialIn:
    return (t == 0.0f) ? 0.0f : std::pow(2.0f, 10.0f * (t - 1.0f));
  case GLEasingFunction::ExponentialOut:
    return (t == 1.0f) ? 1.0f : 1.0f - std::pow(2.0f, -10.0f * t);
  case GLEasingFunction::ExponentialInOut:
    if (t == 0.0f) return 0.0f;
    if (t == 1.0f) return 1.0f;
    if (t < 0.5f)
      return 0.5f * std::pow(2.0f, 20.0f * t - 10.0f);
    else
      return 1.0f - 0.5f * std::pow(2.0f, -20.0f * t + 10.0f);
  default:
    return t;
  }
}

void GLRenderer::renderTransition(float time) {
  // Transition rendering is handled via alpha uniform in the render() method
}

// ============================================================================
// Smart Shader Rotation
// ============================================================================

std::string GLRenderer::getNextShaderName() const {
  auto names = availableShaderNames();
  if (names.empty())
    return "";

  std::vector<std::string> available;
  for (const auto &name : names) {
    if (!isSkipped(name)) {
      available.push_back(name);
    }
  }
  if (available.empty())
    return names.empty() ? "" : names[0];

  if (shuffleMode_) {
    std::uniform_int_distribution<size_t> dist(0, available.size() - 1);
    return available[dist(const_cast<std::mt19937 &>(rng_))];
  }

  auto it = std::find(available.begin(), available.end(), currentShader_);
  if (it == available.end()) {
    return available[0];
  }
  ++it;
  if (it == available.end()) {
    return available[0];
  }
  return *it;
}

void GLRenderer::addFavorite(const std::string &name) {
  favorites_.insert(name);
}

void GLRenderer::removeFavorite(const std::string &name) {
  favorites_.erase(name);
}

bool GLRenderer::isFavorite(const std::string &name) const {
  return favorites_.count(name) > 0;
}

void GLRenderer::addSkip(const std::string &name) { skipList_.insert(name); }

void GLRenderer::removeSkip(const std::string &name) {
  skipList_.erase(name);
}

bool GLRenderer::isSkipped(const std::string &name) const {
  return skipList_.count(name) > 0;
}

// ============================================================================
// Post-Processing
// ============================================================================

void GLRenderer::initPostProcessShader() {
  if (postProcessProgram_) {
    glDeleteProgram(postProcessProgram_);
    postProcessProgram_ = 0;
  }

  const char *vertSrc = R"(
    #version 330 core
    layout(location = 0) in vec2 aPosition;
    layout(location = 1) in vec2 aTexCoord;
    out vec2 vTexCoord;
    void main() {
      gl_Position = vec4(aPosition, 0.0, 1.0);
      vTexCoord = aTexCoord;
    }
  )";

  std::string fragSrc = R"(
    #version 330 core
    in vec2 vTexCoord;
    out vec4 fragColor;
    uniform sampler2D screenTexture;
    uniform vec2 resolution;
    uniform float time;

    uniform bool vignetteEnabled;
    uniform float vignetteIntensity;
    uniform float vignetteRadius;

    uniform bool chromaticAberrationEnabled;
    uniform float chromaticAberrationAmount;

    uniform bool filmGrainEnabled;
    uniform float filmGrainIntensity;

    uniform bool crtScanlinesEnabled;
    uniform float crtScanlineIntensity;
    uniform float crtScanlineCount;

    uniform bool colorTintEnabled;
    uniform vec3 colorTint;

    float hash(vec2 p) {
      return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
    }

    void main() {
      vec2 uv = vTexCoord;
      vec3 color;

      if (chromaticAberrationEnabled) {
        float amount = chromaticAberrationAmount;
        vec2 dir = uv - 0.5;
        float dist = length(dir);
        amount *= dist;
        float r = texture(screenTexture, uv + dir * amount).r;
        float g = texture(screenTexture, uv).g;
        float b = texture(screenTexture, uv - dir * amount).b;
        color = vec3(r, g, b);
      } else {
        color = texture(screenTexture, uv).rgb;
      }

      if (crtScanlinesEnabled) {
        float scanline = sin(uv.y * crtScanlineCount * 3.14159) * 0.5 + 0.5;
        color *= 1.0 - crtScanlineIntensity * (1.0 - scanline);
      }

      if (filmGrainEnabled) {
        float grain = hash(uv * resolution + time * 100.0) * 2.0 - 1.0;
        color += grain * filmGrainIntensity;
      }

      if (vignetteEnabled) {
        vec2 center = uv - 0.5;
        float dist = length(center);
        float vig = smoothstep(vignetteRadius, vignetteRadius - 0.4, dist);
        color *= mix(1.0 - vignetteIntensity, 1.0, vig);
      }

      if (colorTintEnabled) {
        color *= colorTint;
      }

      color = clamp(color, 0.0, 1.0);
      fragColor = vec4(color, 1.0);
    }
  )";

  unsigned int vs = compileShader(vertSrc, GL_VERTEX_SHADER);
  unsigned int fs = compileShader(fragSrc, GL_FRAGMENT_SHADER);

  if (vs && fs) {
    postProcessProgram_ = linkProgram(vs, fs);
  }
  if (vs) glDeleteShader(vs);
  if (fs) glDeleteShader(fs);
}

void GLRenderer::renderPostProcess() {
  if (!postProcessProgram_ || !fboTexture_)
    return;

  glUseProgram(postProcessProgram_);

  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D, fboTexture_);
  glUniform1i(glGetUniformLocation(postProcessProgram_, "screenTexture"), 0);
  glUniform2f(glGetUniformLocation(postProcessProgram_, "resolution"),
              (float)renderWidth_, (float)renderHeight_);
  glUniform1f(glGetUniformLocation(postProcessProgram_, "time"), uniforms_.time);

  glUniform1i(glGetUniformLocation(postProcessProgram_, "vignetteEnabled"),
              postProcessConfig_.vignetteEnabled ? 1 : 0);
  glUniform1f(glGetUniformLocation(postProcessProgram_, "vignetteIntensity"),
              postProcessConfig_.vignetteIntensity);
  glUniform1f(glGetUniformLocation(postProcessProgram_, "vignetteRadius"),
              postProcessConfig_.vignetteRadius);

  glUniform1i(
      glGetUniformLocation(postProcessProgram_, "chromaticAberrationEnabled"),
      postProcessConfig_.chromaticAberrationEnabled ? 1 : 0);
  glUniform1f(
      glGetUniformLocation(postProcessProgram_, "chromaticAberrationAmount"),
      postProcessConfig_.chromaticAberrationAmount);

  glUniform1i(glGetUniformLocation(postProcessProgram_, "filmGrainEnabled"),
              postProcessConfig_.filmGrainEnabled ? 1 : 0);
  glUniform1f(glGetUniformLocation(postProcessProgram_, "filmGrainIntensity"),
              postProcessConfig_.filmGrainIntensity);

  glUniform1i(glGetUniformLocation(postProcessProgram_, "crtScanlinesEnabled"),
              postProcessConfig_.crtScanlinesEnabled ? 1 : 0);
  glUniform1f(glGetUniformLocation(postProcessProgram_, "crtScanlineIntensity"),
              postProcessConfig_.crtScanlineIntensity);
  glUniform1f(glGetUniformLocation(postProcessProgram_, "crtScanlineCount"),
              postProcessConfig_.crtScanlineCount);

  glUniform1i(glGetUniformLocation(postProcessProgram_, "colorTintEnabled"),
              postProcessConfig_.colorTintEnabled ? 1 : 0);
  glUniform3f(glGetUniformLocation(postProcessProgram_, "colorTint"),
              postProcessConfig_.colorTintR, postProcessConfig_.colorTintG,
              postProcessConfig_.colorTintB);

  glBindVertexArray(vao_);
  glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
  glBindVertexArray(0);
  glUseProgram(0);
}

} // namespace Linux
} // namespace Platform
} // namespace ShaderCandy
