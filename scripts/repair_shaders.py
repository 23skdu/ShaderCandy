import os
import re

SHADERS_DIR = "shaders"

def repair_shader(path):
    with open(path, 'r') as f:
        content = f.read()
    
    # 1. Parse Injected Uniforms
    injection_marker = "// Injected default values for missing uniforms"
    if injection_marker not in content:
        return

    # Extract names
    pattern = r'^\s*float\s+(\w+)\s*=\s*1\.0;\s*$'
    injected_vars = []
    
    # Locate the block to parse names
    # We iterate lines to be safe
    lines = content.split('\n')
    injection_line_idx = -1
    for i, line in enumerate(lines):
        if injection_marker in line:
            injection_line_idx = i
            break
            
    if injection_line_idx == -1: return

    # Parse subsequent lines until non-injection
    i = injection_line_idx + 1
    while i < len(lines):
        m = re.match(pattern, lines[i])
        if m:
            injected_vars.append(m.group(1))
            # Rename in definition immediately in our line buffer
            lines[i] = lines[i].replace(f"float {m.group(1)}", f"float u_{m.group(1)}")
        else:
            # End of block? or empty line
            if lines[i].strip() and not lines[i].strip().startswith("//"):
                break
        i += 1
        
    start_processing_line = i
    
    # Now reconstruct content for global replacement logic
    # But wait, working line-by-line is hard for multi-line statements.
    # We should reconstruct content with RENAMED definitions, then process the rest string.
    
    header = "\n".join(lines[:start_processing_line])
    body = "\n".join(lines[start_processing_line:])
    
    fixed_body = body
    
    for var in injected_vars:
        # Find FIRST redeclaration of 'var' in body
        # Pattern: type var ... ;
        # We need to be careful about matching logic.
        # \b\w+\s+var\b matches "float var" or "float3 var"
        
        # We search for the redeclaration.
        # We use a simple regex that assumes standard formatting (space before var).
        redecl_pattern = re.compile(rf'\b(\w+)\s+{var}\b.*?;', re.DOTALL)
        
        match = redecl_pattern.search(fixed_body)
        
        if match:
            # Collision detected!
            # Range [0, match.start()] -> Replace 'var' with 'u_var'
            pre_decl = fixed_body[:match.start()]
            pre_decl = re.sub(rf'\b{var}\b', f"u_{var}", pre_decl)
            
            # Range [match.start(), match.end()] -> Declaration statement
            decl_stmt = match.group(0)
            
            # In decl_stmt, the FIRST occurrence of 'var' (after type) is the definition.
            # We must PROTECT it.
            # We identifying it by position.
            # match.start() is start of type.
            # type_len = len(match.group(1))
            # The string is "Type var = expr;"
            
            # Helper to replace usages in initializer but keep definition
            # Split decl_stmt into Definition ("Type var") and Initializer ("= expr;")
            # Regex match gives us the whole string.
            # We find the first '='.
            eq_idx = decl_stmt.find('=')
            if eq_idx != -1:
                lhs = decl_stmt[:eq_idx] # "float3 underwater "
                rhs = decl_stmt[eq_idx:] # "= underwaterEffect(..., underwater);"
                
                # LHS: Keep 'var' as is.
                # RHS: Replace 'var' with 'u_var'.
                rhs = re.sub(rf'\b{var}\b', f"u_{var}", rhs)
                new_decl = lhs + rhs
            else:
                # No initializer? "float var;"
                # Then no usage inside. Keep as is.
                new_decl = decl_stmt

            # Range [match.end(), EOF] -> Local variable usage. Keep 'var'.
            post_decl = fixed_body[match.end():]
            
            fixed_body = pre_decl + new_decl + post_decl
            
            print(f"  Repaired collision for '{var}' in shader.")
            
        else:
            # No collision. Safe to replace GLOBALLY in body.
            fixed_body = re.sub(rf'\b{var}\b', f"u_{var}", fixed_body)
            # print(f"  Renamed '{var}' to 'u_{var}' globally.")

    # Reassemble
    final_content = header + "\n" + fixed_body
    
    with open(path, 'w') as f:
        f.write(final_content)

def main():
    for root, dirs, files in os.walk(SHADERS_DIR):
        for file in files:
            if file.endswith(".metal"):
                path = os.path.join(root, file)
                try:
                    repair_shader(path)
                except Exception as e:
                    print(f"Error repairing {path}: {e}")

if __name__ == "__main__":
    main()
