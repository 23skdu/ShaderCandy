import os
import re

SHADERS_DIR = "shaders"

CONFLICTING_FUNCS = {
    "noise", "snoise", "random", "fbm", "hash", "hash2", "hash3",
    "rotateX", "rotateY", "rotateZ", "rot", "rotX", "rotY", "rotZ"
}

def fix_file(path):
    with open(path, 'r') as f:
        content = f.read()

    original_content = content
    
    # 1. Fix u_func(...) -> func(...)
    # We look for patterns where a function call matches a "u_" variable.
    # Heuristic: u_(\w+)\(
    
    # We process file content.
    # Find all occurrences of u_SOMETHING(
    matches = re.finditer(r'\bu_(\w+)\s*\(', content)
    replacements = []
    
    for m in matches:
        func_name = m.group(1)
        # We assume u_func was a mistake and revert to func
        # CHECK: Is func a keyword or safe?
        # Assuming safe.
        replacements.append((m.group(0), f"{func_name}("))
        
    for old, new in replacements:
        content = content.replace(old, new)
        # print(f"  Fixed bad replacement: {old} -> {new}")

    # 2. Fix Function Redefinitions (collisions with utils.metal)
    for func in CONFLICTING_FUNCS:
        # Check if function is DEFINED in this file
        # Regex: type func(...) {
        # Note: shader types are stricter.
        pattern = re.compile(rf'^\s*(?:float|float2|float3|float4|void|int|bool)\s+{func}\s*\(', re.MULTILINE)
        
        if pattern.search(content):
            print(f"  Found conflicting function definition: {func} in {os.path.basename(path)}")
            new_name = f"custom_{func}"
            
            # Replace globally with word boundary
            content = re.sub(rf'\b{func}\b', new_name, content)

            # Special case: 'random' -> 'custom_random' might affect comments etc.
            # ensure word boundary.
            
    if content != original_content:
        with open(path, 'w') as f:
            f.write(content)
            
def main():
    for root, dirs, files in os.walk(SHADERS_DIR):
        for file in files:
            if file.endswith(".metal"):
                path = os.path.join(root, file)
                try:
                    fix_file(path)
                except Exception as e:
                    print(f"Error fixing {path}: {e}")

if __name__ == "__main__":
    main()
