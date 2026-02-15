#!/usr/bin/env python3
"""
Metal to GLSL Shader Converter for ShaderCandy

This tool helps convert Metal shaders to GLSL format for Linux support.
Metal shaders use raymarching and 3D SDFs, while GLSL shaders use simpler 2D effects.

Usage: python3 convert_metal_to_glsl.py <metal_shader.metal> <output.frag>
"""

import sys
import re
from pathlib import Path

# Conversion rules
CONVERSIONS = {
    # Types
    r"float2\b": "vec2",
    r"float3\b": "vec3",
    r"float4\b": "vec4",
    r"int32_t\b": "int",
    # Functions
    r"\.x\b": ".x",
    r"\.y\b": ".y",
    r"\.z\b": ".z",
    r"\.w\b": ".w",
    r"\.xy\b": ".xy",
    r"\.xyz\b": ".xyz",
    # Metal-specific to GLSL
    r"float2\(([^)]+)\)": r"vec2(\1)",
    r"float3\(([^)]+)\)": r"vec3(\1)",
    r"float4\(([^)]+)\)": r"vec4(\1)",
    # Math functions (most are the same)
    r"\.clamp\(": "clamp(",
    r"\.mix\(": "mix(",
    r"\.step\(": "step(",
    r"\.smoothstep\(": "smoothstep(",
    r"\.length\(": "length(",
    r"\.distance\(": "distance(",
    r"\.dot\(": "dot(",
    r"\.cross\(": "cross(",
    r"\.normalize\(": "normalize(",
    r"\.reflect\(": "reflect(",
    r"\.refract\(": "refract(",
    r"\.abs\(": "abs(",
    r"\.sign\(": "sign(",
    r"\.floor\(": "floor(",
    r"\.ceil\(": "ceil(",
    r"\.fract\(": "fract(",
    r"\.mod\(": "mod(",
    r"\.min\(": "min(",
    r"\.max\(": "max(",
    r"\.clamp\(": "clamp(",
    r"\.sin\(": "sin(",
    r"\.cos\(": "cos(",
    r"\.tan\(": "tan(",
    r"\.asin\(": "asin(",
    r"\.acos\(": "acos(",
    r"\.atan\(": "atan(",
    r"\.atan2\(": "atan(",
    r"\.pow\(": "pow(",
    r"\.exp\(": "exp(",
    r"\.log\(": "log(",
    r"\.exp2\(": "exp2(",
    r"\.log2\(": "log2(",
    r"\.sqrt\(": "sqrt(",
    r"\.inversesqrt\(": "inversesqrt(",
    # Remove Metal-specific attributes
    r"\[\[stage_in\]\]": "",
    r"\[\[buffer\(0\)\]\]": "",
    r"\[\[position\]\]": "",
    r"\[\[attribute\(\d+\)\]\]": "",
    r"\[\[stage_in\]\]": "",
    r"\[\[stage_out\]\]": "",
    r"fragment float4 fragment_main": "vec4 effect_main",
    r"VertexOut in": "",
    r"constant Uniforms& u": "",
    r"using namespace metal;": "",
    r"using namespace ShaderUtils;": "",
    r"#include <metal_stdlib>": '#include "base/common.glsl"',
    r'#include "ShaderInterop.h"': "",
    r'#include "utils.metal"': "",
    r'#include "base/utils.metal"': "",
    r"/\*.*?\*/": "",  # Remove block comments
}


def convert_metal_to_glsl(metal_code):
    """Convert Metal shader code to GLSL."""
    glsl_code = metal_code

    # Apply conversions
    for pattern, replacement in CONVERSIONS.items():
        glsl_code = re.sub(pattern, replacement, glsl_code, flags=re.DOTALL)

    # Remove line comments
    lines = []
    for line in glsl_code.split("\n"):
        # Skip empty lines and obvious Metal-specific lines
        stripped = line.strip()
        if stripped.startswith("//") and (
            "struct" in stripped or "Uniforms" in stripped
        ):
            continue
        if "thread" in stripped and "float" in stripped:
            line = line.replace("thread ", "")
        lines.append(line)

    return "\n".join(lines)


def create_glsl_wrapper(metal_file):
    """Create a basic GLSL shader from Metal."""
    metal_code = metal_file.read_text()

    # Extract shader name
    shader_name = metal_file.stem

    # Basic template
    glsl_template = f"""#include "base/common.glsl"

// {shader_name} - Converted from Metal to GLSL
// Note: This is a simplified 2D version. The original Metal shader used 3D raymarching.

vec4 effect_main(vec2 centered, vec2 uv) {{
    float t = time * speed * 0.5;
    
    // TODO: Implement shader logic here
    // Original Metal shader used raymarching which needs to be adapted to 2D
    
    vec3 color = vec3(0.5);
    
    color *= intensity;
    return vec4(color, alpha);
}}
"""

    return glsl_template


def main():
    if len(sys.argv) < 3:
        print(
            "Usage: python3 convert_metal_to_glsl.py <metal_shader.metal> <output.frag>"
        )
        print("       python3 convert_metal_to_glsl.py --batch <output_dir>")
        sys.exit(1)

    if sys.argv[1] == "--batch":
        # Batch convert all missing shaders
        output_dir = Path(sys.argv[2])
        output_dir.mkdir(parents=True, exist_ok=True)

        # Find all Metal shaders without GLSL equivalents
        shaders_dir = Path(__file__).parent.parent / "shaders"

        metal_shaders = list(shaders_dir.rglob("*.metal"))
        frag_shaders = set(p.stem for p in shaders_dir.rglob("*.frag"))

        converted = 0
        for metal_file in metal_shaders:
            if metal_file.stem in frag_shaders:
                continue
            if metal_file.stem in ["common", "utils", "default"]:
                continue
            if "system" in str(metal_file):
                continue

            # Determine output path
            rel_path = metal_file.relative_to(shaders_dir)
            output_file = output_dir / rel_path.with_suffix(".frag")
            output_file.parent.mkdir(parents=True, exist_ok=True)

            # Create stub
            glsl_code = create_glsl_wrapper(metal_file)
            output_file.write_text(glsl_code)
            print(f"Created stub: {output_file}")
            converted += 1

        print(f"\nCreated {converted} GLSL shader stubs")
        print(f"Output directory: {output_dir}")
        print(
            "\nNote: These are placeholder stubs. Each shader needs manual implementation"
        )
        print(
            "of the 2D effect equivalent to the original 3D raymarching Metal shader."
        )

    else:
        # Single file conversion
        metal_file = Path(sys.argv[1])
        output_file = Path(sys.argv[2])

        if not metal_file.exists():
            print(f"Error: {metal_file} not found")
            sys.exit(1)

        glsl_code = create_glsl_wrapper(metal_file)
        output_file.write_text(glsl_code)
        print(f"Created: {output_file}")


if __name__ == "__main__":
    main()
