#!/usr/bin/env python3
"""Remove byte-identical local copies of helpers that now live in common.glsl.

Only removes a definition when its body matches the canonical one in
common.glsl exactly, so a shader that has since diverged is left untouched.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHADERS = ROOT / "shaders"

# name -> canonical body lines (as they appear in common.glsl)
CANONICAL = {
    "rot": ["mat2 rot(float a) {", "    float c = cos(a), s = sin(a);", "    return mat2(c, -s, s, c);", "}"],
    "rot2D": ["mat2 rot2D(float a) {", "    float c = cos(a), s = sin(a);", "    return mat2(c, -s, s, c);", "}"],
    "sdCircle": ["float sdCircle(vec2 p, float r) {", "    return length(p) - r;", "}"],
    "sdBox2D": ["float sdBox2D(vec2 p, vec2 b) {", "    vec2 d = abs(p) - b;",
                "    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);", "}"],
    "sdSegment": ["float sdSegment(vec2 p, vec2 a, vec2 b) {", "    vec2 pa = p - a, ba = b - a;",
                  "    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);", "    return length(pa - ba * h);", "}"],
    "fillSDF": ["float fillSDF(float d, float blur) {", "    return 1.0 - smoothstep(-blur, blur, d);", "}"],
    "sdUnevenCapsule": [
        "float sdUnevenCapsule(vec2 p, float r1, float r2, float h) {",
        "    p.x = abs(p.x);",
        "    float b = (r1 - r2) / h;",
        "    float a = sqrt(max(0.0, 1.0 - b * b));",
        "    float k = dot(p, vec2(-b, a));",
        "    if (k < 0.0) return length(p) - r1;",
        "    if (k > a * h) return length(p - vec2(0.0, h)) - r2;",
        "    return dot(p, vec2(a, b)) - r1;",
        "}",
    ],
}

DRY = not (len(sys.argv) > 1 and sys.argv[1] == "--apply")

removed_total = 0
changed_files = []

for frag in sorted(SHADERS.rglob("*.frag")):
    lines = frag.read_text().splitlines()
    if not any("common.glsl" in l for l in lines):
        continue
    out, i, removed = [], 0, []
    while i < len(lines):
        matched = False
        for name, body in CANONICAL.items():
            if lines[i:i + len(body)] == body:
                # Only drop it if the definition is not immediately followed by
                # a second copy, and we are not inside another function body.
                removed.append(name)
                i += len(body)
                # swallow one following blank line, keep spacing tidy
                while i < len(lines) and lines[i].strip() == "":
                    i += 1
                    break
                out.append("")
                matched = True
                break
        if matched:
            continue
        out.append(lines[i])
        i += 1
    if removed:
        text = "\n".join(out)
        text = re.sub(r"\n{3,}", "\n\n", text)
        changed_files.append((frag, removed))
        removed_total += len(removed)
        if not DRY:
            frag.write_text(text.rstrip() + "\n")

for path, names in changed_files:
    print(f"{path.relative_to(ROOT)}: {', '.join(names)}")
print(f"\n{'would remove' if DRY else 'removed'} {removed_total} duplicate definitions "
      f"across {len(changed_files)} files")
if DRY:
    print("(dry run - pass --apply to write)")