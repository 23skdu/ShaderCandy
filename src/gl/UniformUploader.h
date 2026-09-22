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
    if (program == 0)
      return;
    // Guard: ensure GL function pointers are loaded
    if (!glGetUniformLocation)
      return;
    const char *names[] = {
        "time",   "speed",        "intensity",   "resolution",
        "mouse",  "mouseButtons", "alpha",       "gravity",
        "volume", "bass",         "mid",         "treble",
        "beat",
        "param1", "param2",       "param3",      "param4",
        "param5", "param6",       "colorPalette", "effectFlags",
        "gpuTime", "cpuTime",     "fps",
        "date"};
    for (const char *name : names) {
      int loc = glGetUniformLocation(program, name);
      if (loc >= 0) {
        locations_[name] = loc;
      }
    }
    // Cache audioData base array location for fast single-call upload
    audioDataLoc_ = glGetUniformLocation(program, "audioData");
    if (audioDataLoc_ < 0) {
      audioDataLoc_ = glGetUniformLocation(program, "audioData[0]");
    }
    // Fallback: cache individual indices if driver does not support array base location
    if (audioDataLoc_ < 0) {
      for (int i = 0; i < 256; i++) {
        std::string arrName = "audioData[" + std::to_string(i) + "]";
        int loc = glGetUniformLocation(program, arrName.c_str());
        if (loc >= 0) {
          locations_[arrName] = loc;
        }
      }
    }
  }

  void upload(unsigned int program, const Uniforms &u,
              const ShaderParams &sp = ShaderParams{},
              bool audioEnabled = false) {
    if (locations_.empty() && audioDataLoc_ < 0) {
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
    auto set4f = [&](const char *name, float x, float y, float z, float w) {
      auto it = locations_.find(name);
      if (it != locations_.end())
        glUniform4f(it->second, x, y, z, w);
    };

    set1f("time", u.time);
    set1f("speed", u.speed);
    set1f("intensity", u.intensity);
    set2f("resolution", u.resolution.x, u.resolution.y);
    set2f("mouse", u.mouse.x, u.mouse.y);
    set1i("mouseButtons", (int)u.mouseButtons);
    set1f("alpha", u.alpha);
    set1f("gravity", u.gravity);

    // Performance metrics
    set1f("gpuTime", u.gpuTime);
    set1f("cpuTime", u.cpuTime);
    set1f("fps", u.fps);

    // Date
    set4f("date", u.date.x, u.date.y, u.date.z, u.date.w);

    // Shader parameters
    set1f("param1", sp.param1);
    set1f("param2", sp.param2);
    set1f("param3", sp.param3);
    set1f("param4", sp.param4);
    set1f("param5", sp.param5);
    set1f("param6", sp.param6);
    set1i("colorPalette", sp.colorPalette);
    set1i("effectFlags", sp.effectFlags);

    if (audioEnabled) {
      set1f("volume", u.volume);
      set1f("bass", u.bass);
      set1f("mid", u.mid);
      set1f("treble", u.treble);
      set1f("beat", u.beat);

      // Fast path: upload entire 256-float audio buffer in one driver call
      if (audioDataLoc_ >= 0 && glUniform1fv) {
        glUniform1fv(audioDataLoc_, 256, u.audioData);
      } else {
        // Fallback: upload individual array elements
        for (int i = 0; i < 256; i++) {
          std::string arrName = "audioData[" + std::to_string(i) + "]";
          auto it = locations_.find(arrName);
          if (it != locations_.end()) {
            glUniform1f(it->second, u.audioData[i]);
          }
        }
      }
    }
  }

  void invalidate() {
    locations_.clear();
    audioDataLoc_ = -1;
  }

private:
  std::unordered_map<std::string, int> locations_;
  int audioDataLoc_ = -1;
};

} // namespace Linux
} // namespace Platform
} // namespace ShaderCandy
