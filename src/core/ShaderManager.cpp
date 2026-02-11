#include "ShaderManager.h"

namespace ShaderCandy {

// Stub implementation - platform-specific implementations should override this
std::unique_ptr<ShaderManager> createShaderManager() {
    // This will be implemented by platform-specific code
    return nullptr;
}

} // namespace ShaderCandy
