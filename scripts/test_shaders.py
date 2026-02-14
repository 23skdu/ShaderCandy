#!/usr/bin/env python3
import os
import sys
import tempfile
import subprocess
import shutil

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHADERS_DIR = os.path.join(ROOT_DIR, 'shaders')
EXCLUDES = ['common.metal', 'utils.metal', 'ShaderInterop', 'bloom', 'particles', 'debug_overlay']
INTEROP_PATH = os.path.join(ROOT_DIR, 'src', 'core', 'ShaderInterop.h')
UTILS_PATH = os.path.join(SHADERS_DIR, 'base', 'utils.metal')

def read_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def strip_includes(content):
    lines = content.split('\n')
    filtered = []
    for line in lines:
        if '#include "ShaderInterop.h"' in line:
            continue
        if '#include <metal_stdlib>' in line:
            continue
        if 'using namespace metal;' in line:
            continue
        filtered.append(line)
    return '\n'.join(filtered)

def main():
    if not os.path.exists(INTEROP_PATH):
        print(f"Error: ShaderInterop.h not found at {INTEROP_PATH}")
        sys.exit(1)
        
    if not os.path.exists(UTILS_PATH):
        print(f"Error: utils.metal not found at {UTILS_PATH}")
        sys.exit(1)

    interop_content = read_file(INTEROP_PATH)
    utils_content = strip_includes(read_file(UTILS_PATH))
    
    vertex_shader = """
vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}
"""

    failed_shaders = []
    passed_shaders = []

    print(f"Scanning {SHADERS_DIR}...")
    
    for root, dirs, files in os.walk(SHADERS_DIR):
        for file in files:
            if not file.endswith('.metal'):
                continue
                
            name = os.path.splitext(file)[0]
            if name in EXCLUDES or name.endswith('_failed'):
                continue
                
            path = os.path.join(root, file)
            print(f"Testing {name}...", end='', flush=True)
            
            shader_content = strip_includes(read_file(path))
            
            full_source = "#include <metal_stdlib>\nusing namespace metal;\n\n"
            full_source += interop_content + "\n\n"
            full_source += utils_content + "\n\n"
            full_source += vertex_shader + "\n\n"
            full_source += shader_content
            
            with tempfile.NamedTemporaryFile(suffix='.metal', mode='w', delete=False) as tmp:
                tmp.write(full_source)
                tmp_path = tmp.name
                
            try:
                # Compile using xcrun metal
                cmd = ['xcrun', '-sdk', 'macosx', 'metal', '-c', tmp_path, '-o', '/dev/null']
                result = subprocess.run(cmd, capture_output=True, text=True)
                
                if result.returncode == 0:
                    print(" OK")
                    passed_shaders.append(name)
                else:
                    print(" FAILED")
                    print(result.stderr)
                    failed_shaders.append((name, result.stderr))
            finally:
                os.unlink(tmp_path)

    print("\nResults:")
    print(f"Passed: {len(passed_shaders)}")
    print(f"Failed: {len(failed_shaders)}")
    
    if failed_shaders:
        print("\nFailures:")
        for name, error in failed_shaders:
            print(f"--- {name} ---")
            print(error)
        sys.exit(1)
    else:
        print("\nAll shaders compiled successfully!")
        sys.exit(0)

if __name__ == "__main__":
    main()
