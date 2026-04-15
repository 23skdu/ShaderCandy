//
//  ConfigurationManager.cpp
//  ShaderCandy
//
//  Configuration management implementation
//

#include "ConfigurationManager.h"
#include "PresetManager.h"
#include <algorithm>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>

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
  return ConfigValue(1.0f);
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

bool ConfigurationManager::saveToFile(const std::string &path) const {
  try {
    std::filesystem::path filePath(path);
    std::filesystem::create_directories(filePath.parent_path());

    std::ofstream file(path);
    if (!file.is_open()) {
      return false;
    }

    file << JSON::serializeSettings(settings_);
    file.close();
    return true;
  } catch (const std::exception &) {
    return false;
  }
}

void ConfigurationManager::loadDefaults() {
  settings_ = AppSettings();
  settings_.shaderPath = getShaderDirectory();
}


void ConfigurationManager::scanShaderDirectory(const std::string &path) {
  try {
    std::filesystem::path dirPath(path);
    if (!std::filesystem::exists(dirPath))
      return;

    for (const auto &entry : std::filesystem::recursive_directory_iterator(dirPath)) {
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
  // Parse shader metadata from file comments and path
  std::string shaderName = std::filesystem::path(shaderPath).stem().string();

  // Register a basic config with default parameters
  ShaderConfig config;
  config.shaderName = shaderName;
  config.displayName = shaderName;
  config.description = "";

  // Determine category from path
  std::filesystem::path path(shaderPath);
  std::string parentDir = path.parent_path().filename().string();
  if (parentDir == "effects" || parentDir == "effect") {
    config.category = "Effects";
  } else if (parentDir == "music") {
    config.category = "Music";
  } else if (parentDir == "neural") {
    config.category = "Neural";
  } else if (parentDir == "audio") {
    config.category = "Audio";
  } else {
    config.category = "Custom";
  }

  // Try to read shader file and parse metadata from comments
  std::ifstream file(shaderPath);
  if (file.is_open()) {
    std::string line;
    bool foundHeader = false;
    while (std::getline(file, line)) {
      // Look for shader name in first few lines (e.g., "// shader_name - Description")
      if (!foundHeader && line.find("//") == 0 && line.length() > 3) {
        std::string comment = line.substr(2);
        // Remove shader name prefix if present (e.g., "// vortex_dream - ")
        size_t dashPos = comment.find(" - ");
        if (dashPos != std::string::npos) {
          std::string namePart = comment.substr(0, dashPos);
          std::string descPart = comment.substr(dashPos + 3);
          // Clean up whitespace
          namePart.erase(0, namePart.find_first_not_of(" \t"));
          namePart.erase(namePart.find_last_not_of(" \t") + 1);
          if (!namePart.empty() && namePart != shaderName) {
            config.displayName = namePart;
          }
          if (!descPart.empty()) {
            config.description = descPart;
          }
          foundHeader = true;
        } else {
          // Just a comment without dash - might be description
          std::string cleaned = comment;
          cleaned.erase(0, cleaned.find_first_not_of(" \t"));
          cleaned.erase(cleaned.find_last_not_of(" \t") + 1);
          if (!cleaned.empty() && cleaned.length() > 10) {
            config.description = cleaned;
          }
        }
      }

      // Look for metadata comments: "// Category: Name"
      if (line.find("// Category:") != std::string::npos) {
        std::string cat = line.substr(line.find(":") + 1);
        cat.erase(0, cat.find_first_not_of(" \t"));
        cat.erase(cat.find_last_not_of(" \t") + 1);
        if (!cat.empty()) config.category = cat;
      }

      // Look for parameter definitions: "// Parameter: name min max default"
      if (line.find("// Parameter:") != std::string::npos) {
        std::string paramLine = line.substr(line.find(":") + 1);
        std::istringstream iss(paramLine);
        std::string paramName, paramDesc;
        float minVal, maxVal, defaultVal;
        if (iss >> paramName >> minVal >> maxVal >> defaultVal) {
          std::getline(iss, paramDesc);
          paramDesc.erase(0, paramDesc.find_first_not_of(" \t"));
          if (paramDesc.empty()) paramDesc = "User-defined parameter";
          config.parameters.push_back({paramName, paramName, paramDesc,
                                        ParamType::Range, defaultVal, minVal, maxVal});
        }
      }

      // Look for audio support hint: "// Audio: reactive" or similar
      if (line.find("// Audio:") != std::string::npos || 
          line.find("// audio:") != std::string::npos) {
        config.supportsAudio = true;
      }

      // Look for tags: "// Tags: tag1, tag2, tag3"
      if (line.find("// Tags:") != std::string::npos) {
        std::string tags = line.substr(line.find(":") + 1);
        std::istringstream iss(tags);
        std::string tag;
        while (std::getline(iss, tag, ',')) {
          tag.erase(0, tag.find_first_not_of(" \t"));
          tag.erase(tag.find_last_not_of(" \t") + 1);
          if (!tag.empty()) config.tags.push_back(tag);
        }
      }
    }
    file.close();
  }

  // Detect audio support by analyzing shader code for audio uniforms
  if (!config.supportsAudio) {
    std::ifstream checkFile(shaderPath);
    if (checkFile.is_open()) {
      std::string content((std::istreambuf_iterator<char>(checkFile)),
                          std::istreambuf_iterator<char>());
      if (content.find("bass") != std::string::npos ||
          content.find("mid") != std::string::npos ||
          content.find("treble") != std::string::npos ||
          content.find("audio") != std::string::npos) {
        config.supportsAudio = true;
      }
      checkFile.close();
    }
  }

  // Add default parameters if none were defined in metadata
  if (config.parameters.empty()) {
    config.parameters.push_back({"speed", "Speed", "Animation speed",
                                 ParamType::Range, 1.0f, 0.1f, 10.0f});
    config.parameters.push_back({"intensity", "Intensity", "Effect intensity",
                                 ParamType::Range, 1.0f, 0.0f, 2.0f});
    config.parameters.push_back({"bloom", "Enable Bloom",
                                 "Toggle bloom post-processing", ParamType::Bool,
                                 false});
  }

  // Set quality based on complexity indicators in shader
  config.supportsHDR = false;
  config.quality = 1.0f;

  // Check for expensive operations that might warrant lower quality
  std::ifstream qualityCheck(shaderPath);
  if (qualityCheck.is_open()) {
    std::string content((std::istreambuf_iterator<char>(qualityCheck)),
                        std::istreambuf_iterator<char>());
    int loopCount = 0;
    size_t pos = 0;
    while ((pos = content.find("for (", pos)) != std::string::npos) {
      loopCount++;
      pos++;
    }
    // Reduce quality for shaders with many loops
    if (loopCount > 10) config.quality = 0.8f;
    if (loopCount > 20) config.quality = 0.6f;
    qualityCheck.close();
  }

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

namespace JSON {

std::string escapeJSON(const std::string &s) {
  std::string result;
  for (char c : s) {
    switch (c) {
    case '"':
      result += "\\\"";
      break;
    case '\\':
      result += "\\\\";
      break;
    case '\n':
      result += "\\n";
      break;
    case '\r':
      result += "\\r";
      break;
    case '\t':
      result += "\\t";
      break;
    default:
      result += c;
      break;
    }
  }
  return result;
}

static std::string boolToString(bool b) { return b ? "true" : "false"; }

static std::string valueToString(const ConfigValue &value) {
  if (std::holds_alternative<bool>(value)) {
    return boolToString(std::get<bool>(value));
  } else if (std::holds_alternative<int>(value)) {
    return std::to_string(std::get<int>(value));
  } else if (std::holds_alternative<float>(value)) {
    return std::to_string(std::get<float>(value));
  } else if (std::holds_alternative<std::string>(value)) {
    return "\"" + escapeJSON(std::get<std::string>(value)) + "\"";
  }
  return "null";
}

static ConfigValue parseValue(const std::string &json, size_t &pos) {
  while (pos < json.size() && std::isspace(json[pos]))
    pos++;

  if (pos >= json.size())
    return ConfigValue(0);

  if (json[pos] == 't' || json[pos] == 'f') {
    if (json.substr(pos, 4) == "true") {
      pos += 4;
      return ConfigValue(true);
    }
    if (json.substr(pos, 5) == "false") {
      pos += 5;
      return ConfigValue(false);
    }
  }

  if (json[pos] == '"') {
    pos++;
    std::string str;
    while (pos < json.size() && json[pos] != '"') {
      if (json[pos] == '\\' && pos + 1 < json.size()) {
        pos++;
        switch (json[pos]) {
        case 'n':
          str += '\n';
          break;
        case 'r':
          str += '\r';
          break;
        case 't':
          str += '\t';
          break;
        case '"':
          str += '"';
          break;
        case '\\':
          str += '\\';
          break;
        default:
          str += json[pos];
          break;
        }
      } else {
        str += json[pos];
      }
      pos++;
    }
    if (pos < json.size())
      pos++;
    return ConfigValue(str);
  }

  if (json[pos] == '-' || std::isdigit(json[pos])) {
    size_t start = pos;
    if (json[pos] == '-')
      pos++;
    while (pos < json.size() && (std::isdigit(json[pos]) || json[pos] == '.'))
      pos++;
    std::string numStr = json.substr(start, pos - start);
    if (numStr.find('.') != std::string::npos) {
      return ConfigValue(std::stof(numStr));
    }
    return ConfigValue(std::stoi(numStr));
  }

  return ConfigValue(1.0f);
}

std::string serializeSettings(const AppSettings &settings) {
  std::string json = "{\n";
  json += "  \"targetFPS\": " + std::to_string(settings.targetFPS) + ",\n";
  json += "  \"vsync\": " + boolToString(settings.vsync) + ",\n";
  json += "  \"hdr\": " + boolToString(settings.hdr) + ",\n";
  json +=
      "  \"multisampleLevel\": " + std::to_string(settings.multisampleLevel) +
      ",\n";
  json += "  \"enableAudio\": " + boolToString(settings.enableAudio) + ",\n";
  json += "  \"audioDevice\": \"" + escapeJSON(settings.audioDevice) + "\",\n";
  json +=
      "  \"audioSensitivity\": " + std::to_string(settings.audioSensitivity) +
      ",\n";
  json += "  \"audioSmoothing\": " + std::to_string(settings.audioSmoothing) +
          ",\n";
  json += "  \"adaptiveQuality\": " + boolToString(settings.adaptiveQuality) +
          ",\n";
  json += "  \"showFPS\": " + boolToString(settings.showFPS) + ",\n";
  json += "  \"limitGPU\": " + boolToString(settings.limitGPU) + ",\n";
  json += "  \"autoScaleFPSThreshold\": " +
          std::to_string(settings.autoScaleFPSThreshold) + ",\n";
  json +=
      "  \"defaultShader\": \"" + escapeJSON(settings.defaultShader) + "\",\n";
  json += "  \"shaderPath\": \"" + escapeJSON(settings.shaderPath) + "\",\n";
  json += "  \"enableHotReload\": " + boolToString(settings.enableHotReload) +
          ",\n";
  json += "  \"spanDisplays\": " + boolToString(settings.spanDisplays) + ",\n";
  json += "  \"perDisplayShader\": " + boolToString(settings.perDisplayShader) +
          ",\n";
  json += "  \"idleTimeMinutes\": " + std::to_string(settings.idleTimeMinutes) +
          ",\n";
  json +=
      "  \"lockOnActivate\": " + boolToString(settings.lockOnActivate) + ",\n";
  json +=
      "  \"neuralStyleEnabled\": " + boolToString(settings.neuralStyleEnabled) +
      ",\n";
  json += "  \"neuralStyleStrength\": " +
          std::to_string(settings.neuralStyleStrength) + ",\n";
  json += "  \"neuralStyleName\": \"" + escapeJSON(settings.neuralStyleName) +
          "\",\n";
  json += "  \"spatialAudio\": " + boolToString(settings.spatialAudio) + ",\n";
  json += "  \"roomSize\": " + std::to_string(settings.roomSize) + ",\n";
  json +=
      "  \"reverbDamping\": " + std::to_string(settings.reverbDamping) + "\n";
  json += "}\n";
  return json;
}

AppSettings deserializeSettings(const std::string &json) {
  AppSettings settings;

  if (json.empty())
    return settings;

  auto getValue = [&](const std::string &field) -> ConfigValue {
    size_t found = json.find("\"" + field + "\"");
    if (found == std::string::npos)
      return ConfigValue(0);
    size_t pos = json.find(":", found);
    if (pos == std::string::npos)
      return ConfigValue(0);
    pos++; // Skip :
    return parseValue(json, pos);
  };

  ConfigValue v;

  v = getValue("targetFPS");
  if (std::holds_alternative<int>(v)) {
    settings.targetFPS = std::get<int>(v);
  }

  v = getValue("vsync");
  if (std::holds_alternative<bool>(v)) {
    settings.vsync = std::get<bool>(v);
  }

  v = getValue("enableAudio");
  if (std::holds_alternative<bool>(v)) {
    settings.enableAudio = std::get<bool>(v);
  }

  v = getValue("adaptiveQuality");
  if (std::holds_alternative<bool>(v)) {
    settings.adaptiveQuality = std::get<bool>(v);
  }

  v = getValue("autoScaleFPSThreshold");
  if (std::holds_alternative<float>(v)) {
    settings.autoScaleFPSThreshold = std::get<float>(v);
  } else if (std::holds_alternative<int>(v)) {
    settings.autoScaleFPSThreshold = static_cast<float>(std::get<int>(v));
  }

  v = getValue("defaultShader");
  if (std::holds_alternative<std::string>(v)) {
    settings.defaultShader = std::get<std::string>(v);
  }

  return settings;
}

std::map<std::string, ConfigValue> parse(const std::string &json) {
  std::map<std::string, ConfigValue> dict;
  if (json.empty())
    return dict;

  size_t pos = 0;
  auto skipWS = [&]() {
    while (pos < json.size() && std::isspace(json[pos]))
      pos++;
  };

  skipWS();
  if (pos >= json.size() || json[pos] != '{')
    return dict;
  pos++;

  while (pos < json.size()) {
    skipWS();
    if (pos >= json.size() || json[pos] == '}')
      break;

    // Parse key
    if (json[pos] != '"')
      break;
    pos++;
    std::string key;
    while (pos < json.size() && json[pos] != '"') {
      key += json[pos++];
    }
    if (pos < json.size())
      pos++; // skip "

    skipWS();
    if (pos >= json.size() || json[pos] != ':')
      break;
    pos++;

    // Check that there's actually content after the colon
    skipWS();
    if (pos >= json.size()) {
      dict.clear();
      return dict;
    }

    dict[key] = parseValue(json, pos);

    skipWS();
    if (pos < json.size() && json[pos] == ',') {
      pos++;
    } else if (pos < json.size() && json[pos] == '}') {
      // end of object
    } else {
      break;
    }
  }
  return dict;
}

} // namespace JSON

bool ConfigurationManager::loadFromFile(const std::string &path) {
  std::ifstream file(path);
  if (!file.is_open()) {
    loadDefaults();
    return false;
  }

  std::stringstream buffer;
  buffer << file.rdbuf();
  std::string json = buffer.str();
  file.close();

  settings_ = JSON::deserializeSettings(json);
  return true;
}

bool ConfigurationManager::savePreset(const std::string &name,
                                      const std::string &shader) {
  PresetManager &pm = PresetManager::getInstance();
  Preset preset(shader);
  preset.name = name;

  // Fill with current parameter values
  if (parameterValues_.count(shader) > 0) {
    for (const auto &pair : parameterValues_.at(shader)) {
      if (std::holds_alternative<float>(pair.second)) {
        preset.setFloat(pair.first, std::get<float>(pair.second));
      } else if (std::holds_alternative<int>(pair.second)) {
        preset.setInt(pair.first, std::get<int>(pair.second));
      } else if (std::holds_alternative<bool>(pair.second)) {
        preset.setBool(pair.first, std::get<bool>(pair.second));
      }
    }
  }

  std::string error;
  std::string path = getPresetDirectory() + "/" + shader + "/" + name + ".json";
  return pm.savePreset(preset, path, error);
}

bool ConfigurationManager::loadPreset(const std::string &name,
                                      const std::string &shader) {
  PresetManager &pm = PresetManager::getInstance();
  std::string error;
  std::string path = getPresetDirectory() + "/" + shader + "/" + name + ".json";
  auto preset = pm.loadPreset(path, error);

  if (preset) {
    for (const auto &pair : preset->floatParameters) {
      setParameter(shader, pair.first, pair.second);
    }
    for (const auto &pair : preset->intParameters) {
      setParameter(shader, pair.first, pair.second);
    }
    for (const auto &pair : preset->boolParameters) {
      setParameter(shader, pair.first, pair.second);
    }
    return true;
  }
  return false;
}

std::vector<std::string>
ConfigurationManager::getPresets(const std::string &shader) const {
  std::vector<std::string> results;
  std::string path = getPresetDirectory() + "/" + shader;
  if (!std::filesystem::exists(path))
    return results;

  for (const auto &entry : std::filesystem::directory_iterator(path)) {
    if (entry.path().extension() == ".json") {
      results.push_back(entry.path().stem().string());
    }
  }
  return results;
}

void ConfigurationManager::deletePreset(const std::string &name,
                                        const std::string &shader) {
  std::string error;
  std::string path = getPresetDirectory() + "/" + shader + "/" + name + ".json";
  PresetManager::getInstance().deletePreset(path, error);
}

} // namespace Config
} // namespace ShaderCandy
