/* This is free and unencumbered software released into the public domain.
   See LICENSE or <https://unlicense.org/> for details. */

// shadercandy-bench — GPU shader performance benchmark
// Compiles all shaders, measures render FPS, and outputs a baseline report.

#include "GLLoader.h"
#include "GLSLWrapper.h"

#ifdef __linux__
#include <GL/gl.h>
#include <GL/glext.h>
#include <GLFW/glfw3.h>
#endif

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

using namespace ShaderCandy::Platform::Linux;

struct BenchResult {
  std::string name;
  std::string path;
  bool compiled;
  double compileTimeMs;
  double avgFrameMs;
  double avgFps;
  double minFps;
  double maxFps;
  int frameCount;
};

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

static std::string loadShaderWithIncludes(const char *path, int depth = 0) {
  return GLSLWrapper::loadShaderWithIncludes(path, depth);
}

static bool compileShaderProgram(const std::string &fragSrc, GLuint &outProgram) {
  std::string vertSrc = GLSLWrapper::getVertexShader();

  GLuint vs = glCreateShader(GL_VERTEX_SHADER);
  const char *vSrc = vertSrc.c_str();
  glShaderSource(vs, 1, &vSrc, nullptr);
  glCompileShader(vs);

  GLint success = 0;
  glGetShaderiv(vs, GL_COMPILE_STATUS, &success);
  if (!success) {
    glDeleteShader(vs);
    return false;
  }

  GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
  const char *fSrc = fragSrc.c_str();
  glShaderSource(fs, 1, &fSrc, nullptr);
  glCompileShader(fs);

  glGetShaderiv(fs, GL_COMPILE_STATUS, &success);
  if (!success) {
    glDeleteShader(vs);
    glDeleteShader(fs);
    return false;
  }

  outProgram = glCreateProgram();
  glAttachShader(outProgram, vs);
  glAttachShader(outProgram, fs);
  glLinkProgram(outProgram);

  glGetProgramiv(outProgram, GL_LINK_STATUS, &success);
  if (!success) {
    glDeleteProgram(outProgram);
    outProgram = 0;
    glDeleteShader(vs);
    glDeleteShader(fs);
    return false;
  }

  glDeleteShader(vs);
  glDeleteShader(fs);
  return true;
}

static void setupQuad(GLuint &vao, GLuint &vbo) {
  float vertices[] = {-1.0f, -1.0f, 0.0f, 0.0f,  1.0f, -1.0f, 1.0f, 0.0f,
                      -1.0f, 1.0f,  0.0f, 1.0f,  -1.0f, 1.0f,  0.0f, 1.0f,
                      1.0f,  -1.0f, 1.0f, 0.0f,  1.0f,  1.0f,  1.0f, 1.0f};

  glGenVertexArrays(1, &vao);
  glGenBuffers(1, &vbo);

  glBindVertexArray(vao);
  glBindBuffer(GL_ARRAY_BUFFER, vbo);
  glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void *)0);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float),
                        (void *)(2 * sizeof(float)));
  glEnableVertexAttribArray(1);
}

static BenchResult benchmarkShader(const std::string &path, GLuint vao,
                                   GLuint vbo, int renderFrames, int width,
                                   int height) {
  BenchResult result;
  result.path = path;
  result.name = std::filesystem::path(path).stem().string();
  result.compiled = false;
  result.compileTimeMs = 0;
  result.avgFrameMs = 0;
  result.avgFps = 0;
  result.minFps = 999999;
  result.maxFps = 0;
  result.frameCount = 0;

  // Compile
  auto t0 = std::chrono::steady_clock::now();
  std::string fragStr = loadShaderWithIncludes(path.c_str());
  if (fragStr.empty()) {
    std::cerr << "  [SKIP] Failed to load: " << path << std::endl;
    return result;
  }

  std::string wrappedFrag = GLSLWrapper::getPreamble() + fragStr;
  GLuint program = 0;
  if (!compileShaderProgram(wrappedFrag, program)) {
    std::cerr << "  [FAIL] Compile error: " << result.name << std::endl;
    return result;
  }
  auto t1 = std::chrono::steady_clock::now();
  result.compileTimeMs =
      std::chrono::duration<double, std::milli>(t1 - t0).count();
  result.compiled = true;

  // Setup UBO
  GLuint ubo;
  glGenBuffers(1, &ubo);
  glBindBuffer(GL_UNIFORM_BUFFER, ubo);
  glBufferData(GL_UNIFORM_BUFFER, sizeof(Uniforms), nullptr, GL_DYNAMIC_DRAW);

  GLuint blockIndex = glGetUniformBlockIndex(program, "Uniforms");
  if (blockIndex != GL_INVALID_INDEX) {
    glUniformBlockBinding(program, blockIndex, 0);
  }

  Uniforms uniforms{};
  uniforms.speed = 1.0f;
  uniforms.intensity = 1.0f;
  uniforms.resolution[0] = static_cast<float>(width);
  uniforms.resolution[1] = static_cast<float>(height);

  auto startTime = std::chrono::steady_clock::now();

  // Render frames and measure
  std::vector<double> frameTimes;
  frameTimes.reserve(renderFrames);

  for (int i = 0; i < renderFrames; ++i) {
    auto frameStart = std::chrono::steady_clock::now();

    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(program);
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, ubo);

    uniforms.time =
        std::chrono::duration<float>(frameStart - startTime).count();
    uniforms.frame = i;
    uniforms.deltaTime = 1.0f / 60.0f;

    glBindBuffer(GL_UNIFORM_BUFFER, ubo);
    glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(Uniforms), &uniforms);

    glDrawArrays(GL_TRIANGLES, 0, 6);
    glFinish();

    auto frameEnd = std::chrono::steady_clock::now();
    double frameMs =
        std::chrono::duration<double, std::milli>(frameEnd - frameStart).count();
    frameTimes.push_back(frameMs);
  }

  // Calculate stats
  double totalMs = 0;
  for (double ft : frameTimes) {
    totalMs += ft;
  }
  result.avgFrameMs = totalMs / frameTimes.size();
  result.avgFps = (result.avgFrameMs > 0) ? 1000.0 / result.avgFrameMs : 0;

  for (double ft : frameTimes) {
    double fps = (ft > 0) ? 1000.0 / ft : 0;
    result.minFps = std::min(result.minFps, fps);
    result.maxFps = std::max(result.maxFps, fps);
  }
  result.frameCount = renderFrames;

  // Cleanup
  glDeleteProgram(program);
  glDeleteBuffers(1, &ubo);

  return result;
}

