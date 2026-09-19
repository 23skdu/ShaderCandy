/* This is free and unencumbered software released into the public domain.
   See LICENSE or <https://unlicense.org/> for details. */

#include "GLShaderProgram.h"

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

  std::string included = loadShaderWithIncludes(path.c_str(), 0);
  if (!included.empty()) {
    cleanup();
    loadShader("#version 450\nin vec2 position;\nvoid main() { "
               "gl_Position = vec4(position, 0.0, 1.0); }\n",
               included.c_str());
    startTime = std::chrono::steady_clock::now();
    lastFrame = startTime;
    lastModTime = st.st_mtime;
    return true;
  }
  return false;
}

std::string GLShaderProgram::loadShaderWithIncludes(const char *path,
                                                    int depth) {
  if (depth > 10) {
    std::cerr << "Include depth exceeded for: " << path << std::endl;
    return "";
  }

  std::ifstream file(path);
  if (!file.is_open()) {
    std::cerr << "Failed to open: " << path << std::endl;
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
          while (parentDir.length() > 0 &&
                 (parentDir.back() == '/' || parentDir.back() == '\\')) {
            parentDir.pop_back();
          }
          size_t parentSlash = parentDir.find_last_of("/\\");
          if (parentSlash != std::string::npos) {
            parentDir = parentDir.substr(0, parentSlash);
          }
          std::string remainingPath = includePath.substr(3);
          while (remainingPath.substr(0, 3) == "../") {
            size_t slash = parentDir.find_last_of("/\\");
            if (slash != std::string::npos) {
              parentDir = parentDir.substr(0, slash);
            }
            remainingPath = remainingPath.substr(3);
          }
          fullPath = parentDir + "/" + remainingPath;
          std::ifstream testFile(fullPath.c_str());
          if (!testFile.is_open()) {
            std::string altPath = fullPath;
            size_t shadersPos = altPath.find("/shaders/");
            if (shadersPos == std::string::npos) {
              shadersPos = altPath.rfind("/shadercandy/");
              if (shadersPos != std::string::npos) {
                altPath = altPath.substr(0, shadersPos + 12) + "shaders/" +
                          remainingPath;
              }
            } else {
              altPath = altPath.substr(0, shadersPos + 8) + remainingPath;
            }
            std::ifstream altFile(altPath.c_str());
            if (altFile.is_open()) {
              fullPath = altPath;
            } else {
              std::string shaderBasePath =
                  dir + "base/" + remainingPath.substr(5);
              std::ifstream shaderBaseFile(shaderBasePath.c_str());
              if (shaderBaseFile.is_open()) {
                fullPath = shaderBasePath;
              }
            }
          }
        } else if (includePath.substr(0, 2) == "./") {
          fullPath = dir + includePath.substr(2);
        } else {
          fullPath = dir + includePath;
          std::ifstream testFile(fullPath.c_str());
          if (!testFile.is_open()) {
            std::string altPath = fullPath;
            size_t shadersPos = altPath.find("/shaders/");
            if (shadersPos != std::string::npos) {
              altPath = altPath.substr(0, shadersPos + 8) + "/" + includePath;
            } else {
              size_t pos = altPath.rfind("/shadercandy/");
              if (pos != std::string::npos) {
                altPath =
                    altPath.substr(0, pos + 12) + "shaders/" + includePath;
              }
            }
            std::ifstream altFile(altPath.c_str());
            if (altFile.is_open()) {
              fullPath = altPath;
            }
          }
        }

        std::string includeContent =
            loadShaderWithIncludes(fullPath.c_str(), depth + 1);
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

bool GLShaderProgram::loadShaderFromFile(const char *fragmentPath) {
  std::string fragStr = loadShaderWithIncludes(fragmentPath);
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
  const tm *lt = localtime(&t);
  uniforms.date[0] = static_cast<float>(lt->tm_year + 1900);
  uniforms.date[1] = static_cast<float>(lt->tm_mon + 1);
  uniforms.date[2] = static_cast<float>(lt->tm_mday);
  uniforms.date[3] =
      static_cast<float>(lt->tm_hour * 3600 + lt->tm_min * 60 + lt->tm_sec);

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
