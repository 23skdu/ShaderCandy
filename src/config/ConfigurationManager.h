#pragma once

#include <functional>
#include <map>
#include <memory>
#include <string>
#include <variant>
#include <vector>

namespace ShaderCandy {
namespace Config {

// Configuration value types
using ConfigValue = std::variant<bool, int, float, std::string>;

// Parameter type enumeration
enum class ParamType {
  Bool,
  Int,
  Float,
  Color,  // Float3/Float4
  Choice, // Dropdown selection
  Range,  // Float with min/max
  File    // File path
};

// Shader parameter definition
struct ShaderParameter {
  std::string name;        // Variable name in shader
  std::string displayName; // Human-readable name
  std::string description; // Tooltip/help text
  ParamType type;
  ConfigValue defaultValue;
  ConfigValue minValue;             // For Range type
  ConfigValue maxValue;             // For Range type
  std::vector<std::string> choices; // For Choice type
  bool needsReload = false;         // If true, requires shader reload
};

// Shader configuration
struct ShaderConfig {
  std::string shaderName;
  std::string displayName;
  std::string description;
  std::string category; // e.g., "Fractals", "Abstract", "Nature"
  std::vector<std::string> tags;
  std::vector<ShaderParameter> parameters;
  bool supportsAudio = false;
  bool supportsHDR = false;
  float quality = 1.0f; // Performance hint (0-1)
};

// Global application settings
struct AppSettings {
  // Display
  int targetFPS = 60;
  bool vsync = true;
  bool hdr = false;
  int multisampleLevel = 0;

  // Audio
  bool enableAudio = false;
  std::string audioDevice;
  float audioSensitivity = 1.0f;
  float audioSmoothing = 0.3f;

  // Performance
  bool adaptiveQuality = true;
  bool showFPS = false;
  bool limitGPU = false;
  float autoScaleFPSThreshold = 45.0f;

  // Shaders
  std::string defaultShader;
  std::string shaderPath;
  bool enableHotReload = true;

  // Multi-monitor
  bool spanDisplays = false;
  bool perDisplayShader = false;
  std::vector<std::string> displayShaders;

  // Screensaver
  int idleTimeMinutes = 5;
  bool lockOnActivate = false;

  // Phase 5 - Advanced Technology
  bool neuralStyleEnabled = false;
  float neuralStyleStrength = 0.5f;
  std::string neuralStyleName = "default";

  bool spatialAudio = false;
  float roomSize = 1.0f;
  float reverbDamping = 0.5f;
};

class ConfigurationManager {
public:
  static ConfigurationManager &getInstance();

  // Initialize and load configuration
  bool initialize();
  void shutdown();

  // Settings access
  AppSettings &getSettings() { return settings_; }
  const AppSettings &getSettings() const { return settings_; }

  // Shader configuration
  void registerShader(const ShaderConfig &config);
  void unregisterShader(const std::string &shaderName);
  std::vector<ShaderConfig> getAvailableShaders() const;
  std::vector<ShaderConfig>
  getShadersByCategory(const std::string &category) const;
  ShaderConfig *getShaderConfig(const std::string &shaderName);

  // Parameter values
  void setParameter(const std::string &shader, const std::string &param,
                    ConfigValue value);
  ConfigValue getParameter(const std::string &shader,
                           const std::string &param) const;
  ConfigValue getParameterDefault(const std::string &shader,
                                  const std::string &param) const;
  void resetParameter(const std::string &shader, const std::string &param);
  void resetAllParameters(const std::string &shader);

  // Parameter values (Typed helpers with safe fallback)
  float getFloatParameter(const std::string &shader,
                          const std::string &param) const {
    auto value = getParameter(shader, param);
    if (std::holds_alternative<float>(value)) {
      return std::get<float>(value);
    } else if (std::holds_alternative<int>(value)) {
      return static_cast<float>(std::get<int>(value));
    }
    return 1.0f;
  }
  bool getBoolParameter(const std::string &shader,
                        const std::string &param) const {
    auto value = getParameter(shader, param);
    if (std::holds_alternative<bool>(value)) {
      return std::get<bool>(value);
    }
    return false;
  }
  int getIntParameter(const std::string &shader,
                      const std::string &param) const {
    auto value = getParameter(shader, param);
    if (std::holds_alternative<int>(value)) {
      return std::get<int>(value);
    } else if (std::holds_alternative<float>(value)) {
      return static_cast<int>(std::get<float>(value));
    }
    return 0;
  }
  std::string getStringParameter(const std::string &shader,
                                 const std::string &param) const {
    auto value = getParameter(shader, param);
    if (std::holds_alternative<std::string>(value)) {
      return std::get<std::string>(value);
    }
    return "";
  }

  // Persistence
  bool loadFromFile(const std::string &path);
  bool saveToFile(const std::string &path) const;
  void loadDefaults();

  // Auto-discovery
  void scanShaderDirectory(const std::string &path);
  void parseShaderMetadata(const std::string &shaderPath);

  // Change notifications
  using ConfigChangeCallback =
      std::function<void(const std::string &shader, const std::string &param)>;
  void setChangeCallback(ConfigChangeCallback callback);

  // Preset management
  bool savePreset(const std::string &name, const std::string &shader);
  bool loadPreset(const std::string &name, const std::string &shader);
  std::vector<std::string> getPresets(const std::string &shader) const;
  void deletePreset(const std::string &name, const std::string &shader);

  // Platform-specific paths
  static std::string getConfigDirectory();
  static std::string getShaderDirectory();
  static std::string getPresetDirectory();

private:
  ConfigurationManager() = default;
  ~ConfigurationManager() = default;

  AppSettings settings_;
  std::map<std::string, ShaderConfig> shaderConfigs_;
  std::map<std::string, std::map<std::string, ConfigValue>> parameterValues_;
  ConfigChangeCallback changeCallback_;

  std::string configFilePath_;
  bool initialized_ = false;
};

// JSON serialization helpers
namespace JSON {
std::string serializeSettings(const AppSettings &settings);
AppSettings deserializeSettings(const std::string &json);
std::string serializeShaderConfig(const ShaderConfig &config);
ShaderConfig deserializeShaderConfig(const std::string &json);
} // namespace JSON

} // namespace Config
} // namespace ShaderCandy
