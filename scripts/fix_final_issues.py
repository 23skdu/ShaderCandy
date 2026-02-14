import os
import re

REPLACEMENTS = {
    "hiphop.metal": [
        (r"atan\(p\.y, p\.x\)", "atan2(p.y, p.x)")
    ],
    "heavymetal.metal": [
        (r"custom_hash\(float2\(floor\(t \* 10\.0\), 0\.0\)\);", "custom_hash(float2(floor(t * 10.0), 0.0)));")
    ],
    "classical.metal": [
        (r"ribbonP\.y0", "ribbonP.y"),
        (r"t \+ \* 3\. offset", "t + offset * 3.0")
    ],
    "unicorn.metal": [
        (r"float3 sparkles = sparkles", "float3 sparklesCol = sparkles"),
        (r"sparkles\(uv, t \* u_sparkle\)", "sparkles(uv, t * u_sparkle)"), 
        (r"time \* 5\.0", "t * 5.0"),
        (r"hornGlow\(uv, t \* aura\)", "hornGlow(uv, t * aura)") 
    ],
    "orcs.metal": [(r"time \* 5\.0", "t * 5.0")],
    "frog.metal": [
        (r"t \* ripple", "t * u_ripple"),
        (r"time \* 5\.0", "t * 5.0")
    ],
    "elves.metal": [
        (r"t \* glow", "t * u_glow"),
        (r"time \* 5\.0", "t * 5.0")
    ],
    "thieves.metal": [(r"time \* 5\.0", "t * 5.0")],
    "owl.metal": [(r"t \* vision", "t * u_vision")],
    "knights.metal": [
        (r"float3 heraldry = heraldry", "float3 heraldryCol = heraldry"),
        (r"\+= heraldry \*", "+= heraldryCol *")
    ],
     "fallout.metal": [
        (r"float3\(centeredUV \* 6\.0 \+ float\(i\), time, time \* 0\.5\)", "float3(centeredUV.x * 6.0 + float(i), centeredUV.y * 6.0 + float(i), time * 0.5)") 
    ]
}

def apply_fixes():
    for root, dirs, files in os.walk("shaders"):
        for file in files:
            if file in REPLACEMENTS:
                path = os.path.join(root, file)
                with open(path, 'r') as f:
                    content = f.read()
                
                original = content
                for pattern, replacement in REPLACEMENTS[file]:
                    content = re.sub(pattern, replacement, content)
                
                if content != original:
                    with open(path, 'w') as f:
                        f.write(content)
                    print(f"Fixed {file}")

if __name__ == "__main__":
    apply_fixes()
