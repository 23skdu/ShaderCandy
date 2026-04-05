#pragma once

#include <string>
#include <unordered_map>
#include <vector>

namespace ShaderCandy {
namespace Platform {
namespace Linux {

class GLShaderCompiler {
public:
  GLShaderCompiler();
  ~GLShaderCompiler();

  bool initialize();
  void shutdown();

  bool compileFromFile(const std::string &shaderPath, unsigned int &outProgram);
  bool compileFromSource(const std::string &vertexSource,
                         const std::string &fragmentSource,
                         unsigned int &outProgram);

  std::string getLastError() const { return lastError_; }
  bool hasErrors() const { return !lastError_.empty(); }
  void clearError() { lastError_.clear(); }

  void setPreamble(const std::string &preamble) { preamble_ = preamble; }

private:
  bool initialized_ = false;
  std::string preamble_;
  std::string lastError_;

  unsigned int compileShaderSource(const std::string &source,
                                   unsigned int type);
  bool checkShaderErrors(unsigned int shader);
  bool checkProgramErrors(unsigned int program);
};

} // namespace Linux
} // namespace Platform
} // namespace ShaderCandy
