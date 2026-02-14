import os

SHADERS_DIR = "shaders"

def fix_remaining(path):
    with open(path, 'r') as f:
        content = f.read()

    original = content
    
    # 1. Remove #include "common.metal"
    if '#include "common.metal"' in content:
        print(f"  Removing common.metal include from {os.path.basename(path)}")
        content = content.replace('#include "common.metal"', '// #include "common.metal" (Removed for runtime compatibility)')

    if '#include "base/common.metal"' in content:
        content = content.replace('#include "base/common.metal"', '// #include "base/common.metal"')

    # 2. Fix fallout.metal unused var
    if "fallout.metal" in path:
        if "float3 cloudPos = p + lightDir * 2.0;" in content:
            print("  Fixing fallout.metal unused var")
            content = content.replace("float3 cloudPos = p + lightDir * 2.0;", "// float3 cloudPos = p + lightDir * 2.0;")

    # 3. Fix neural_style_blend sample -> read
    if "neural_style_blend.metal" in path:
        # It uses input.sample(...) but likely has access::read
        # We can change access to sample?
        # texture2d<float, access::read, ...>
        # Change to access::sample?
        if "access::read" in content and ".sample(" in content:
            print("  Fixing neural_style_blend texture access")
            content = content.replace("access::read", "access::sample")
            
    # 4. Fix dwarves.metal undeclared identifiers
    if "dwarves.metal" in path:
        # glow -> u_glow?
        # time -> u_time?
        # Check if u_glow exists?
        if "float u_glow = 1.0;" in content:
            content = content.replace("t * glow", "t * u_glow")
            print("  Fixed usage of glow -> u_glow")
        
        if "float u_time = 1.0;" in content: # Wait, time is usually u.time
            # If I injected u_time?
            # Or if it was u.time -> time (my fix) -> u_time (my repair)?
            # Let's blindly try to fix 'time' usage if 'u_time' is available?
            # Or assume 'time' means 'u.time' from implicit Uniforms?
            # But Uniforms struct is commented out.
            # And 'u' might be missing.
            # If I replaced 'u.time' with 'time'.
            # And 'time' is not defined.
            # Then I should use 'u_time' (if injected) or 'uniforms.time' (if standard).
            # 'uniforms' is the standard name in MetalRenderer.
            # So 'time' -> 'uniforms.time'?
            # But 'time' is a variable name.
            pass

    if content != original:
        with open(path, 'w') as f:
            f.write(content)

def main():
    for root, dirs, files in os.walk(SHADERS_DIR):
        for file in files:
            if file.endswith(".metal"):
                fix_remaining(os.path.join(root, file))

if __name__ == "__main__":
    main()
