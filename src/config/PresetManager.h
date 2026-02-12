//
//  PresetManager.h
//  ShaderCandy
//
//  Manager for preset save/load operations
//

#pragma once

#include <string>
#include <vector>
#include <map>
#include <optional>
#include <variant>

namespace ShaderCandy {
namespace Config {

// Forward declarations
class Preset;

enum class PresetValidationError {
    None = 0,
    InvalidJSON,
    MissingVersion,
    UnsupportedVersion,
    MissingShader,
    InvalidParameters,
    MissingName,
};

// Preset data model
class Preset {
public:
    std::string version;
    std::string name;
    std::string author;
    std::string description;
    std::string shaderName;
    std::map<std::string, float> floatParameters;
    std::map<std::string, int> intParameters;
    std::map<std::string, bool> boolParameters;
    std::map<std::string, std::string> stringParameters;
    std::map<std::string, float> globalSettings;
    std::string createdDate;
    std::string modifiedDate;
    std::vector<std::string> tags;
    std::string category;
    std::string thumbnailPath;

    // Constructors
    Preset();
    explicit Preset(const std::string& shader);

    // Serialization
    std::map<std::string, std::variant<float, int, bool, std::string>> toDictionary() const;
    static Preset fromDictionary(const std::map<std::string, std::variant<float, int, bool, std::string>>& dict);

    // Parameter helpers
    void setFloat(const std::string& key, float value);
    float getFloat(const std::string& key, float defaultValue = 0.0f) const;
    void setInt(const std::string& key, int value);
    int getInt(const std::string& key, int defaultValue = 0) const;
    void setBool(const std::string& key, bool value);
    bool getBool(const std::string& key, bool defaultValue = false) const;
};

class PresetManager {
public:
    static PresetManager& getInstance();

    // Discovery
    std::vector<Preset> discoverPresets(const std::string& directory);
    std::vector<Preset> allBuiltInPresets();
    std::vector<Preset> allUserPresets();

    // CRUD Operations
    bool savePreset(const Preset& preset, const std::string& path, std::string& error);
    std::optional<Preset> loadPreset(const std::string& path, std::string& error);
    bool deletePreset(const std::string& path, std::string& error);

    // Validation
    PresetValidationError validatePreset(const Preset& preset);
    std::string validationErrorMessage(PresetValidationError error);

    // Import/Export
    std::vector<Preset> importPresets(const std::string& directory, std::string& error);
    bool exportPreset(const Preset& preset, const std::string& outputPath, std::string& error);

private:
    PresetManager() = default;
    ~PresetManager() = default;
};

}  // namespace Config
}  // namespace ShaderCandy
