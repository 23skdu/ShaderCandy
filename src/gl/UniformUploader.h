#pragma once

#include "../core/ShaderInterop.h"
#include "../platform/linux/GLLoader.h"
#include <string>
#include <unordered_map>

namespace ShaderCandy {
namespace Platform {
namespace Linux {

class UniformUploader {
public:
  void cacheLocations(unsigned int program) {
    locations_.clear();
    const char *names[] = {
        "time",   "speed",        "intensity",   "resolution",
        "mouse",  "mouseButtons", "alpha",       "gravity",
        "volume", "bass",         "mid",         "treble",
        "beat"};
    for (const char *name : names) {
      int loc = glGetUniformLocation(program, name);
      if (loc >= 0) {
        locations_[name] = loc;
      }
    }
  }

  void upload(unsigned int program, const Uniforms &u,
              bool audioEnabled = false) {
    if (locations_.empty()) {
      cacheLocations(program);
    }

    auto set1f = [&](const char *name, float v) {
      auto it = locations_.find(name);
      if (it != locations_.end())
        glUniform1f(it->second, v);
    };
    auto set1i = [&](const char *name, int v) {
      auto it = locations_.find(name);
      if (it != locations_.end())
        glUniform1i(it->second, v);
    };
    auto set2f = [&](const char *name, float x, float y) {
      auto it = locations_.find(name);
      if (it != locations_.end())
        glUniform2f(it->second, x, y);
    };

    set1f("time", u.time);
    set1f("speed", u.speed);
    set1f("intensity", u.intensity);
    set2f("resolution", u.resolution.x, u.resolution.y);
    set2f("mouse", u.mouse.x, u.mouse.y);
    set1i("mouseButtons", (int)u.mouseButtons);
    set1f("alpha", u.alpha);
    set1f("gravity", u.gravity);

    if (audioEnabled) {
      set1f("volume", u.volume);
      set1f("bass", u.bass);
      set1f("mid", u.mid);
      set1f("treble", u.treble);
      set1f("beat", u.beat);
    }
  }

  void invalidate() { locations_.clear(); }

private:
  std::unordered_map<std::string, int> locations_;
};

} // namespace Linux
} // namespace Platform
} // namespace ShaderCandy
