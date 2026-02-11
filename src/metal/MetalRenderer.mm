#include "MetalRenderer.h"
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include <iostream>

namespace ShaderCandy {

class MetalRenderer::Impl {
public:
  id<MTLDevice> device;
  id<MTLCommandQueue> commandQueue;
  id<MTLLibrary> library;
  id<MTLRenderPipelineState> pipelineState;
  std::string currentShaderPath;

  Impl() {
    device = MTLCreateSystemDefaultDevice();
    if (device) {
      commandQueue = [device newCommandQueue];
    }
  }
};

MetalRenderer::MetalRenderer() : pImpl(std::make_unique<Impl>()) {}

MetalRenderer::~MetalRenderer() = default;

bool MetalRenderer::initialize() {
  if (!pImpl->device) {
    std::cerr << "Metal is not supported on this device" << std::endl;
    return false;
  }
  return true;
}

bool MetalRenderer::initializeWithDevice(void *device) {
  pImpl->device = (__bridge id<MTLDevice>)device;
  pImpl->commandQueue = [pImpl->device newCommandQueue];
  return true;
}

bool MetalRenderer::loadShader(const std::string &name,
                               const std::string &path) {
  shaderPaths_[name] = path;

  NSError *error = nil;
  NSString *nsPath = [NSString stringWithUTF8String:path.c_str()];
  NSString *source = [NSString stringWithContentsOfFile:nsPath
                                               encoding:NSUTF8StringEncoding
                                                  error:&error];

  if (error) {
    std::cerr << "Failed to load shader file: " << path << std::endl;
    return false;
  }

  return compileFromSource([source UTF8String],
                           "vertex_main"); // Assuming standard entry point
}

bool MetalRenderer::compileFromSource(const std::string &source,
                                      const std::string &entryPoint) {
  if (!pImpl->device)
    return false;

  NSString *nsSource = [NSString stringWithUTF8String:source.c_str()];
  NSError *error = nil;

  id<MTLLibrary> library = [pImpl->device newLibraryWithSource:nsSource
                                                       options:nil
                                                         error:&error];

  if (error) {
    std::cerr << "Shader compilation error: " <<
        [[error localizedDescription] UTF8String] << std::endl;
    return false;
  }

  pImpl->library = library;

  // Attempt to create pipeline state to verify full validity
  MTLRenderPipelineDescriptor *descriptor =
      [[MTLRenderPipelineDescriptor alloc] init];
  descriptor.vertexFunction = [library newFunctionWithName:@"vertex_main"];
  descriptor.fragmentFunction = [library newFunctionWithName:@"fragment_main"];
  descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

  pImpl->pipelineState =
      [pImpl->device newRenderPipelineStateWithDescriptor:descriptor
                                                    error:&error];

  if (error) {
    std::cerr << "Pipeline state creation error: " <<
        [[error localizedDescription] UTF8String] << std::endl;
    return false;
  }

  return true;
}

bool MetalRenderer::reloadShaders() {
  if (activeShader_.empty())
    return false;
  auto it = shaderPaths_.find(activeShader_);
  if (it != shaderPaths_.end()) {
    return loadShader(activeShader_, it->second);
  }
  return false;
}

std::vector<std::string> MetalRenderer::getAvailableShaders() const {
  std::vector<std::string> names;
  for (const auto &pair : shaderPaths_) {
    names.push_back(pair.first);
  }
  return names;
}

bool MetalRenderer::setActiveShader(const std::string &name) {
  auto it = shaderPaths_.find(name);
  if (it != shaderPaths_.end()) {
    activeShader_ = name;
    return loadShader(name, it->second);
  }
  return false;
}

std::string MetalRenderer::getActiveShader() const { return activeShader_; }

void MetalRenderer::render() {
  // Placeholder: In a real renderer, this would encode commands
  // But since this class is likely used for offline testing or testing without
  // a view, we might not have a drawable.
}

// Stub factory function
std::unique_ptr<ShaderManager> createMetalRenderer() {
  return std::make_unique<MetalRenderer>();
}

// Move constructors
MetalRenderer::MetalRenderer(MetalRenderer &&) noexcept = default;
MetalRenderer &MetalRenderer::operator=(MetalRenderer &&) noexcept = default;

} // namespace ShaderCandy
