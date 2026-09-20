/* This is free and unencumbered software released into the public domain.
   See LICENSE or <https://unlicense.org/> for details. */

#include "GLShaderProgram.h"

#ifdef HAS_AUDIO
#include "../../audio/AudioInput.h"
#endif

namespace {
bool g_glShaderProgramLoaderInitialized = false;
}

namespace ShaderCandy {
namespace Platform {
namespace Linux {

void GLShaderProgram::cleanup() {
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

bool GLShaderProgram::loadShader(const char *vertexSource,
                                 const char *fragmentSource) {
  if (!g_glShaderProgramLoaderInitialized) {
    g_glShaderProgramLoaderInitialized = InitializeGLLoader();
    if (!g_glShaderProgramLoaderInitialized)
      return false;
  }

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

  glGenBuffers(1, &ubo);
  glBindBuffer(GL_UNIFORM_BUFFER, ubo);
  glBufferData(GL_UNIFORM_BUFFER, sizeof(Uniforms), nullptr, GL_DYNAMIC_DRAW);

  GLuint blockIndex = glGetUniformBlockIndex(program, "Uniforms");
  std::cerr << "Shader '" << name << "': Uniform block index = " << blockIndex
            << std::endl;
  if (blockIndex != GL_INVALID_INDEX) {
    glUniformBlockBinding(program, blockIndex, 0);
    std::cerr << "Shader '" << name
              << "': Uniform block bound to binding point 0" << std::endl;
  } else {
    std::cerr << "Shader '" << name
              << "': WARNING - Uniform block 'Uniforms' not found!" << std::endl;
  }

  GLuint audioBlockIndex = glGetUniformBlockIndex(program, "AudioUniforms");
  if (audioBlockIndex != GL_INVALID_INDEX) {
    std::cerr << "Shader '" << name << "': AudioUniforms block found!"
              << std::endl;
  } else {
    std::cerr << "Shader '" << name << "': No AudioUniforms block found"
              << std::endl;
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

bool GLShaderProgram::reload() {
  if (path.empty())
    return false;

  struct stat st;
  if (stat(path.c_str(), &st) != 0)
    return false;

  std::string included = GLSLWrapper::loadShaderWithIncludes(path.c_str(), 0);
  if (!included.empty()) {
    cleanup();
    std::string vertexShaderStr = GLSLWrapper::getVertexShader();
    std::string wrappedFrag = "#version 330 core\n";
    wrappedFrag += included;
    loadShader(vertexShaderStr.c_str(), wrappedFrag.c_str());
    startTime = std::chrono::steady_clock::now();
    lastFrame = startTime;
    lastModTime = st.st_mtime;
    return true;
  }
  return false;
}

std::string GLShaderProgram::loadShaderWithIncludes(const char *path, int depth) {
  return GLSLWrapper::loadShaderWithIncludes(path, depth);
}

bool GLShaderProgram::loadShaderFromFile(const char *fragmentPath) {
  std::string fragStr = GLSLWrapper::loadShaderWithIncludes(fragmentPath);
  if (fragStr.empty()) {
    return false;
  }

  path = fragmentPath;
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
#version 330 core\n";
  wrappedFrag += fragStr;

  return loadShader(vertexShaderStr.c_str(), wrappedFrag.c_str());
}

void GLShaderProgram::use() {
  glUseProgram(program);
  glBindBufferBase(GL_UNIFORM_BUFFER, 0, ubo);
}

void GLShaderProgram::updateUniforms(int width, int height, float mouseX,
                                     float mouseY, float mouseBtns,
                                     const void *audioDataPtr) {
  auto now = std::chrono::steady_clock::now();

  uniforms.time = std::chrono::duration<float>(now - startTime).count();
  uniforms.resolution[0] = static_cast<float>(width);
  uniforms.resolution[1] = static_cast<float>(height);
  uniforms.mouse[0] = mouseX / static_cast<float>(width);
  uniforms.mouse[1] = mouseY / static_cast<float>(height);
  uniforms.mouseButtons = mouseBtns;
  uniforms.frame = frameCount++;
  uniforms.deltaTime = std::chrono::duration<float>(now - lastFrame).count();

  static int uniformDebugCount = 0;
  if (uniformDebugCount++ < 5) {
    std::cerr << "Uniforms: time=" << uniforms.time
              << " res=" << uniforms.resolution[0] << "x"
              << uniforms.resolution[1] << " speed=" << uniforms.speed
              << " intensity=" << uniforms.alpha << std::endl;
  }

  time_t t = time(nullptr);
  struct tm tm_buf;
  localtime_r(&t, &tm_buf);
  uniforms.date[0] = static_cast<float>(tm_buf.tm_year + 1900);
  uniforms.date[1] = static_cast<float>(tm_buf.tm_mon + 1);
  uniforms.date[2] = static_cast<float>(tm_buf.tm_mday);
  uniforms.date[3] =
      static_cast<float>(tm_buf.tm_hour * 3600 + tm_buf.tm_min * 60 + tm_buf.tm_sec);

  if (audioDataPtr) {
    const auto *ad =
        static_cast<const ShaderCandy::Audio::AudioData *>(audioDataPtr);
    uniforms.volume = ad->volume;
    uniforms.bass = ad->bass;
    uniforms.mid = ad->mid;
    uniforms.treble = ad->treble;
    uniforms.beat = ad->beat ? 1.0f : 0.0f;
    int samplesToCopy = std::min(256, (int)ad->spectrum.size());
    for (int i = 0; i < samplesToCopy; ++i) {
      uniforms.audioData[i] = ad->spectrum[i];
    }
  }

  glBindBuffer(GL_UNIFORM_BUFFER, ubo);
  glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(Uniforms), &uniforms);

  lastFrame = now;
}

GLuint GLShaderProgram::compileShader(GLenum type, const char *source) {
  GLuint shader = glCreateShader(type);
  const char *sources[] = {source};
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

} // namespace Linux
} // namespace Platform
} // namespace ShaderCandy
