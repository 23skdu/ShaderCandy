#pragma once

#include <string>
#include <vector>
#include <memory>
#include <functional>
#include <unordered_map>

namespace ShaderCandy {

// Abstract base class for platform-specific shader management
class ShaderManager {
public:
    virtual ~ShaderManager() = default;
    
    // Initialize the shader system
    virtual bool initialize() = 0;
    
    // Load a shader from file
    virtual bool loadShader(const std::string& name, const std::string& path) = 0;
    
    // Reload all shaders (hot reload)
    virtual bool reloadShaders() = 0;
    
    // Get list of available shaders
    virtual std::vector<std::string> getAvailableShaders() const = 0;
    
    // Set active shader
    virtual bool setActiveShader(const std::string& name) = 0;
    
    // Get currently active shader
    virtual std::string getActiveShader() const = 0;
    
    // Render frame with current shader
    virtual void render() = 0;
    
    // Enable/disable hot reload
    void setHotReload(bool enabled) { hotReloadEnabled_ = enabled; }
    bool isHotReloadEnabled() const { return hotReloadEnabled_; }
    
    // Set shader changed callback
    using ShaderChangedCallback = std::function<void(const std::string&)>;
    void setShaderChangedCallback(ShaderChangedCallback callback) {
        shaderChangedCallback_ = callback;
    }

protected:
    bool hotReloadEnabled_ = false;
    ShaderChangedCallback shaderChangedCallback_;
    std::unordered_map<std::string, std::string> shaderPaths_;
    std::string activeShader_;
};

// Factory function to create platform-specific shader manager
std::unique_ptr<ShaderManager> createShaderManager();

} // namespace ShaderCandy
