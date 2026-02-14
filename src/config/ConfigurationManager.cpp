//
//  ConfigurationManager.cpp
//  ShaderCandy
//
//  Configuration management implementation
//

#include "ConfigurationManager.h"
#include <filesystem>
#include <fstream>
#include <iostream>

namespace ShaderCandy {
namespace Config {

ConfigurationManager &ConfigurationManager::getInstance() {
  static ConfigurationManager instance;
  return instance;
}

bool ConfigurationManager::initialize() {
  if (initialized_)
    return true;

  // Set default shader path
  settings_.shaderPath = getShaderDirectory();

  // Load any existing configuration
  std::string configPath = getConfigDirectory() + "/settings.json";
  loadFromFile(configPath);

  initialized_ = true;
  return true;
}

void ConfigurationManager::shutdown() {
  if (initialized_) {
    saveToFile(getConfigDirectory() + "/settings.json");
    initialized_ = false;
  }
}

void ConfigurationManager::registerShader(const ShaderConfig &config) {
  shaderConfigs_[config.shaderName] = config;
}

void ConfigurationManager::unregisterShader(const std::string &shaderName) {
  shaderConfigs_.erase(shaderName);
}

std::vector<ShaderConfig> ConfigurationManager::getAvailableShaders() const {
  std::vector<ShaderConfig> result;
  for (const auto &[name, config] : shaderConfigs_) {
    result.push_back(config);
  }
  return result;
}

std::vector<ShaderConfig>
ConfigurationManager::getShadersByCategory(const std::string &category) const {
  std::vector<ShaderConfig> result;
  for (const auto &[name, config] : shaderConfigs_) {
    if (config.category == category) {
      result.push_back(config);
    }
  }
  return result;
}

ShaderConfig *
ConfigurationManager::getShaderConfig(const std::string &shaderName) {
  auto it = shaderConfigs_.find(shaderName);
  return (it != shaderConfigs_.end()) ? &it->second : nullptr;
}

void ConfigurationManager::setParameter(const std::string &shader,
                                        const std::string &param,
                                        ConfigValue value) {
  parameterValues_[shader][param] = value;
}

ConfigValue ConfigurationManager::getParameter(const std::string &shader,
                                               const std::string &param) const {
  auto shaderIt = parameterValues_.find(shader);
  if (shaderIt != parameterValues_.end()) {
    auto paramIt = shaderIt->second.find(param);
    if (paramIt != shaderIt->second.end()) {
      return paramIt->second;
    }
  }
  return getParameterDefault(shader, param);
}

ConfigValue
ConfigurationManager::getParameterDefault(const std::string &shader,
                                          const std::string &param) const {
  auto shaderIt = shaderConfigs_.find(shader);
  if (shaderIt != shaderConfigs_.end()) {
    for (const auto &p : shaderIt->second.parameters) {
      if (p.name == param) {
        return p.defaultValue;
      }
    }
  }
  return ConfigValue(0);
}

void ConfigurationManager::resetParameter(const std::string &shader,
                                          const std::string &param) {
  auto shaderIt = parameterValues_.find(shader);
  if (shaderIt != parameterValues_.end()) {
    shaderIt->second.erase(param);
  }
}

void ConfigurationManager::resetAllParameters(const std::string &shader) {
  parameterValues_.erase(shader);
}

bool ConfigurationManager::loadFromFile(const std::string &path) {
  // Simple JSON-like loading (placeholder implementation)
  std::ifstream file(path);
  if (!file.is_open()) {
    loadDefaults();
    return false;
  }

  // TODO: Parse JSON configuration
  file.close();
  return true;
}

bool ConfigurationManager::saveToFile(const std::string &path) const {
  try {
    std::filesystem::path filePath(path);
    std::filesystem::create_directories(filePath.parent_path());

    std::ofstream file(path);
    if (!file.is_open()) {
      return false;
    }

    // Simple JSON-like output
    file << "{\n";
    file << "  \"targetFPS\": " << settings_.targetFPS << ",\n";
    file << "  \"vsync\": " << (settings_.vsync ? "true" : "false") << ",\n";
    file << "  \"enableAudio\": " << (settings_.enableAudio ? "true" : "false")
         << ",\n";
    file << "  \"adaptiveQuality\": "
         << (settings_.adaptiveQuality ? "true" : "false") << ",\n";
    file << "  \"autoScaleFPSThreshold\": " << settings_.autoScaleFPSThreshold
         << "\n";
    file << "}\n";

    file.close();
    return true;
  } catch (const std::exception &) {
    return false;
  }
}

void ConfigurationManager::loadDefaults() { settings_ = AppSettings(); }

void ConfigurationManager::scanShaderDirectory(const std::string &path) {
  try {
    std::filesystem::path dirPath(path);
    if (!std::filesystem::exists(dirPath))
      return;

    for (const auto &entry : std::filesystem::directory_iterator(dirPath)) {
      if (entry.is_regular_file() && (entry.path().extension() == ".metal" ||
                                      entry.path().extension() == ".glsl" ||
                                      entry.path().extension() == ".frag")) {
        parseShaderMetadata(entry.path().string());
      }
    }
  } catch (const std::exception &) {
    // Ignore directory errors
  }
}

void ConfigurationManager::parseShaderMetadata(const std::string &shaderPath) {
  // Simple shader metadata parsing (placeholder)
  // In a full implementation, this would parse comments/metadata from shader
  // files

  std::string shaderName = std::filesystem::path(shaderPath).stem().string();

  // Register a basic config with default parameters
  ShaderConfig config;
  config.shaderName = shaderName;
  config.displayName = shaderName;
  config.category = "Custom";

  // Add granular controls as default parameters
  config.parameters.push_back({"speed", "Speed", "Animation speed",
                               ParamType::Range, 1.0f, 0.1f, 10.0f});
  config.parameters.push_back({"intensity", "Intensity", "Effect intensity",
                               ParamType::Range, 1.0f, 0.0f, 2.0f});
  config.parameters.push_back({"bloom", "Enable Bloom",
                               "Toggle bloom post-processing", ParamType::Bool,
                               false});

  config.supportsAudio = false;
  config.supportsHDR = false;
  config.quality = 1.0f;

  shaderConfigs_[shaderName] = config;
}

void ConfigurationManager::setChangeCallback(ConfigChangeCallback callback) {
  changeCallback_ = callback;
}

std::string ConfigurationManager::getConfigDirectory() {
  const char *home = getenv("HOME");
  if (home) {
    std::string path =
        std::string(home) + "/Library/Application Support/ShaderCandy";
    return path;
  }
  return "/tmp/ShaderCandy";
}

std::string ConfigurationManager::getShaderDirectory() {
  return getConfigDirectory() + "/shaders";
}

std::string ConfigurationManager::getPresetDirectory() {
  return getConfigDirectory() + "/presets";
}

} // namespace Config
} // namespace ShaderCandy
