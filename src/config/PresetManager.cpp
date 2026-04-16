//
//  PresetManager.cpp
//  ShaderCandy
//
//  Preset save/load operations
//

#include "PresetManager.h"
#include "ConfigurationManager.h"
#include <algorithm>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <sstream>

namespace ShaderCandy {
namespace Config {

#pragma mark - Preset Implementation

Preset::Preset()
    : version("1.0"), name(""), shaderName("plasma"), createdDate(""),
      modifiedDate("") {
  auto now = std::chrono::system_clock::now();
  auto time = std::chrono::system_clock::to_time_t(now);
  std::tm *tm = std::localtime(&time);
  std::ostringstream oss;
  oss << std::put_time(tm, "%Y-%m-%dT%H:%M:%SZ");
  createdDate = oss.str();
}

Preset::Preset(const std::string &shader) : Preset() {
  shaderName = shader;
  name = "Custom " + shader;
}

std::map<std::string, std::variant<float, int, bool, std::string>>
Preset::toDictionary() const {
  std::map<std::string, std::variant<float, int, bool, std::string>> dict;

  dict["version"] = version;
  dict["name"] = name;
  dict["shader"] = shaderName;

  if (!author.empty())
    dict["author"] = author;
  if (!description.empty())
    dict["description"] = description;
  if (!createdDate.empty())
    dict["created"] = createdDate;
  if (!modifiedDate.empty())
    dict["modified"] = modifiedDate;
  if (!category.empty())
    dict["category"] = category;

  // Tags as comma-separated string
  if (!tags.empty()) {
    std::string tagsStr;
    for (size_t i = 0; i < tags.size(); i++) {
      if (i > 0)
        tagsStr += ",";
      tagsStr += tags[i];
    }
    dict["tags"] = tagsStr;
  }

  // Parameters with "param." prefix
  for (const auto &[key, value] : floatParameters) {
    dict["param." + key] = value;
  }
  for (const auto &[key, value] : intParameters) {
    dict["param." + key] = value;
  }
  for (const auto &[key, value] : boolParameters) {
    dict["param." + key] = value;
  }
  for (const auto &[key, value] : stringParameters) {
    dict["param." + key] = value;
  }

  // Global settings with "setting." prefix
  for (const auto &[key, value] : globalSettings) {
    dict["setting." + key] = value;
  }

  return dict;
}

Preset Preset::fromDictionary(
    const std::map<std::string, std::variant<float, int, bool, std::string>>
        &dict) {
  Preset preset;

  // Required fields
  if (auto it = dict.find("version"); it != dict.end()) {
    preset.version = std::get<std::string>(it->second);
  }
  if (auto it = dict.find("name"); it != dict.end()) {
    preset.name = std::get<std::string>(it->second);
  }
  if (auto it = dict.find("shader"); it != dict.end()) {
    preset.shaderName = std::get<std::string>(it->second);
  }

  // Optional fields
  if (auto it = dict.find("author"); it != dict.end()) {
    preset.author = std::get<std::string>(it->second);
  }
  if (auto it = dict.find("description"); it != dict.end()) {
    preset.description = std::get<std::string>(it->second);
  }
  if (auto it = dict.find("created"); it != dict.end()) {
    preset.createdDate = std::get<std::string>(it->second);
  }
  if (auto it = dict.find("modified"); it != dict.end()) {
    preset.modifiedDate = std::get<std::string>(it->second);
  }
  if (auto it = dict.find("category"); it != dict.end()) {
    preset.category = std::get<std::string>(it->second);
  }
  if (auto it = dict.find("tags"); it != dict.end()) {
    std::string tagsStr = std::get<std::string>(it->second);
    std::istringstream iss(tagsStr);
    std::string tag;
    while (std::getline(iss, tag, ',')) {
      if (!tag.empty()) {
        preset.tags.push_back(tag);
      }
    }
  }

  // Parse prefixed keys
  for (const auto &[key, value] : dict) {
    if (key.substr(0, 6) == "param.") {
      std::string paramKey = key.substr(6);
      if (std::holds_alternative<float>(value)) {
        preset.floatParameters[paramKey] = std::get<float>(value);
      } else if (std::holds_alternative<int>(value)) {
        preset.intParameters[paramKey] = std::get<int>(value);
      } else if (std::holds_alternative<bool>(value)) {
        preset.boolParameters[paramKey] = std::get<bool>(value);
      } else if (std::holds_alternative<std::string>(value)) {
        preset.stringParameters[paramKey] = std::get<std::string>(value);
      }
    } else if (key.substr(0, 8) == "setting.") {
      std::string settingKey = key.substr(8);
      if (std::holds_alternative<float>(value)) {
        preset.globalSettings[settingKey] = std::get<float>(value);
      }
    }
  }


  return preset;
}

void Preset::setFloat(const std::string &key, float value) {
  floatParameters[key] = value;
}

float Preset::getFloat(const std::string &key, float defaultValue) const {
  auto it = floatParameters.find(key);
  return (it != floatParameters.end()) ? it->second : defaultValue;
}

void Preset::setInt(const std::string &key, int value) {
  intParameters[key] = value;
}

int Preset::getInt(const std::string &key, int defaultValue) const {
  auto it = intParameters.find(key);
  return (it != intParameters.end()) ? it->second : defaultValue;
}

void Preset::setBool(const std::string &key, bool value) {
  boolParameters[key] = value;
}

bool Preset::getBool(const std::string &key, bool defaultValue) const {
  auto it = boolParameters.find(key);
  return (it != boolParameters.end()) ? it->second : defaultValue;
}

#pragma mark - PresetManager Implementation

PresetManager &PresetManager::getInstance() {
  static PresetManager instance;
  return instance;
}

std::vector<Preset>
PresetManager::discoverPresets(const std::string &directory) {
  std::vector<Preset> presets;

  try {
    std::filesystem::path dirPath(directory);
    if (!std::filesystem::exists(dirPath) ||
        !std::filesystem::is_directory(dirPath)) {
      return presets;
    }

    for (const auto &entry : std::filesystem::directory_iterator(dirPath)) {
      if (entry.is_regular_file() && entry.path().extension() == ".json") {
        std::string error;
        auto preset = loadPreset(entry.path().string(), error);
        if (preset.has_value()) {
          presets.push_back(preset.value());
        }
      }
    }
  } catch (const std::exception &) {
    // Directory access errors are ignored
  }

  return presets;
}

std::vector<Preset> PresetManager::allBuiltInPresets() {
  std::string builtInPath =
      ConfigurationManager::getPresetDirectory() + "/BuiltIn";
  return discoverPresets(builtInPath);
}

std::vector<Preset> PresetManager::allUserPresets() {
  std::string userPath = ConfigurationManager::getPresetDirectory() + "/User";
  return discoverPresets(userPath);
}

bool PresetManager::savePreset(const Preset &preset, const std::string &path,
                               std::string &error) {
  // Validate preset
  PresetValidationError validationError = validatePreset(preset);
  if (validationError != PresetValidationError::None) {
    error = validationErrorMessage(validationError);
    return false;
  }

  auto dict = preset.toDictionary();

  try {
    std::filesystem::path filePath(path);
    std::filesystem::create_directories(filePath.parent_path());

    std::ofstream outFile(path);
    if (!outFile.is_open()) {
      error = "Failed to create file: " + path;
      return false;
    }

    outFile << "{\n";

    size_t count = 0;
    for (const auto &[key, value] : dict) {
      outFile << "  \"" << key << "\": ";

      if (std::holds_alternative<float>(value)) {
        outFile << std::fixed << std::setprecision(3) << std::get<float>(value);
      } else if (std::holds_alternative<int>(value)) {
        outFile << std::get<int>(value);
      } else if (std::holds_alternative<bool>(value)) {
        outFile << (std::get<bool>(value) ? "true" : "false");
      } else if (std::holds_alternative<std::string>(value)) {
        outFile << "\"" << std::get<std::string>(value) << "\"";
      }

      if (++count < dict.size()) {
        outFile << ",";
      }
      outFile << "\n";
    }

    outFile << "}\n";
    outFile.close();

    return true;
  } catch (const std::exception &e) {
    error = std::string("Error saving preset: ") + e.what();
    return false;
  }
}

std::optional<Preset> PresetManager::loadPreset(const std::string &path,
                                                std::string &error) {
  try {
    std::ifstream inFile(path);
    if (!inFile.is_open()) {
      error = "Failed to open file: " + path;
      return std::nullopt;
    }

    std::stringstream buffer;
    buffer << inFile.rdbuf();
    inFile.close();

    std::string jsonStr = buffer.str();
    std::map<std::string, std::variant<float, int, bool, std::string>> dict;

    // Simple JSON parser for key-value pairs
    std::istringstream iss(jsonStr);
    std::string line;

    while (std::getline(iss, line)) {
      // Trim whitespace
      line.erase(std::remove_if(line.begin(), line.end(), ::isspace),
                 line.end());

      size_t colonPos = line.find(':');
      if (colonPos == std::string::npos)
        continue;

      std::string key = line.substr(1, colonPos - 2); // Remove quotes
      std::string value = line.substr(colonPos + 1);

      if (!value.empty() && value.back() == ',')
        value.pop_back();
      if (!value.empty() && value.back() == '}')
        value.pop_back();

      // Parse value type
      if (value.front() == '"') {
        dict[key] = value.substr(1, value.size() - 2);
      } else if (value == "true") {
        dict[key] = true;
      } else if (value == "false") {
        dict[key] = false;
      } else if (value.find('.') != std::string::npos) {
        dict[key] = std::stof(value);
      } else {
        dict[key] = std::stoi(value);
      }
    }

    return Preset::fromDictionary(dict);

  } catch (const std::exception &e) {
    error = std::string("Error loading preset: ") + e.what();
    return std::nullopt;
  }
}

bool PresetManager::deletePreset(const std::string &path, std::string &error) {
  try {
    return std::filesystem::remove(path);
  } catch (const std::exception &e) {
    error = std::string("Error deleting preset: ") + e.what();
    return false;
  }
}

PresetValidationError PresetManager::validatePreset(const Preset &preset) {
  if (preset.version.empty()) {
    return PresetValidationError::MissingVersion;
  }

  if (preset.version != "1.0") {
    return PresetValidationError::UnsupportedVersion;
  }

  if (preset.name.empty()) {
    return PresetValidationError::MissingName;
  }

  if (preset.shaderName.empty()) {
    return PresetValidationError::MissingShader;
  }

  return PresetValidationError::None;
}

std::string PresetManager::validationErrorMessage(PresetValidationError error) {
  switch (error) {
  case PresetValidationError::None:
    return "";
  case PresetValidationError::InvalidJSON:
    return "Invalid JSON format";
  case PresetValidationError::MissingVersion:
    return "Missing version field";
  case PresetValidationError::UnsupportedVersion:
    return "Unsupported preset version";
  case PresetValidationError::MissingShader:
    return "Missing shader name";
  case PresetValidationError::InvalidParameters:
    return "Invalid parameter values";
  case PresetValidationError::MissingName:
    return "Missing preset name";
  default:
    return "Unknown validation error";
  }
}

std::vector<Preset> PresetManager::importPresets(const std::string &directory,
                                                 std::string &error) {
  return discoverPresets(directory);
}

bool PresetManager::exportPreset(const Preset &preset,
                                 const std::string &outputPath,
                                 std::string &error) {
  return savePreset(preset, outputPath, error);
}

} // namespace Config
} // namespace ShaderCandy
