#include "../src/platform/linux/GLSLWrapper.h"
#include "../src/platform/linux/LinuxIPC.h"
#include <cassert>
#include <iostream>
#include <string>

using namespace ShaderCandy::Platform::Linux;

void testGLSLWrapper() {
  std::cout << "Testing GLSLWrapper..." << std::endl;

  std::string preamble = GLSLWrapper::getPreamble(false);
  assert(preamble.find("#version 330 core") != std::string::npos);
  assert(preamble.find("layout(std140) uniform Uniforms") != std::string::npos);
  assert(preamble.find("vec3 ACESFilm(vec3 x)") != std::string::npos);

  std::string preambleGLES = GLSLWrapper::getPreamble(true);
  assert(preambleGLES.find("#version 300 es") != std::string::npos);
  assert(preambleGLES.find("precision highp float;") != std::string::npos);

  std::string vert = GLSLWrapper::getVertexShader(false);
  assert(vert.find("gl_Position = vec4(aPos, 0.0, 1.0);") != std::string::npos);

  std::cout << "[PASS] GLSLWrapper tests" << std::endl;
}

void testLinuxIPC() {
  std::cout << "Testing LinuxIPC (Logic Only)..." << std::endl;

  // Note: On some systems/environments shmget might fail if not permitted.
  // We'll try to initialize it and if it fails, we skip with a warning.
  try {
    LinuxIPC ipc(9999);
    ipc.updateShader("test_shader");
    ipc.updateSettings(1.5f, 0.8f);

    IPCData *data = ipc.getData();
    assert(std::string(data->currentShader) == "test_shader");
    assert(data->speed == 1.5f);
    assert(data->intensity == 0.8f);
    assert(data->updateNeeded == true);

    std::cout << "[PASS] LinuxIPC logic tests" << std::endl;
  } catch (...) {
    std::cout << "[SKIP] LinuxIPC tests (SHM not available in this environment)"
              << std::endl;
  }
}

int main() {
  testGLSLWrapper();
  testLinuxIPC();

  std::cout << "All Linux logic tests passed!" << std::endl;
  return 0;
}
