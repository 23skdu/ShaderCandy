#!/usr/bin/env python3
import os
import sys
import subprocess
import time
from pathlib import Path

BUILD_DIR = Path("build")
SCREENSHOTS_DIR = Path("screenshots")
THUMBNAILS_DIR = Path("thumbnails")
SCREENSHOT_TOOL = BUILD_DIR / "shadercandy-screenshot"
PLAYER_APP = BUILD_DIR / "ShaderCandyPlayer.app"

SHADERS = [
    ("effects/area_51", "Area 51 - UFOs, aliens, and cows in desert"),
    ("effects/astra_fractal", "Astra Fractal - Mandelbox fractal with zoom"),
    ("effects/audio_spectrum", "Audio Spectrum - Real-time audio visualization"),
    ("effects/biolume_forest", "Biolume Forest - Glowing organic mushrooms"),
    ("effects/bloom", "Bloom - HDR glow effect"),
    ("effects/calibration", "Calibration - Test pattern for display setup"),
    ("effects/chrono_warp", "Chrono Warp - Time-distortion tunnel"),
    ("effects/cosmic_kaleido", "Cosmic Kaleidoscope - Mirror symmetry patterns"),
    ("effects/deep_ocean_pulse", "Deep Ocean Pulse - Underwater caustics"),
    ("effects/event_horizon", "Event Horizon - Black hole visualization"),
    ("effects/fallout", "Fallout - Post-apocalyptic wasteland"),
    ("effects/fractal_zoom", "Fractal Zoom - Infinite Mandelbrot dive"),
    ("effects/hearts", "Hearts - 3D floating hearts"),
    ("effects/julia_3d", "Julia 3D - 3D Julia set fractal"),
    ("effects/julia_set", "Julia Set - 2D Julia set visualization"),
    ("effects/kaleidoscopic_tunnel", "Kaleidoscopic Tunnel - Psychedelic tunnel"),
    ("effects/liquid_aura", "Liquid Aura - Fluid energy simulation"),
    ("effects/liquid_gradient", "Liquid Gradient - Smooth flowing colors"),
    ("effects/mandelbrot_set", "Mandelbrot Set - Classic fractal explorer"),
    ("effects/mandelbulb_3d", "Mandelbulb 3D - 3D Mandelbrot"),
    ("effects/mind_palace", "Mind Palace - Architectural memory palace"),
    ("effects/nebula", "Nebula - Cosmic gas clouds"),
    ("effects/neon_pulse", "Neon Pulse - Synthwave grid landscape"),
    ("effects/neural_nexus", "Neural Nexus - AI-inspired network"),
    ("effects/particles", "Particles - GPU particle system"),
    ("effects/prism_core", "Prism Core - Crystal refraction"),
    ("effects/quantum_crystalline", "Quantum Crystalline - Quantum field visualization"),
    ("effects/reaction_diffusion", "Reaction Diffusion - Chemical pattern formation"),
    ("effects/retro_robot", "Retro Robot - Vintage sci-fi aesthetic"),
    ("effects/starfield_warp", "Starfield Warp - Hyperspace travel"),
    ("effects/starship_hud", "Starship HUD - Sci-fi interface elements"),
    ("effects/voronoi_cells", "Voronoi Cells - Geometric tessellation"),
    ("effects/vortex_dream", "Vortex Dream - Swirling color tunnel"),
    ("music/8bit", "8-Bit - Retro video game aesthetic"),
    ("music/classical", "Classical - Elegant flowing ribbons"),
    ("music/electronic", "Electronic - Cyberpunk digital rain"),
    ("music/heavymetal", "Heavy Metal - Dark industrial theme"),
    ("music/hiphop", "Hip Hop - Urban graffiti style"),
    ("music/jazz", "Jazz - Smooth flowing patterns"),
    ("music/punk", "Punk - Aggressive glitch aesthetic"),
    ("music/reggae", "Reggae - Tropical island vibes"),
    ("music/soul", "Soul - Warm flowing gradients"),
    ("music/vaporwave", "Vaporwave - 80s retro nostalgia"),
    ("aquatic", "Aquatic - Underwater life scene"),
    ("capman", "CapMan - Pac-Man style game board"),
    ("dragon", "Dragon - Mystical dragon eye"),
    ("dwarves", "Dwarves - Underground forge scene"),
    ("elves", "Elves - Mystical forest elves"),
    ("frog", "Frog - Pond life with lily pad"),
    ("knights", "Knights - Medieval battle scene"),
    ("orcs", "Orcs - Volcanic fortress warriors"),
    ("owl", "Owl - Night watch with glowing eyes"),
    ("thieves", "Thieves - Stealth shadow scene"),
    ("unicorn", "Unicorn - Magical creature with horn"),
    ("checkerboard", "Checkerboard - Optical illusion pattern"),
    ("flying_toasters", "Flying Toasters - After Dark tribute"),
    ("gradient_waves", "Gradient Waves - Smooth flowing colors"),
    ("plasma", "Plasma - Classic demo scene effect"),
    ("ripples", "Ripples - Water ripple simulation"),
    ("spiral", "Spiral - Hypnotic rotating spiral"),
    ("tunnel", "Tunnel - Infinite corridor effect"),
    ("audio/audio_ray_tracing", "Audio Ray Tracing - Acoustic visualization"),
    ("neural/neural_style_blend", "Neural Style - Artistic style transfer"),
]

