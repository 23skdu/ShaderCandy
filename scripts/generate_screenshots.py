#!/usr/bin/env python3
"""
ShaderCady Screenshot Generator
Generates screenshots for all shaders using the shadercandy-screenshot tool.
Run from the build directory.
"""

import os
import sys
import subprocess
import time
from pathlib import Path

# List of all shaders to capture
SHADERS = [
    # Music
    "vaporwave",
    "jazz",
    "classical",
    "heavymetal",
    "hiphop",
    "reggae",
    "8bit",
    "electronic",
    "punk",
    "soul",
    # Effects
    "effects/area_51",
    "effects/astra_fractal",
    "effects/biolume_forest",
    "effects/hearts",
    "effects/mind_palace",
    # Characters/Creatures
    "aquatic",
    "capman",
    "dragon",
    "dwarves",
    "elves",
    "frog",
    "orcs",
    "owl",
    "unicorn",
    # Other popular shaders
    "knights",
    "thieves",
    "checkerboard",
    "tunnel",
    "spiral",
    "plasma",
    "ripples",
    "gradient_waves",
    "flying_toasters",
]


def main():
    build_dir = Path(__file__).parent.parent / "build"
    screenshots_dir = Path(__file__).parent.parent / "screenshots"

    os.makedirs(screenshots_dir, exist_ok=True)

    screenshot_tool = build_dir / "shadercandy-screenshot"
    if not screenshot_tool.exists():
        print(f"Error: {screenshot_tool} not found. Please build first.")
        sys.exit(1)

    print(f"Generating screenshots for {len(SHADERS)} shaders...")
    print(f"Output directory: {screenshots_dir}")
    print()

    successful = []
    failed = []

    for shader in SHADERS:
        shader_name = Path(shader).name
        output_file = screenshots_dir / f"{shader_name}.png"

        print(f"Rendering {shader_name}...", end=" ", flush=True)

        try:
            cmd = [
                str(screenshot_tool),
                "--shader",
                shader,
                "--output",
                str(output_file),
                "--time",
                "2.0",
            ]

            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

            if result.returncode == 0 and output_file.exists():
                print(f"✓")
                successful.append(shader_name)
            else:
                print(f"✗")
                failed.append((shader_name, result.stderr))

        except subprocess.TimeoutExpired:
            print(f"✗ (timeout)")
            failed.append((shader_name, "Timeout"))
        except Exception as e:
            print(f"✗ ({e})")
            failed.append((shader_name, str(e)))

    print()
    print("=" * 50)
    print(f"Screenshot generation complete!")
    print(f"Successful: {len(successful)}/{len(SHADERS)}")
    print(f"Failed: {len(failed)}/{len(SHADERS)}")
    print()

    if failed:
        print("Failed shaders:")
        for name, error in failed:
            print(f"  - {name}: {error[:100]}")

    print()
    print(f"Screenshots saved to: {screenshots_dir}")

    # Also generate thumbnails
    print()
    print("Generating thumbnails...")
    thumbnails_dir = Path(__file__).parent.parent / "thumbnails"
    os.makedirs(thumbnails_dir, exist_ok=True)

    for screenshot in screenshots_dir.glob("*.png"):
        thumbnail = thumbnails_dir / screenshot.name
        try:
            subprocess.run(
                ["sips", "-Z", "300", str(screenshot), "--out", str(thumbnail)],
                capture_output=True,
                check=True,
            )
        except:
            pass

    print(f"Thumbnails saved to: {thumbnails_dir}")


if __name__ == "__main__":
    main()
