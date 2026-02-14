import os
import re

SHADERS_DIR = "shaders"

STANDARD_UNIFORMS = {
    "time", "speed", "resolution", "mouse", "mouseButtons", "intensity", 
    "date", "frame", "deltaTime", "alpha", "gravity", "volume", "bass", 
    "mid", "treble", "beat", "audioData", "gpuTime", "cpuTime", "fps",
    "gameTime", "playerPos", "ghostPos", "score", "lives", "level"
}

def fix_shader(path):
    with open(path, 'r') as f:
        content = f.read()

    original_content = content
    
    # 1. Fix Entry Point Name
    # Look for fragment function that is NOT fragment_main
    # pattern: fragment float4 name(...)
    match = re.search(r'fragment\s+float4\s+(\w+)\s*\(', content)
    if match:
        func_name = match.group(1)
        if func_name != 'fragment_main':
            print(f"  Renaming entry point {func_name} -> fragment_main")
            content = content.replace(f"fragment float4 {func_name}", "fragment float4 fragment_main")

    # 2. Fix Uniforms Redefinition
    # regex to capture struct Uniforms { ... };
    # We use dotall to match across lines
    uniforms_match = re.search(r'struct\s+Uniforms\s*\{(.*?)\};', content, re.DOTALL)
    extra_fields = []
    
    if uniforms_match:
        struct_body = uniforms_match.group(1)
        print(f"  Found Uniforms struct redefinition in {os.path.basename(path)}")
        
        # Parse fields
        for line in struct_body.split(';'):
            line = line.strip()
            if not line: continue
            # float name
            parts = line.split()
            if len(parts) >= 2:
                type_name = parts[0]
                var_name = parts[1]
                if var_name not in STANDARD_UNIFORMS:
                    extra_fields.append(var_name)
                    print(f"    Found non-standard uniform: {var_name}")

        # Comment out the struct
        content = content.replace(uniforms_match.group(0), "/* " + uniforms_match.group(0) + " */")

    # 3. Handle Extra Fields in Usage
    # We need to inject these variables at the start of fragment_main
    if extra_fields:
        # Find start of fragment_main body
        main_match = re.search(r'fragment\s+float4\s+fragment_main\s*\(.*?\)\s*\{', content, re.DOTALL)
        if main_match:
            insertion_point = main_match.end()
            injection = "\n    // Injected default values for missing uniforms\n"
            for field in extra_fields:
                injection += f"    float {field} = 1.0;\n" # Default to 1.0
            
            content = content[:insertion_point] + injection + content[insertion_point:]
            
            # Now replace u.field with field, assuming 'u' is the uniform variable name
            # Check variable name definition: constant Uniforms& name [[buffer(0)]]
            arg_match = re.search(r'constant\s+Uniforms\s*[&*]\s*(\w+)\s*\[\[buffer\(0\)\]\]', content)
            if arg_match:
                u_name = arg_match.group(1)
                for field in extra_fields:
                    # distinct check to avoid replacing valid sub-words
                    content = re.sub(rf'\b{u_name}\.{field}\b', field, content)

    # 4. Fix VertexOut members (uv -> texCoord)
    if "in.uv" in content and "in.texCoord" not in content:
        # Assuming 'in' is the variable name, but might be different.
        # Simple string replace is risky but likely safe for "in.uv" pattern if "VertexOut" is standard.
        # But user might have defined struct VertexOut { float2 uv; ... };
        # If so, we need to comment out THAT struct too.
        # But ShaderInterop defines VertexOut.
        pass
        
    vertex_out_match = re.search(r'struct\s+VertexOut\s*\{(.*?)\};', content, re.DOTALL)
    if vertex_out_match:
        print(f"  Found VertexOut redefinition. Commenting out.")
        content = content.replace(vertex_out_match.group(0), "/* " + vertex_out_match.group(0) + " */")
        
    # Replace .uv with .texCoord if used on VertexOut
    # We assume 'in' is the name or just generally replace in.uv -> in.texCoord
    # This is a bit aggressive but common in these ports.
    content = re.sub(r'\b(\w+)\.uv\b', r'\1.texCoord', content)
    
    # 5. Remove 'using namespace metal;' redundancy (optional, cleaner)
    # content = content.replace("using namespace metal;", "// using namespace metal;")
    
    # 6. Fix missing includes
    content = content.replace('#include "../../src/core/ShaderInterop.h"', '// #include "ShaderInterop.h" (Auto-included)')
    content = content.replace('#include "../base/common.metal"', '#include "common.metal"') # standard include path
    
    if content != original_content:
        with open(path, 'w') as f:
            f.write(content)
        print(f"Fixed {path}")
    else:
        pass

def main():
    for root, dirs, files in os.walk(SHADERS_DIR):
        for file in files:
            if file.endswith(".metal"):
                path = os.path.join(root, file)
                # print(f"Checking {path}...")
                try:
                    fix_shader(path)
                except Exception as e:
                    print(f"Error fixing {path}: {e}")

if __name__ == "__main__":
    main()