def generate_screenshot(shader_path, description, use_tool=True):
    shader_name = Path(shader_path).name
    screenshot_file = SCREENSHOTS_DIR / f"{shader_name}.png"
    
    print(f"Processing {shader_name}...", end=" ", flush=True)
    
    try:
        if use_tool and SCREENSHOT_TOOL.exists():
            cmd = [
                str(SCREENSHOT_TOOL),
                "--shader", shader_path,
                "--output", str(screenshot_file),
                "--time", "2.0"
            ]
            result = subprocess.run(cmd, capture_output=True, timeout=30)
            success = result.returncode == 0 and screenshot_file.exists()
        else:
            cmd = [
                str(PLAYER_APP / "Contents/MacOS/ShaderCandyPlayer"),
                "--shader", shader_path
            ]
            proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(3)
            subprocess.run(["screencapture", "-x", str(screenshot_file)], check=True)
            proc.terminate()
            success = screenshot_file.exists()
        
        if success:
            print("OK")
            return (shader_name, True, None)
        else:
            print("FAIL")
            return (shader_name, False, "Screenshot not created")
            
    except subprocess.TimeoutExpired:
        print("TIMEOUT")
        return (shader_name, False, "Timeout")
    except Exception as e:
        print(f"ERROR: {e}")
        return (shader_name, False, str(e))

def generate_thumbnail(shader_name):
    screenshot = SCREENSHOTS_DIR / f"{shader_name}.png"
    thumbnail = THUMBNAILS_DIR / f"{shader_name}.png"
    
    if not screenshot.exists():
        return False
    
    try:
        subprocess.run([
            "sips", "-Z", "300",
            str(screenshot),
            "--out", str(thumbnail)
        ], capture_output=True, check=True)
        return True
    except:
        return False

def main():
    SCREENSHOTS_DIR.mkdir(exist_ok=True)
    THUMBNAILS_DIR.mkdir(exist_ok=True)
    
    print("=" * 60)
    print("ShaderCandy Screenshot Generator")
    print("=" * 60)
    print(f"Total shaders: {len(SHADERS)}")
    print(f"Output: {SCREENSHOTS_DIR.absolute()}")
    print()
    
    if not SCREENSHOT_TOOL.exists():
        print(f"Warning: {SCREENSHOT_TOOL} not found")
        print("Will attempt to use player app with screencapture")
        use_tool = False
    else:
        use_tool = True
    
    print("Generating screenshots...")
    print("-" * 60)
    
    successful = []
    failed = []
    
    for shader_path, description in SHADERS:
        name, success, error = generate_screenshot(shader_path, description, use_tool)
        if success:
            successful.append(name)
            generate_thumbnail(name)
        else:
            failed.append((name, error))
    
    print()
    print("=" * 60)
    print(f"Screenshot Generation Complete")
    print("=" * 60)
    print(f"Successful: {len(successful)}/{len(SHADERS)}")
    print(f"Failed: {len(failed)}/{len(SHADERS)}")
    
    if failed:
        print()
        print("Failed shaders:")
        for name, error in failed:
            print(f"  - {name}: {error}")
    
    print()
    print(f"Screenshots: {SCREENSHOTS_DIR.absolute()}")
    print(f"Thumbnails: {THUMBNAILS_DIR.absolute()}")
    
    return 0 if len(failed) == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