static void printReport(const std::vector<BenchResult> &results) {
  std::cout << "\n"
            << "========================================\n"
            << "  ShaderCandy Benchmark Report\n"
            << "========================================\n\n";

  int compiled = 0, failed = 0;
  double totalCompileMs = 0;
  double bestFps = 0, worstFps = 999999;

  std::cout << "  Shader                 Compile    Avg FPS    Min FPS    Max FPS\n"
            << "  -----------------------------------------------------------------\n";

  for (const auto &r : results) {
    std::string name = r.name;
    if (name.size() > 22)
      name = name.substr(0, 19) + "...";

    if (r.compiled) {
      compiled++;
      totalCompileMs += r.compileTimeMs;
      bestFps = std::max(bestFps, r.avgFps);
      worstFps = std::min(worstFps, r.avgFps);

      printf("  %-22s %7.1fms  %8.1f   %8.1f   %8.1f\n", name.c_str(),
             r.compileTimeMs, r.avgFps, r.minFps, r.maxFps);
    } else {
      failed++;
      printf("  %-22s    FAIL\n", name.c_str());
    }
  }

  std::cout << "\n"
            << "========================================\n"
            << "  Summary\n"
            << "========================================\n"
            << "  Shaders compiled:  " << compiled << "/" << results.size()
            << "\n"
            << "  Compile failures: " << failed << "\n"
            << "  Total compile:     " << totalCompileMs << "ms\n"
            << "  Best FPS:          " << bestFps << "\n"
            << "  Worst FPS:         "
            << (worstFps < 999999 ? worstFps : 0) << "\n";

  if (compiled > 0) {
    double avgCompile = totalCompileMs / compiled;
    double avgFps = 0;
    for (const auto &r : results) {
      if (r.compiled)
        avgFps += r.avgFps;
    }
    avgFps /= compiled;
    std::cout << "  Avg compile time:  " << avgCompile << "ms\n"
              << "  Avg FPS (all):     " << avgFps << "\n";
  }
  std::cout << "========================================\n\n";
}

int main(int argc, char **argv) {
  int renderFrames = 120;
  int width = 1920;
  int height = 1080;
  std::string outputPath;
  std::vector<std::string> shaderDirs;

  for (int i = 1; i < argc; i++) {
    if ((strcmp(argv[i], "-h") == 0) || (strcmp(argv[i], "--help") == 0)) {
      std::cout
          << "ShaderCandy Benchmark\n"
          << "Usage: " << argv[0] << " [options]\n"
          << "Options:\n"
          << "  -dir <path>       Shader directory (can be repeated)\n"
          << "  -frames <n>       Render frames per shader (default: 120)\n"
          << "  -width <n>        Render width (default: 1920)\n"
          << "  -height <n>       Render height (default: 1080)\n"
          << "  -output <path>    Save report to file (JSON)\n";
      return 0;
    } else if (strcmp(argv[i], "-dir") == 0 && i + 1 < argc) {
      shaderDirs.push_back(argv[++i]);
    } else if (strcmp(argv[i], "-frames") == 0 && i + 1 < argc) {
      renderFrames = std::atoi(argv[++i]);
    } else if (strcmp(argv[i], "-width") == 0 && i + 1 < argc) {
      width = std::atoi(argv[++i]);
    } else if (strcmp(argv[i], "-height") == 0 && i + 1 < argc) {
      height = std::atoi(argv[++i]);
    } else if (strcmp(argv[i], "-output") == 0 && i + 1 < argc) {
      outputPath = argv[++i];
    }
  }

  // Discover shaders
  std::vector<std::string> shaderPaths;
  namespace fs = std::filesystem;

  for (const auto &dir : shaderDirs) {
    if (!fs::exists(dir) || !fs::is_directory(dir))
      continue;
    for (const auto &entry : fs::directory_iterator(dir)) {
      if (!entry.is_regular_file())
        continue;
      auto ext = entry.path().extension().string();
      if (ext == ".frag" || ext == ".glsl") {
        shaderPaths.push_back(entry.path().string());
      }
    }
  }

  if (shaderPaths.empty()) {
    shaderDirs.push_back("shaders");
    shaderDirs.push_back("shaders/base");
    shaderDirs.push_back("shaders/effects");
    for (const auto &dir : shaderDirs) {
      if (!fs::exists(dir) || !fs::is_directory(dir))
        continue;
      for (const auto &entry : fs::directory_iterator(dir)) {
        if (!entry.is_regular_file())
          continue;
        auto ext = entry.path().extension().string();
        if (ext == ".frag" || ext == ".glsl") {
          shaderPaths.push_back(entry.path().string());
        }
      }
    }
  }

  std::sort(shaderPaths.begin(), shaderPaths.end());
  shaderPaths.erase(std::unique(shaderPaths.begin(), shaderPaths.end()),
                    shaderPaths.end());

  if (shaderPaths.empty()) {
    std::cerr << "No shaders found. Use -dir to specify shader directories."
              << std::endl;
    return 1;
  }

  std::cout << "ShaderCandy Benchmark: " << shaderPaths.size() << " shaders, "
            << renderFrames << " frames each at " << width << "x" << height
            << "\n"
            << std::endl;

  // Init GLFW
  if (!glfwInit()) {
    std::cerr << "Failed to initialize GLFW" << std::endl;
    return 1;
  }

  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
  glfwWindowHint(GLFW_VISIBLE, GLFW_FALSE);
  glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);

  GLFWwindow *window = glfwCreateWindow(width, height, "ShaderCandy Bench",
                                        nullptr, nullptr);
  if (!window) {
    std::cerr << "Failed to create GLFW window" << std::endl;
    glfwTerminate();
    return 1;
  }

  glfwMakeContextCurrent(window);
  glfwSwapInterval(0);

  InitializeGLLoader();

  std::cout << "GL Vendor:   " << glGetString(GL_VENDOR) << std::endl;
  std::cout << "GL Renderer: " << glGetString(GL_RENDERER) << std::endl;
  std::cout << "GL Version:  " << glGetString(GL_VERSION) << std::endl;
  std::cout << std::endl;

  GLuint vao, vbo;
  setupQuad(vao, vbo);

  glViewport(0, 0, width, height);
  glDisable(GL_DEPTH_TEST);

  // Benchmark all shaders
  std::vector<BenchResult> results;
  results.reserve(shaderPaths.size());

  for (size_t i = 0; i < shaderPaths.size(); ++i) {
    std::cout << "[" << (i + 1) << "/" << shaderPaths.size() << "] "
              << fs::path(shaderPaths[i]).stem().string() << "... "
              << std::flush;

    BenchResult r =
        benchmarkShader(shaderPaths[i], vao, vbo, renderFrames, width, height);
    results.push_back(r);

    if (r.compiled) {
      std::cout << r.avgFps << " fps (compile: " << r.compileTimeMs << "ms)"
                << std::endl;
    }
  }

  // Print report
  printReport(results);

  // Save JSON if requested
  if (!outputPath.empty()) {
    std::ofstream out(outputPath);
    if (out) {
      out << "{\n  \"shaders\": [\n";
      for (size_t i = 0; i < results.size(); ++i) {
        const auto &r = results[i];
        out << "    {\n"
            << "      \"" << r.name << "\": {\n"
            << "        \"path\": \"" << r.path << "\",\n"
            << "        \"compiled\": " << (r.compiled ? "true" : "false")
            << ",\n"
            << "        \"compileTimeMs\": " << r.compileTimeMs << ",\n"
            << "        \"avgFps\": " << r.avgFps << ",\n"
            << "        \"minFps\": " << r.minFps << ",\n"
            << "        \"maxFps\": " << r.maxFps << "\n"
            << "      }\n"
            << "    }";
        if (i + 1 < results.size())
          out << ",";
        out << "\n";
      }
      out << "  ]\n}\n";
      std::cout << "Report saved to: " << outputPath << std::endl;
    }
  }

  // Cleanup
  glDeleteVertexArrays(1, &vao);
  glDeleteBuffers(1, &vbo);
  glfwDestroyWindow(window);
  glfwTerminate();

  return 0;
}
